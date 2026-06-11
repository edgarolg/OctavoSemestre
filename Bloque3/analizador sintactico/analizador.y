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
    char lexeme[256];
    int linea;
    int tipo_dato;
    int categoria;
struct ID *next;
};
extern struct ID *idSymTbl;

typedef struct {
    int token_id;
    int table_index;   
    int linea;
    char lexeme[256]; 
} EntryToken;

extern EntryToken token_list[];
extern int count_tokens;
extern char *token_name(int id);

%}

/* forma de almacenar las cosa que manda el lexico */
%union {
    char *cadena;  /* guaradr nombres*/
    int  tipo_dato; /* guardar int, float o string */
}

%token <cadena> ID NUMBER STRING_LIT
%type <tipo_dato> type_specifier
%type <cadena> var

/* Declaración de Tokens */
%token INT FLOAT STRING_TYPE VOID MAIN
%token IF ELSE WHILE RETURN READ WRITE
%token LESSEQUAL "<="
%token MOREEQUAL ">="
%token EQUAL "=="
%token DIF "!="


%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

/* --- REGLAAAAAS--- */

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

var_declaration
    : type_specifier ID ';' {
        actualizar_tipo_y_cat($2, $1, CAT_VAR);
    }
    | type_specifier ID '[' NUMBER ']' ';' {
        actualizar_tipo_y_cat($2, $1, CAT_VAR);
    }
    ;

type_specifier
    : INT           { $$ = INT; }
    | FLOAT         { $$ = FLOAT; }
    | STRING_TYPE   { $$ = STRING_TYPE; }
    ;

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
    : type_specifier ID { actualizar_tipo_y_cat($2, $1, CAT_VAR); }
    | type_specifier ID '[' ']' { actualizar_tipo_y_cat($2, $1, CAT_VAR); }
    ;

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

statement
    : var '=' expression ';'
    | var '=' STRING_LIT ';'
    | call ';'
    | compound_stmt
    | IF '(' expression ')' statement %prec LOWER_THAN_ELSE
    | IF '(' expression ')' statement ELSE statement
    | WHILE '(' expression ')' statement
    | RETURN ';'
    | RETURN expression ';'
    | READ var ';'
    | WRITE expression ';'
    ;

var
    : ID {
        int cat = obtener_categoria($1);
        if (cat == CAT_FUNC) {
            fprintf(stderr, "[SEMANTIC ERROR] Linea %d: El identificador '%s' es una funcion y no puede usarse como variable.\n", yylineno, $1);
        }
        $$ = $1;
    }
    | ID '[' arithmetic_expression ']' {
        int cat = obtener_categoria($1);
        if (cat == CAT_FUNC) {
            fprintf(stderr, "[SEMANTIC ERROR] Linea %d: El identificador '%s' es una funcion y no puede de esta manera.\n", yylineno, $1);
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

call
    : ID '(' args ')' {
        int cat = obtener_categoria($1);
        if (cat == CAT_VAR) {
            fprintf(stderr, "[SEMANTIC ERROR] Linea %d: El identificador '%s' es una variable y no puede ser invocado como funcion.\n", yylineno, $1);
        }
    }
    | ID '(' ')' {
        int cat = obtener_categoria($1);
        if (cat == CAT_VAR) {
            fprintf(stderr, "[SEMANTIC ERROR] Linea %d: El identificador '%s' es una variable y no puede ser invocado como funcion.\n", yylineno, $1);
        }
    }
    ;

args
    : arg_list
    ;

arg_list
    : arg_list ',' arithmetic_expression
    | arithmetic_expression
    ;
%%


/* --- CÓDIGO C --- */

extern FILE *yyin;

void yyerror(const char *s) {
    fprintf(stderr, "Error sintactico en la linea %d: %s\n", yylineno, s);
}

void actualizar_tipo_y_cat(char *nombre, int tipo, int categoria) {
    struct ID *tp = idSymTbl;
    while (tp != NULL) {
        if (strcmp(tp->lexeme, nombre) == 0) {
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

    printf("Iniciando analisis\n");
    
    if (yyparse() == 0) {
        printf("Analisis exitoso\n");
    } else {
        printf("El analisis fallo.\n");
    }
    fclose(archivo);

    printf("\n=================================================================\n");
    printf("TABLA DE SIMBOLOS (IDENTIFICADORES)\n");
    printf("%-20s  %-10s  %-15s\n", "Identificador", "Linea", "Rol Semantico");


    struct ID *actual = idSymTbl;
    while (actual != NULL) {
        char *rol = "---";
        if (actual->categoria == CAT_VAR) {
            rol = "VARIABLE";
        } else if (actual->categoria == CAT_FUNC) {
            rol = "FUNCION";
        }

        // Imprimir el lexeme único
        printf("%-20s  %-10d  %-15s\n", actual->lexeme, actual->linea, rol);
        actual = actual->next;
    }

    return 0;
}