%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CAT_VAR   1
#define CAT_FUNC  2

extern int yylex();
extern int yylineno;
void yyerror(const char *s);
void actualizar_tipo_y_cat(char *nombre, int tipo, int categoria);
extern int obtener_categoria(char *nombre);


struct ID {
    char      lexeme[256];
    int       linea;
    int       tipo_dato;
    int       categoria;
    struct ID *next;
};
extern struct ID *idSymTbl;


%}

/* Usado para almacenar las cosa que manda el lexico */
%union {
    char *cadena;  /* Para guardar los nombres de las variables/textos */
    int  tipo_dato; /* Para guardar si es INT, FLOAT o STRING */
}

/* Ahora le decimos a Yacc qué tokens van a usar esa 'cadena' */
%token <cadena> ID NUMBER STRING_LIT
/* Y cuáles reglas van a usar el 'tipo_dato' */
%type <tipo_dato> type_specifier


/* Declaración de Tokens */
%token INT FLOAT STRING_TYPE VOID MAIN
%token IF ELSE WHILE RETURN READ WRITE
%token LESSEQUAL "<="
%token MOREEQUAL ">="
%token EQUAL "=="
%token DIF "!="

/* Resolución del Dangling Else: 
   Le decimos a Yacc que el IF sin else tiene menor prioridad que el ELSE.
   Así, cuando vea un ELSE, forzará el emparejamiento con el IF más cercano. */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
/* --- REGLAS GRAMATICALES --- */

/* 1. Programa y Declaraciones */
program
    : declaration_list void_fun_declaration
    | void_fun_declaration
    ;

declaration_list
    : declaration_list var_declaration
    | declaration_list fun_declaration
    | var_declaration
    | fun_declaration
    ;

/* 2. Variables y Tipos */
var_declaration
    : type_specifier ID ';' {
        printf("DEBUG: Declarando variable '%s' de tipo %d\n", $2, $1);
        /*  función de tu tabla de símbolos*/
        actualizar_tipo_y_cat($2, $1, CAT_VAR);
    }
    | type_specifier ID '[' NUMBER ']' ';' {
        printf("DEBUG: Declarando arreglo '%s' de tipo %d con tamaño %s\n", $2, $1, $4);
        actualizar_tipo_y_cat($2, $1, CAT_VAR);
    }
    ;

type_specifier
    : INT           { $$ = INT; }          /* Si veo 'int', devuelvo el token INT */
    | FLOAT         { $$ = FLOAT; }        /* Si veo 'float', devuelvo FLOAT */
    | STRING_TYPE   { $$ = STRING_TYPE; }
    ;

/* 3. Funciones y Parámetros */
fun_declaration
    : type_specifier ID '(' param_list ')' compound_stmt { actualizar_tipo_y_cat($2, $1, CAT_FUNC); }
    | type_specifier ID '(' VOID ')' compound_stmt       { actualizar_tipo_y_cat($2, $1, CAT_FUNC); }
    | VOID ID '(' param_list ')' compound_stmt           { actualizar_tipo_y_cat($2, VOID, CAT_FUNC); }
    | VOID ID '(' VOID ')' compound_stmt                 { actualizar_tipo_y_cat($2, VOID   , CAT_FUNC); }
    ;

void_fun_declaration
    : VOID MAIN '(' VOID ')' compound_stmt { actualizar_tipo_y_cat("main", VOID, CAT_FUNC); }
    ;

param_list
    : param_list ',' param
    | param
    ;

param
    : type_specifier ID
    | type_specifier ID '[' ']'
    ;

/* 4. Bloques de Código */
compound_stmt
    : '{' local_declarations statement_list '}'
    | '{' local_declarations '}'
    | '{' statement_list '}'
    | '{' '}'
    ;

local_declarations
    : local_declarations var_declaration
    | var_declaration
    ;

statement_list
    : statement_list statement
    | statement
    ;

/* 5. Sentencias */
statement
    : var '=' expression ';'
    | var '=' STRING_LIT ';'
    | call ';'
    | compound_stmt
    | IF '(' expression ')' statement %prec LOWER_THAN_ELSE  /* <- Magia del Dangling Else */
    | IF '(' expression ')' statement ELSE statement
    | WHILE '(' expression ')' statement
    | RETURN ';'
    | RETURN expression ';'
    | READ var ';'
    | WRITE expression ';'
    ;

/* 6. Variables y Expresiones */
var
    : ID {
        int cat = obtener_categoria($1);
        if (cat == CAT_FUNC) {
            fprintf(stderr, "[SEMANTIC ERROR] Línea %d: El identificador '%s' es una función y no puede usarse como variable.\n", yylineno, $1);
        }
        $$ = $1;
    }
    | ID '[' arithmetic_expression ']' {
        int cat = obtener_categoria($1);
        if (cat == CAT_FUNC) {
            fprintf(stderr, "[SEMANTIC ERROR] Línea %d: El identificador '%s' es una función y no puede de esta manera.\n", yylineno, $1);
        }
        $$ = $1;
    }
    ;
expression
    : arithmetic_expression relop arithmetic_expression
    | arithmetic_expression
    ;

relop
    : LESSEQUAL 
    | '<' 
    | '>' 
    | MOREEQUAL 
    | EQUAL 
    | DIF
    ;

/* 7. Matemáticas */
arithmetic_expression
    : arithmetic_expression addop term
    | term
    ;

addop
    : '+' 
    | '-'
    ;

term
    : term mulop factor
    | factor
    ;

mulop
    : '*' 
    | '/'
    ;

factor
    : '(' arithmetic_expression ')'
    | var
    | call
    | NUMBER
    ;

/* 9. Llamadas a Funciones */
call
    : ID '(' arg_list ')' {
        int cat = obtener_categoria($1);
        if (cat == CAT_VAR) {
            fprintf(stderr, "[SEMANTIC ERROR] Línea %d: El identificador '%s' es una variable y no puede ser invocado como función.\n", yylineno, $1);
        }
    }
    | ID '(' ')' {
        int cat = obtener_categoria($1);
        if (cat == CAT_VAR) {
            fprintf(stderr, "[SEMANTIC ERROR] Línea %d: El identificador '%s' es una variable y no puede ser invocado como función.\n", yylineno, $1);
        }
    }
    ;

%%
/* --- CÓDIGO C --- */

extern FILE *yyin;

void yyerror(const char *s) {
    fprintf(stderr, "Error sintáctico en la línea %d: %s\n", yylineno, s);
}

void actualizar_tipo_y_cat(char *nombre, int tipo, int categoria) {
    struct ID *tp = idSymTbl;
    while (tp != NULL) {
        if (strcmp(tp->lexeme, nombre) == 0) {
            /* ¡Lo encontramos! Actualizamos su tipo y rol */
            tp->tipo_dato = tipo;
            tp->categoria = categoria;
            return;
        }
        tp = tp->next;
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Uso: ./compilador archivo.cm\n");
        return 1;
    }

    FILE *archivo = fopen(argv[1], "r");
    if (!archivo) {
        printf("Error: No se pudo abrir el archivo %s\n", argv[1]);
        return 1;
    }

    yyin = archivo;

    printf("Iniciando análisis sintáctico de %s...\n", argv[1]);
    
    if (yyparse() == 0) {
        printf("¡Análisis exitoso! El código es válido.\n");
    } else {
        printf("El análisis falló.\n");
    }
    fclose(archivo);

    return 0;
}