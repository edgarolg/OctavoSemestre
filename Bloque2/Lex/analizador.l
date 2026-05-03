%{



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

/* others */
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
    char      lexeme[MAX_LEXEME];  /* también cambia *name por array */
    int       linea;
    struct ID *next;
};

struct ID *idSymTbl = NULL;

/* Tablas de números int o float */
typedef struct {
    char lexeme[256];
    int  token_type;  /* TK_INT_NUM o TK_FLOAT_NUM */
    int  linea;
} EntryNum;

EntryNum tabla_nums[MAX_NUMS];
/* donde inicia la tabla */
int count_nums = 0;


/* Tabla de strings */
typedef struct {
    char lexeme[MAX_LEXEME];
    int  linea;
} EntryString;

EntryString tabla_strings[MAX_STRINGS];
/* donde inicia la tabla */
int count_strings = 0;


/* lista de tokens */
typedef struct {
    int  token_id;
    int  table_index;   /* índice en su tabla, -1 si no aplica */
    int  linea;
    char lexeme[MAX_LEXEME];
} TokenEntry;

TokenEntry token_list[5000];
int count_tokens = 0;
int error_count  = 0;

/* ── Lookup table de keywords ───────────────── */
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


/* ── Prototipos ─────────────────────────────── */
/* es un aviso sobre lo que se va a declarar despues y e l como */
int lookup_keyword (char *word);
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
INT_NUM     {SIGN}?{DIGIT}+
FLOAT_NUM   {SIGN}?{DIGIT}+"."{DIGIT}+
STRING_LIT  \"[^\"\n]*\"
COMMENT     "/*"([^*]|\*+[^*/])*\*+"/"
BLANK       [ \t\n]


/*REGLAAAAAS */
%%

/* comentarios */

{COMMENT}  {   }


"/*"[^*]* { 
  print_error("Unterminated comment", yylineno, yytext);
}

/* blancos */

{BLANK}+  {  }

/* string */
{STRING_LIT}   {
  char content[MAX_LEXEME];
  strncpy(content, yytext + 1, yyleng - 2);
  content[yyleng - 2] = '\0';
  to_lower(content);
  int idx = insert_string(content, yylineno);
  add_token(TK_STRING_LIT, idx, yylineno, yytext);
  return TK_STRING_LIT;
}

/* string sin cerrar — llegó newline antes de " */
\"[^\"\n]*\n   {
 print_error("Unterminated string literal", yylineno, yytext);
}


/* Operadores dobles  */
"<="    { add_token(TK_LESSEQ, -1, yylineno, yytext); return TK_LESSEQ; }
">="    { add_token(TK_MOREEQ, -1, yylineno, yytext); return TK_MOREEQ; }
"=="    { add_token(TK_EQUAL,  -1, yylineno, yytext); return TK_EQUAL;  }
"!="    { add_token(TK_DIF, -1, yylineno, yytext); return TK_DIF; }

/* ── 5. Keywords e Identificadores ─────────── */
{ID}                {
  char lower[MAX_LEXEME];
  strncpy(lower, yytext, MAX_LEXEME - 1);
  lower[MAX_LEXEME - 1] = '\0';
  to_lower(lower);

  int kw = lookup_keyword(lower);
  if (kw != 0) {
  /* es keyword */
  add_token(kw, -1, yylineno, yytext);
  return kw;
  } else {
  /* es identificador */
  struct ID *entry = lookUp_ID(lower, yylineno);
  int idx = 0;
  struct ID *tp = idSymTbl;
  while (tp != entry) { tp = tp->next; idx++; }
  add_token(TK_ID, idx, yylineno, yytext);
  return TK_ID;
  }
}

/* identificador inválido: doble underscore */
"__"[a-zA-Z0-9_]*  {
 print_error("Invalid identifier: double underscore", yylineno, yytext);
}
/* de este tengo duda, pq si puede ser un identificador en base al doc, pero no es algo que se use */
/* underscore solo */
"_"                 { 
  print_error("Invalid identifier: underscore alone", yylineno, yytext);
}
/* numeros */
{FLOAT_NUM} {
int idx = insert_num(yytext, TK_FLOAT_NUM, yylineno);
add_token(TK_FLOAT_NUM, idx, yylineno, yytext);
return TK_FLOAT_NUM;
}

{SIGN}?{DIGIT}+"."  {
print_error("Invalid real: missing decimal part", yylineno, yytext);
}

{INT_NUM} {
int idx = insert_num(yytext, TK_INT_NUM, yylineno);
add_token(TK_INT_NUM, idx, yylineno, yytext);
return TK_INT_NUM;
}

/* operadores */
"+"     { add_token(TK_PLUS,   -1, yylineno, yytext); return TK_PLUS;   }
"-"     { add_token(TK_MINUS,  -1, yylineno, yytext); return TK_MINUS;  }
"*"     { add_token(TK_MULT,   -1, yylineno, yytext); return TK_MULT;   }
"/"     { add_token(TK_DIV,    -1, yylineno, yytext); return TK_DIV;    }
"<"     { add_token(TK_LESSTHAN,     -1, yylineno, yytext); return TK_LESSTHAN;     }
">"     { add_token(TK_MORETHAN,     -1, yylineno, yytext); return TK_MORETHAN;     }
"="     { add_token(TK_ASSIGN, -1, yylineno, yytext); return TK_ASSIGN; }

/* ! solo es inválido en C-- */
"!"     { print_error("Invalid character: '!' without '='", yylineno, yytext); }

/* simbolos */
";"     { add_token(TK_SEMI,     -1, yylineno, yytext); return TK_SEMI;     }
","     { add_token(TK_COMMA,    -1, yylineno, yytext); return TK_COMMA;    }
"("     { add_token(TK_OPAREN,   -1, yylineno, yytext); return TK_OPAREN;   }
")"     { add_token(TK_CPAREN,   -1, yylineno, yytext); return TK_CPAREN;   }
"["     { add_token(TK_OBRACKET, -1, yylineno, yytext); return TK_OBRACKET; }
"]"     { add_token(TK_CBRACKET, -1, yylineno, yytext); return TK_CBRACKET; }
"{"     { add_token(TK_OCURLY,   -1, yylineno, yytext); return TK_OCURLY;   }
"}"     { add_token(TK_CCURLY,   -1, yylineno, yytext); return TK_CCURLY;   }

/* errores */
<<EOF>> { return 0; }
.       { print_error("Invalid character", yylineno, yytext); }

%%

/* ── to_lower: convierte string a minúsculas ── */
/* verificar si esto es necesario pq si habia algo sobre las mayu y muinus */
void to_lower(char *str) {
    for (int i = 0; str[i]; i++)
        str[i] = tolower((unsigned char)str[i]);
}
/* buscar key word */
int lookup_keyword(char *word) {
    for (int i = 0; keywords[i].word != NULL; i++)
        if (strcmp(keywords[i].word, word) == 0)
            return keywords[i].token;
    return 0;
}


/* buscar o agregar el id */
struct ID* lookUp_ID(char *lexeme, int linea) {
  struct ID *tp = idSymTbl;

  /* buscar si ya existe */
  while (tp) {
      if (strcmp(tp->lexeme, lexeme) == 0)
          return tp;
      tp = tp->next;
  }

  /* no existe — agregar al inicio de la lista */
  tp = (struct ID*) malloc(sizeof(struct ID));
  strncpy(tp->lexeme, lexeme, MAX_LEXEME - 1);
  tp->lexeme[MAX_LEXEME - 1] = '\0';
  tp->linea  = linea;
  tp->next   = idSymTbl;
  idSymTbl   = tp;
  return tp;
}

/* insertar numero */
int insert_num(char *lexeme, int tipo, int linea) {
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


/* ── token_name ────────────────────────────────
 * Convierte un token ID a su nombre legible.    */
char *token_name(int id) {
    switch(id) {
        case TK_INT:        return "KW_INT";
        case TK_FLOAT:      return "KW_FLOAT";
        case TK_STRING:     return "KW_STRING";
        case TK_RETURN:     return "KW_RETURN";
        case TK_IF:         return "KW_IF";
        case TK_ELSE:       return "KW_ELSE";
        case TK_WHILE:      return "KW_WHILE";
        case TK_READ:       return "KW_READ";
        case TK_WRITE:      return "KW_WRITE";
        case TK_VOID:       return "KW_VOID";
        case TK_PLUS:       return "TK_PLUS";
        case TK_MINUS:      return "TK_MINUS";
        case TK_MULT:       return "TK_MULT";
        case TK_DIV:        return "TK_DIV";
        case TK_LT:         return "TK_LT";
        case TK_LEQ:        return "TK_LEQ";
        case TK_GT:         return "TK_GT";
        case TK_GEQ:        return "TK_GEQ";
        case TK_EQ:         return "TK_EQ";
        case TK_NEQ:        return "TK_NEQ";
        case TK_ASSIGN:     return "TK_ASSIGN";
        case TK_SEMI:       return "TK_SEMI";
        case TK_COMMA:      return "TK_COMMA";
        case TK_LPAREN:     return "TK_LPAREN";
        case TK_RPAREN:     return "TK_RPAREN";
        case TK_LBRACKET:   return "TK_LBRACKET";
        case TK_RBRACKET:   return "TK_RBRACKET";
        case TK_LCURLY:     return "TK_LCURLY";
        case TK_RCURLY:     return "TK_RCURLY";
        case TK_ID:         return "TK_ID";
        case TK_INT_NUM:    return "TK_INT_NUM";
        case TK_FLOAT_NUM:  return "TK_FLOAT_NUM";
        case TK_STRING_LIT: return "TK_STRING_LIT";
        default:            return "UNKNOWN";
    }
}

/* ── print_token_list ──────────────────────────
 * Imprime la secuencia completa de tokens.      */
void print_token_list(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  TOKEN LIST\n");
    printf("=============================================================\n");
    printf("  %-4s  %-15s  %-4s  %-5s  %s\n",
           "No.", "Token", "ID", "Line", "Lexeme");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_tokens; i++) {
        printf("  %-4d  %-15s  %-4d  %-5d  %s\n",
               i + 1,
               token_name(token_list[i].token_id),
               token_list[i].token_id,
               token_list[i].linea,
               token_list[i].lexeme);
    }
    printf("=============================================================\n");
    printf("  Total tokens: %d\n", count_tokens);
    printf("=============================================================\n");
}

/* ── print_table_ids ───────────────────────────
 * Imprime la tabla de identificadores.
 * Recorre la linked list de idSymTbl.           */
void print_table_ids(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — IDENTIFIERS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-30s  %s\n", "Index", "Lexeme", "First Line");
    printf("-------------------------------------------------------------\n");
    struct ID *tp = idSymTbl;
    int i = 0;
    while (tp) {
        printf("  %-6d  %-30s  %d\n", i, tp->lexeme, tp->linea);
        tp = tp->next;
        i++;
    }
    printf("=============================================================\n");
    printf("  Total identifiers: %d\n", i);
    printf("=============================================================\n");
}

/* ── print_table_nums ──────────────────────────
 * Imprime la tabla de números.                  */
void print_table_nums(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — NUMBERS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-15s  %-12s  %s\n",
           "Index", "Lexeme", "Type", "Line");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_nums; i++) {
        printf("  %-6d  %-15s  %-12s  %d\n",
               i,
               tabla_nums[i].lexeme,
               tabla_nums[i].token_type == TK_INT_NUM ? "INTEGER" : "FLOAT",
               tabla_nums[i].linea);
    }
    printf("=============================================================\n");
    printf("  Total numbers: %d\n", count_nums);
    printf("=============================================================\n");
}

/* ── print_table_strings ───────────────────────
 * Imprime la tabla de strings.                  */
void print_table_strings(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — STRINGS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-40s  %s\n", "Index", "Content", "Line");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_strings; i++) {
        printf("  %-6d  %-40s  %d\n",
               i,
               tabla_strings[i].lexeme,
               tabla_strings[i].linea);
    }
    printf("=============================================================\n");
    printf("  Total strings: %d\n", count_strings);
    printf("=============================================================\n");
}

/* ── main ──────────────────────────────────────
 * Abre el archivo pasado como argumento,
 * corre el scanner y muestra los resultados.    */
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
    printf("=============================================================\n");

    /* apuntar lex al archivo de entrada */
    yyin = fp;

    /* correr el scanner */
    yylex();

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
    printf("=============================================================\n");

    return (error_count > 0) ? 1 : 0;
}