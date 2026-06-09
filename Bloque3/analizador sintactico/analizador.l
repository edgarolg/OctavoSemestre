%{


/* Compilador para el lenguaje de C--
* Author: Edgar Aviles
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "parser.tab.h"

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
    int  token_type;  /* NUMBER o TK_FLOAT_NUM */
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
    {"int",    INT},
    {"float",  FLOAT},
    {"string", STRING_TYPE},
    {"return", RETURN},
    {"if",     IF},
    {"else",   ELSE},
    {"while",  WHILE},
    {"read",   READ},
    {"write",  WRITE},
    {"void",   VOID},
    {NULL, 0}             /* centinela para saber dónde termina */
};


/* Prototipos  */
/* es un aviso sobre lo que se va a declarar despues y el como */
int lookup_keyword (char *word);

/* es al id, se va a buscar cual es */
struct ID*  lookUp_ID (char *lexeme, int linea, int tipo_dato;);
int  insert_num (char *lexeme, int tipo, int linea);
int  insert_string (char *lexeme, int linea);
void add_token (int token_id, int table_index, int linea, char *lexeme);
void to_lower (char *str);
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
/* primero la comilla doble, luego cualquier cosa excepto comillas o salto de linea, al final otra comilla doble */
STRING_LIT  \"[^\"\n]*\"
/* inicia el comentarios, cualquier cosa que no sea asterisco, siendo que uno o mas asteriscos no cierran el comentario, luego ya el asterisco mas la diagonal, cierra el comentario */
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
  yylval.cadena = strdup(content);
  add_token(STRING_LIT, idx, yylineno, yytext);
  return STRING_LIT;
}

\"[^\"\n]*\n   {
  /* si el estring no se cerro totalmente, se pone el error */
 print_error("Unterminated string literal", yylineno, yytext);
}


"<="    { add_token(LESSEQUAL, -1, yylineno, yytext); return LESSEQUAL; }
">="    { add_token(MOREEQUAL, -1, yylineno, yytext); return MOREEQUAL; }
"=="    { add_token(EQUAL,  -1, yylineno, yytext); return EQUAL;  }
"!="    { add_token(DIF, -1, yylineno, yytext); return DIF; }

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
  yylval.cadena = strdup(lower);
  /*busca y asigna el indice*/
  int idx = 0;
  struct ID *tp = idSymTbl;
  while (tp != entry) { tp = tp->next; idx++; }
  add_token(ID, idx, yylineno, yytext);
  return ID;
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
  int idx = insert_num(yytext, NUMBER, yylineno);
  yylval.cadena = strdup(yytext);
  add_token(NUMBER, idx, yylineno, yytext);
  return NUMBER;
}

{SIGN}?{DIGIT}+"."  {
  /* error de digito con punto al final  */
  print_error("Invalid real: missing decimal part", yylineno, yytext);
}

{INT_NUM} {
  /* inserta el numero (el numero en si, el id de numero int, y la linea), de ahi mete el toquen con el indice que se genero, y la misma info a la de tokens generales */
  int idx = insert_num(yytext, NUMBER, yylineno);
  yylval.cadena = strdup(yytext);
  /* si no quisiera guardar otra vez el lexema (lo que es la palabrta o numero) se pone un null en el yytext */
  add_token(NUMBER, idx, yylineno, yytext);
  return NUMBER;
}

"+" { add_token('+', -1, yylineno, yytext); return '+'; }
"-" { add_token('-', -1, yylineno, yytext); return '-'; }
"*" { add_token('*', -1, yylineno, yytext); return '*'; }
"/" { add_token('/', -1, yylineno, yytext); return '/'; }
"<" { add_token('<', -1, yylineno, yytext); return '<'; }
">" { add_token('>', -1, yylineno, yytext); return '>'; }
"=" { add_token('=', -1, yylineno, yytext); return '='; }

"!" { print_error("Invalid character: '!' without '='", yylineno, yytext); }

";" { add_token(';', -1, yylineno, yytext); return ';'; }
"," { add_token(',', -1, yylineno, yytext); return ','; }
"(" { add_token('(', -1, yylineno, yytext); return '('; }
")" { add_token(')', -1, yylineno, yytext); return ')'; }
"[" { add_token('[', -1, yylineno, yytext); return '['; }
"]" { add_token(']', -1, yylineno, yytext); return ']'; }
"{" { add_token('{', -1, yylineno, yytext); return '{'; }
"}" { add_token('}', -1, yylineno, yytext); return '}'; }

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
  int i;
  for (i = 0; i < count_nums; i++) {
    if (strcmp(tabla_nums[i].lexeme, lexeme) == 0 && tabla_nums[i].token_type == tipo) {
        return i;
    }
  }
  /* copia el texto dentro de la tabla, e indica la posicion de este*/
  strncpy(tabla_nums[count_nums].lexeme, lexeme, MAX_LEXEME - 1);
  tabla_nums[count_nums].token_type = tipo;
  tabla_nums[count_nums].linea = linea;
  return count_nums++;
}

/* insertar string */
int insert_string(char *lexeme, int linea) {
  int i;
  for (i = 0; i < count_strings; i++) {
    if (strcmp(tabla_strings[i].lexeme, lexeme) == 0) {
      return i;
    }
  }
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
        case INT: return "KW_INT";
        case FLOAT: return "KW_FLOAT";
        case STRING_TYPE: return "KW_STRING";
        case RETURN: return "KW_RETURN";
        case IF: return "KW_IF";
        case ELSE: return "KW_ELSE";
        case WHILE: return "KW_WHILE";
        case READ: return "KW_READ";
        case WRITE: return "KW_WRITE";
        case VOID: return "KW_VOID";
        case '+': return "TK_PLUS";
        case '-': return "TK_MINUS";
        case '*': return "TK_MULT";
        case '/': return "TK_DIVISION";
        case '<': return "TK_LT";
        case LESSEQUAL: return "TK_LESSEQ";
        case '>': return "TK_MORETHAN";
        case MOREEQUAL: return "TK_MOREEQ";
        case EQUAL: return "TK_EQUAL";
        case DIF: return "TK_DIF";
        case '=': return "TK_ASSIGN";
        case ';': return "TK_SEMICOLON";
        case ',': return "TK_COMMA";
        case '(': return "TK_OPAREN";
        case ')': return "TK_CPAREN";
        case '[': return "TK_OBRACKET";
        case ']': return "TK_CBRACKET";
        case '{': return "TK_OCURLY";
        case '}': return "TK_CCURLY";
        case ID: return "ID";
        case NUMBER: return "NUMBER";
        case STRING_LIT: return "TK_STRING_LIT";
        default: return "UNKNOWN";
    }
}
