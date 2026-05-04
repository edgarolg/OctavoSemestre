%{


/* Compilador para el lenguaje de C--
* Author: Edgar Aviles
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>



/* ── Token IDs ─── */

/* Keywords */
#define TK_INT 1
#define TK_FLOAT 2
#define TK_STRING 3
#define TK_RETURN 4
#define TK_IF 5
#define TK_ELSE 6
#define TK_WHILE 7
#define TK_READ 8
#define TK_WRITE 9
#define TK_VOID 10


/* OPERATIONS */
#define TK_PLUS 11
#define TK_MINUS 12
#define TK_MULT 13
#define TK_DIVISION 14
#define TK_LESSTHAN 15
#define TK_LESSEQ 16
#define TK_MORETHAN 17
#define TK_MOREEQ 18
#define TK_EQUAL 19
#define TK_DIF 20

/* Others */
#define TK_ASSIGN 21
#define TK_SEMICOLON 22
#define TK_COMMA 23
#define TK_DQUOTE 24
#define TK_OPAREN     25
#define TK_CPAREN     26
#define TK_OBRACKET   27
#define TK_CBRACKET   28
#define TK_OCURLY     29
#define TK_CCURLY     30

/* Value tokens  */
#define TK_ID         31
#define TK_INT_NUM    32
#define TK_FLOAT_NUM  33
#define TK_STRING_LIT 34


/*  Tables structures */
#define MAX_LEXEME   256
#define MAX_NUMS     500
#define MAX_STRINGS  500

struct ID {
    /* Esta es la variable como tal   */
    char      lexeme[MAX_LEXEME];
    int       linea;
    struct ID *next;
};
/*  Se inicia en 0 la tabla /lista enlazada */
struct ID *idSymTbl = NULL;

/* Tablas de números para int o float */
typedef struct {
    char lexeme[256];
    int  token_type;  /* TK_INT_NUM o TK_FLOAT_NUM */
    int  linea;
} EntryNum;

EntryNum tabla_nums[MAX_NUMS];
/* Se inicia la tabla en 0 */
int count_nums = 0;


/* Tabla de strings */
typedef struct {
    char lexeme[MAX_LEXEME];
    int  linea;
} EntryString;

EntryString tabla_strings[MAX_STRINGS];
/* Se inicia la tabla en 0 */
int count_strings = 0;


/* Lista de tokens */
typedef struct {
    int  token_id;
    int  table_index;   /* índice en su tabla, -1 si no aplica */
    int  linea;
    char lexeme[MAX_LEXEME];
} TokenEntry;

TokenEntry token_list[5000];
int count_tokens = 0;
int error_count  = 0;

/* tabla para buscar los key words */
typedef struct {
    char *word;
    int   token;
} Keyword;

Keyword keywords[] = {
    {"int",    TK_INT},
    {"float",  TK_FLOAT},
    {"string", TK_STRING},
    {"return", TK_RETURN},
    {"if",     TK_IF},
    {"else",   TK_ELSE},
    {"while",  TK_WHILE},
    {"read",   TK_READ},
    {"write",  TK_WRITE},
    {"void",   TK_VOID},
    {NULL, 0}             /* centinela para saber dónde termina */
};


/* Prototipos  */
/* es un aviso sobre lo que se va a declarar despues y el como */
int lookup_keyword (char *word);

/* es al id, se va a buscar cual es */
struct ID*  lookUp_ID (char *lexeme, int linea);
int  insert_num (char *lexeme, int tipo, int linea);
int  insert_string (char *lexeme, int linea);
void add_token (int token_id, int table_index, int linea, char *lexeme);
void to_lower (char *str);
void print_token_list (void);
void print_table_ids (void);
void print_table_nums (void);
void print_table_strings (void);
void print_error (char *msg, int linea, char *lexeme);


%}


/* OPCIONES extra */

/* conteo de lineas */
%option yylineno

/* para evitar el end of file */
%option noyywrap

/* ── Regex con nombre ──────── */

LETTER      [a-zA-Z]
DIGIT       [0-9]
SIGN        [+\-]
ID          ({LETTER}(({LETTER}|{DIGIT}|_)*))|(_({LETTER}|{DIGIT})({LETTER}|{DIGIT}|_)*)
INT_NUM     {DIGIT}+
FLOAT_NUM   {DIGIT}+"."{DIGIT}+
STRING_LIT  \"[^\"\n]*\"
COMMENT     "/*"([^*]|\*+[^*/])*\*+"/"
BLANK       [ \t\n]


/*REGLAAAAAS */
%%

{COMMENT}  { /* se ignora completamente los comentarios */  }


"/*"[^*]* { 
  /* se inicio pero no se cerro */
  print_error("Unterminated comment", yylineno, yytext);
}


{BLANK}+  { /* se ignoran los espacios en blanco */ }

{STRING_LIT}   {
  /* para obtener lo que contiene el string literalmente
  * se saca el contenido, se le quitan las dobles comillas, se pone en minuscula y de ahi se inserta el contenido y la linea 
  * luego se agrega el token, si es con lista, el id, linea y texto 
  */
  char content[MAX_LEXEME];
  strncpy(content, yytext + 1, yyleng - 2);
  content[yyleng - 2] = '\0';
  to_lower(content);
  int idx = insert_string(content, yylineno);
  add_token(TK_STRING_LIT, idx, yylineno, yytext);
  return TK_STRING_LIT;
}

\"[^\"\n]*\n   {
  /* si el estring no se cerro totalmente, se pone el error */
 print_error("Unterminated string literal", yylineno, yytext);
}


"<="    { add_token(TK_LESSEQ, -1, yylineno, yytext); return TK_LESSEQ; }
">="    { add_token(TK_MOREEQ, -1, yylineno, yytext); return TK_MOREEQ; }
"=="    { add_token(TK_EQUAL,  -1, yylineno, yytext); return TK_EQUAL;  }
"!="    { add_token(TK_DIF, -1, yylineno, yytext); return TK_DIF; }

{ID} {
  /* copia el codigo para guardarlo y se asegure que sea solo la parte del id, tambien lo pasa a minuscula */
  char lower[MAX_LEXEME];
  strncpy(lower, yytext, MAX_LEXEME - 1);
  lower[MAX_LEXEME - 1] = '\0';
  to_lower(lower);
  /* buscar si es palabra reservada */
  int kw = lookup_keyword(lower);
  if (kw != 0) {
  /* es keyword */
  add_token(kw, -1, yylineno, yytext);
  return kw;
  } else {
  /* es identificador */
  struct ID *entry = lookUp_ID(lower, yylineno);
  /*busca y asigna el indice*/
  int idx = 0;
  struct ID *tp = idSymTbl;
  while (tp != entry) { tp = tp->next; idx++; }
  add_token(TK_ID, idx, yylineno, yytext);
  return TK_ID;
  }
}

"__"[a-zA-Z0-9_]*  {
  /* error de doble guion bajo*/
  print_error("Invalid identifier: double underscore", yylineno, yytext);
}
"_" {
  /* error de solo un guion bajo*/ 
  print_error("Invalid identifier: underscore alone", yylineno, yytext);
}


{FLOAT_NUM} {
  /* le asigna un indice en la tabla de numero, de ahi mete el indice que obtuvo con la informacion en la tabla general de tokens */
  int idx = insert_num(yytext, TK_FLOAT_NUM, yylineno);
  add_token(TK_FLOAT_NUM, idx, yylineno, yytext);
  return TK_FLOAT_NUM;
}

{SIGN}?{DIGIT}+"."  {
  /* error de digito con punto al final  */
  print_error("Invalid real: missing decimal part", yylineno, yytext);
}

{INT_NUM} {
  /* inserta el numero (el numero en si, el id de numero int, y la linea), de ahi mete el toquen con el indice que se genero, y la misma info a la de tokens generales */
  int idx = insert_num(yytext, TK_INT_NUM, yylineno);
  /* si no quisiera guardar otra vez el lexema (lo que es la palabrta o numero) se pone un null en el yytext */
  add_token(TK_INT_NUM, idx, yylineno, yytext);
  return TK_INT_NUM;
}

"+" { add_token(TK_PLUS, -1, yylineno, yytext); return TK_PLUS; }
"-" { add_token(TK_MINUS, -1, yylineno, yytext); return TK_MINUS; }
"*" { add_token(TK_MULT, -1, yylineno, yytext); return TK_MULT; }
"/" { add_token(TK_DIVISION, -1, yylineno, yytext); return TK_DIVISION; }
"<" { add_token(TK_LESSTHAN, -1, yylineno, yytext); return TK_LESSTHAN; }
">" { add_token(TK_MORETHAN, -1, yylineno, yytext); return TK_MORETHAN; }
"=" { add_token(TK_ASSIGN, -1, yylineno, yytext); return TK_ASSIGN; }

"!" { print_error("Invalid character: '!' without '='", yylineno, yytext); }

";" { add_token(TK_SEMICOLON, -1, yylineno, yytext); return TK_SEMICOLON; }
"," { add_token(TK_COMMA, -1, yylineno, yytext); return TK_COMMA; }
"(" { add_token(TK_OPAREN, -1, yylineno, yytext); return TK_OPAREN; }
")" { add_token(TK_CPAREN, -1, yylineno, yytext); return TK_CPAREN; }
"[" { add_token(TK_OBRACKET, -1, yylineno, yytext); return TK_OBRACKET; }
"]" { add_token(TK_CBRACKET, -1, yylineno, yytext); return TK_CBRACKET; }
"{" { add_token(TK_OCURLY, -1, yylineno, yytext); return TK_OCURLY; }
"}" { add_token(TK_CCURLY, -1, yylineno, yytext); return TK_CCURLY; }

<<EOF>> { /*regresa 0 para que el while acabe */  return 0; }
.       { print_error("Invalid character", yylineno, yytext); }

%%

/* ── to_lower: convierte string a minúsculas ── */
void to_lower(char *str) {
    int i;
    for ( i = 0; str[i]; i++)
        str[i] = tolower((unsigned char)str[i]);
}
/* buscar key word */
int lookup_keyword(char *word) {
    int i;
    for (i = 0; keywords[i].word != NULL; i++)
        if (strcmp(keywords[i].word, word) == 0)
            return keywords[i].token;
    return 0;
}


/* buscar o agregar la variabel */
struct ID* lookUp_ID(char *lexeme, int linea) {
  struct ID *tp = idSymTbl;

  /* buscar si ya existe */
  while (tp) {
    if (strcmp(tp->lexeme, lexeme) == 0)
      return tp;
    tp = tp->next;
  }

  /* no existe — agregar al inicio de la lista */
  /*guarda espacio para este */
  tp = (struct ID*) malloc(sizeof(struct ID));
  /* coppia la palabra */
  strncpy(tp->lexeme, lexeme, MAX_LEXEME - 1);
  tp->lexeme[MAX_LEXEME - 1] = '\0';
  tp->linea  = linea;
  tp->next   = idSymTbl;
  idSymTbl   = tp;
  return tp;
}

/* insertar numero */
int insert_num(char *lexeme, int tipo, int linea) {
  /* copia el texto dentro de la tabla, e indica la posicion de este*/
  strncpy(tabla_nums[count_nums].lexeme, lexeme, MAX_LEXEME - 1);
  tabla_nums[count_nums].token_type = tipo;
  tabla_nums[count_nums].linea = linea;
  return count_nums++;
}

/* insertar string */
int insert_string(char *lexeme, int linea) {
  strncpy(tabla_strings[count_strings].lexeme, lexeme, MAX_LEXEME - 1);
  tabla_strings[count_strings].linea = linea;
  return count_strings++;
}

/* agregar token */
void add_token(int token_id, int table_index, int linea, char *lexeme) {
  token_list[count_tokens].token_id    = token_id;
  token_list[count_tokens].table_index = table_index;
  token_list[count_tokens].linea       = linea;
  strncpy(token_list[count_tokens].lexeme, lexeme, MAX_LEXEME - 1);
  count_tokens++;
}

/* errores */
void print_error(char *msg, int linea, char *lexeme) {
    fprintf(stderr, "[LEXICAL ERROR] Line %d: %s -> '%s'\n",
            linea, msg, lexeme);
    error_count++;
}

/* convertir a tokens correctos */
char *token_name(int id) {
    switch(id) {
        case TK_INT: return "KW_INT";
        case TK_FLOAT: return "KW_FLOAT";
        case TK_STRING: return "KW_STRING";
        case TK_RETURN: return "KW_RETURN";
        case TK_IF: return "KW_IF";
        case TK_ELSE: return "KW_ELSE";
        case TK_WHILE: return "KW_WHILE";
        case TK_READ: return "KW_READ";
        case TK_WRITE: return "KW_WRITE";
        case TK_VOID: return "KW_VOID";
        case TK_PLUS: return "TK_PLUS";
        case TK_MINUS: return "TK_MINUS";
        case TK_MULT: return "TK_MULT";
        case TK_DIVISION: return "TK_DIVISION";
        case TK_LESSTHAN: return "TK_LT";
        case TK_LESSEQ: return "TK_LESSEQ";
        case TK_MORETHAN: return "TK_MORETHAN";
        case TK_MOREEQ: return "TK_MOREEQ";
        case TK_EQUAL: return "TK_EQUAL";
        case TK_DIF: return "TK_DIF";
        case TK_ASSIGN: return "TK_ASSIGN";
        case TK_SEMICOLON: return "TK_SEMICOLON";
        case TK_COMMA: return "TK_COMMA";
        case TK_OPAREN: return "TK_OPAREN";
        case TK_CPAREN: return "TK_CPAREN";
        case TK_OBRACKET: return "TK_OBRACKET";
        case TK_CBRACKET: return "TK_CBRACKET";
        case TK_OCURLY: return "TK_OCURLY";
        case TK_CCURLY: return "TK_CCURLY";
        case TK_ID: return "TK_ID";
        case TK_INT_NUM: return "TK_INT_NUM";
        case TK_FLOAT_NUM: return "TK_FLOAT_NUM";
        case TK_STRING_LIT: return "TK_STRING_LIT";
        default: return "UNKNOWN";
    }
}

/* imprimir todos los tokens */
void print_token_list(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  TOKEN LIST\n");
    printf("  %-4s  %-15s  %-4s  %-5s  %s\n",
           "No.", "Token", "ID", "Line", "Lexeme");
    int i;
    for (i = 0; i < count_tokens; i++) {
        printf("  %-4d  %-15s  %-4d  %-5d  %s\n",
               i + 1,
               token_name(token_list[i].token_id),
               token_list[i].token_id,
               token_list[i].linea,
               token_list[i].lexeme);
    }
    printf("  Total tokens: %d\n", count_tokens);
    printf("=============================================================\n");
}

/* imprime todas las variables o identificadores  */
void print_table_ids(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE: IDENTIFIERS\n");
    printf("  %-6s  %-30s  %s\n", "Index", "Lexeme", "First Line");
    struct ID *tp = idSymTbl;
    int i = 0;
    while (tp) {
        /* formato de impresion */
        printf("  %-6d  %-30s  %d\n", i, tp->lexeme, tp->linea);
        tp = tp->next;
        i++;
    }
    printf("  Total identifiers: %d\n", i);
    printf("=============================================================\n");
}

/* imprime todos los numeros  */
void print_table_nums(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE: NUMBERS\n");
    printf("  %-6s  %-15s  %-12s  %s\n",
           "Index", "Lexeme", "Type", "Line");
    int i;
    for ( i = 0; i < count_nums; i++) {
        printf("  %-6d  %-15s  %-12s  %d\n",
               i,
               tabla_nums[i].lexeme,
               tabla_nums[i].token_type == TK_INT_NUM ? "INTEGER" : "FLOAT",
               tabla_nums[i].linea);
    }
    printf("  Total numbers: %d\n", count_nums);
    printf("=============================================================\n");
}

/* imprime los strings encontrados */
void print_table_strings(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE: STRINGS\n");
    printf("  %-6s  %-40s  %s\n", "Index", "Content", "Line");
    int i;
    for (i = 0; i < count_strings; i++) {
        printf("  %-6d  %-40s  %d\n",
               i,
               tabla_strings[i].lexeme,
               tabla_strings[i].linea);
    }
    printf("  Total strings: %d\n", count_strings);
    printf("=============================================================\n");
}

/* archivo principal */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <archivo.cm>\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "r");
    if (!fp) {
        fprintf(stderr, "ERROR: No se pudo abrir '%s'\n", argv[1]);
        return 1;
    }

    printf("=============================================================\n");
    printf("  C-- Lexical Analyzer\n");
    printf("  File: %s\n", argv[1]);

    /* apuntar lex al archivo de entrada */
    yyin = fp;

    /* correr el scanner */
    while (yylex() != 0);

    fclose(fp);

    /* imprimir resultados */
    print_token_list();
    print_table_ids();
    print_table_nums();
    print_table_strings();

    /* resumen final */
    printf("\n");
    printf("=============================================================\n");
    printf("  SCAN COMPLETE\n");
    printf("  Tokens   : %d\n", count_tokens);
    printf("  IDs      : %d\n", /* contar linked list */
           ({ int n=0; struct ID*t=idSymTbl; while(t){n++;t=t->next;} n; }));
    printf("  Numbers  : %d\n", count_nums);
    printf("  Strings  : %d\n", count_strings);
    printf("  Errors   : %d\n", error_count);

    return (error_count > 0) ? 1 : 0;
}