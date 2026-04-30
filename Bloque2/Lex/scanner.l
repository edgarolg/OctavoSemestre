%{
/*=============================================================================
 * scanner.l  —  Lexical Analyzer for C-- Language
 * TC3002B  —  Module #3: Compilers
 *
 * Author : [Tu nombre]
 * Date   : 2026
 *
 * Description:
 *   This file implements the lexical analyzer (scanner) for the C-- language,
 *   a subset of C. It recognizes all valid tokens, builds the symbol tables,
 *   and reports lexical errors with line numbers.
 *
 * Sections:
 *   1. Definitions  — includes, token IDs, symbol table structures
 *   2. Rules        — regex patterns and actions for each token
 *   3. User Code    — main(), symbol table functions, helpers
 *=============================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ── Token IDs ────────────────────────────────────────────────────────────── */
/* Keywords */
#define TK_INT        1
#define TK_FLOAT      2
#define TK_STRING     3
#define TK_RETURN     4
#define TK_IF         5
#define TK_ELSE       6
#define TK_WHILE      7
#define TK_READ       8
#define TK_WRITE      9
#define TK_VOID       10

/* Arithmetic operators */
#define TK_PLUS       11
#define TK_MINUS      12
#define TK_MULT       13
#define TK_DIV        14

/* Relational operators */
#define TK_LT         15
#define TK_LEQ        16
#define TK_GT         17
#define TK_GEQ        18
#define TK_EQ         19
#define TK_NEQ        20

/* Assignment */
#define TK_ASSIGN     21

/* Punctuation */
#define TK_SEMI       22
#define TK_COMMA      23
#define TK_DQUOTE     24
#define TK_LPAREN     25
#define TK_RPAREN     26
#define TK_LBRACKET   27
#define TK_RBRACKET   28
#define TK_LCURLY     29
#define TK_RCURLY     30

/* Value tokens (stored in symbol tables) */
#define TK_ID         31
#define TK_INT_NUM    32
#define TK_FLOAT_NUM  33
#define TK_STRING_LIT 34

/* ── Symbol Table Sizes ───────────────────────────────────────────────────── */
#define MAX_IDS      500
#define MAX_NUMS     500
#define MAX_STRINGS  500
#define MAX_LEXEME   256

/* ── Symbol Table Structures ─────────────────────────────────────────────── */

/* Identifier table entry */
typedef struct {
    char  lexeme[MAX_LEXEME];
    int   line;
} EntryID;

/* Number table entry (used for both int and float) */
typedef struct {
    char  lexeme[MAX_LEXEME];
    int   token_type;   /* TK_INT_NUM or TK_FLOAT_NUM */
    int   line;
} EntryNum;

/* String literal table entry */
typedef struct {
    char  lexeme[MAX_LEXEME];
    int   line;
} EntryString;

/* Token list entry — the output sequence */
typedef struct {
    int   token_id;
    int   table_index;  /* index in its symbol table, -1 if not applicable */
    int   line;
    char  lexeme[MAX_LEXEME];
} TokenEntry;

/* ── Global Tables ───────────────────────────────────────────────────────── */
EntryID     table_ids    [MAX_IDS];
EntryNum    table_nums   [MAX_NUMS];
EntryString table_strings[MAX_STRINGS];
TokenEntry  token_list   [5000];

int count_ids     = 0;
int count_nums    = 0;
int count_strings = 0;
int count_tokens  = 0;
int error_count   = 0;

/* ── Keyword lookup table ────────────────────────────────────────────────── */
typedef struct { char *word; int token; } Keyword;

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
    {NULL, 0}
};

/* ── Function prototypes ─────────────────────────────────────────────────── */
int  lookup_keyword(char *word);
int  lookup_or_insert_id(char *lexeme, int line);
int  insert_num(char *lexeme, int token_type, int line);
int  insert_string(char *lexeme, int line);
void add_token(int token_id, int table_index, int line, char *lexeme);
void to_lower(char *str);
void print_token_list(void);
void print_table_ids(void);
void print_table_nums(void);
void print_table_strings(void);
void print_error(char *msg, int line, char *lexeme);

%}

/* ── Flex options ────────────────────────────────────────────────────────── */
%option yylineno
%option noyywrap

/* ── Named definitions (regex macros) ───────────────────────────────────── */
LETTER      [a-zA-Z]
DIGIT       [0-9]
UNDERSCORE  "_"
SIGN        [+\-]

/* Identifier: starts with letter or underscore
   If starts with underscore, must be followed by letter or digit */
ID          ({LETTER}({LETTER}|{DIGIT}|{UNDERSCORE})*)|({UNDERSCORE}({LETTER}|{DIGIT})({LETTER}|{DIGIT}|{UNDERSCORE})*)

/* Numbers */
INT_NUM     {SIGN}?{DIGIT}+
FLOAT_NUM   {SIGN}?{DIGIT}+"."{DIGIT}+

/* String literal: any char except " and newline between double quotes */
STRING_LIT  \"[^\"\n]*\"

/* Comments: C-style block comments */
COMMENT     "/*"([^*]|\*+[^*/])*\*+"/"

/* Blanks */
BLANK       [ \t\n]

%%

/*=============================================================================
 * SECTION 2 — RULES
 * Format: pattern   { action in C }
 * yytext  = matched lexeme string
 * yylineno = current line number
 *=============================================================================*/

/* ── Comments: recognized and discarded ──────────────────────────────────── */
{COMMENT}       {
                    /* Comments are ignored, not added to token list */
                }

/* Unterminated comment — EOF reached inside comment */
"/*"[^*]*       {
                    print_error("Unterminated comment", yylineno, yytext);
                }

/* ── Blanks: recognized and discarded ───────────────────────────────────── */
{BLANK}+        { /* ignore whitespace */ }

/* ── String literals ─────────────────────────────────────────────────────── */
{STRING_LIT}    {
                    /* Remove surrounding quotes before storing */
                    char content[MAX_LEXEME];
                    strncpy(content, yytext + 1, yyleng - 2);
                    content[yyleng - 2] = '\0';
                    to_lower(content);
                    int idx = insert_string(content, yylineno);
                    add_token(TK_STRING_LIT, idx, yylineno, yytext);
                    return TK_STRING_LIT;
                }

/* Unterminated string — newline reached before closing quote */
\"[^\"\n]*\n    {
                    print_error("Unterminated string literal", yylineno, yytext);
                }

/* ── Identifiers and Keywords ────────────────────────────────────────────── */
{ID}            {
                    char lower[MAX_LEXEME];
                    strncpy(lower, yytext, MAX_LEXEME - 1);
                    lower[MAX_LEXEME - 1] = '\0';
                    to_lower(lower);

                    int kw = lookup_keyword(lower);
                    if (kw != 0) {
                        /* It is a keyword */
                        add_token(kw, -1, yylineno, yytext);
                        return kw;
                    } else {
                        /* It is an identifier */
                        int idx = lookup_or_insert_id(lower, yylineno);
                        add_token(TK_ID, idx, yylineno, yytext);
                        return TK_ID;
                    }
                }

/* Invalid identifier: starts with double underscore */
"__"[a-zA-Z0-9_]* {
                    print_error("Invalid identifier (double underscore)", yylineno, yytext);
                }

/* Invalid identifier: underscore alone */
"_"             {
                    print_error("Invalid identifier (underscore alone)", yylineno, yytext);
                }

/* ── Float numbers (must match before int to avoid partial match) ─────────── */
{FLOAT_NUM}     {
                    int idx = insert_num(yytext, TK_FLOAT_NUM, yylineno);
                    add_token(TK_FLOAT_NUM, idx, yylineno, yytext);
                    return TK_FLOAT_NUM;
                }

/* ── Integer numbers ─────────────────────────────────────────────────────── */
{INT_NUM}       {
                    int idx = insert_num(yytext, TK_INT_NUM, yylineno);
                    add_token(TK_INT_NUM, idx, yylineno, yytext);
                    return TK_INT_NUM;
                }

/* Number with no decimal part after dot: error */
{SIGN}?{DIGIT}+"." {
                    print_error("Invalid real number (missing decimal part)", yylineno, yytext);
                }

/* Sign alone: error */
[+\-]           {
                    /* Could be operator or sign — handled as operator here */
                    if (yytext[0] == '+') {
                        add_token(TK_PLUS, -1, yylineno, yytext);
                        return TK_PLUS;
                    } else {
                        add_token(TK_MINUS, -1, yylineno, yytext);
                        return TK_MINUS;
                    }
                }

/* ── Relational operators (two-char first) ───────────────────────────────── */
"<="            { add_token(TK_LEQ, -1, yylineno, yytext); return TK_LEQ; }
">="            { add_token(TK_GEQ, -1, yylineno, yytext); return TK_GEQ; }
"=="            { add_token(TK_EQ,  -1, yylineno, yytext); return TK_EQ;  }
"!="            { add_token(TK_NEQ, -1, yylineno, yytext); return TK_NEQ; }

/* Single relational */
"<"             { add_token(TK_LT,     -1, yylineno, yytext); return TK_LT;     }
">"             { add_token(TK_GT,     -1, yylineno, yytext); return TK_GT;     }
"="             { add_token(TK_ASSIGN, -1, yylineno, yytext); return TK_ASSIGN; }

/* ! alone is invalid in C-- */
"!"             { print_error("Invalid character '!' without '='", yylineno, yytext); }

/* ── Arithmetic operators ────────────────────────────────────────────────── */
"*"             { add_token(TK_MULT, -1, yylineno, yytext); return TK_MULT; }
"/"             { add_token(TK_DIV,  -1, yylineno, yytext); return TK_DIV;  }

/* ── Punctuation ─────────────────────────────────────────────────────────── */
";"             { add_token(TK_SEMI,     -1, yylineno, yytext); return TK_SEMI;     }
","             { add_token(TK_COMMA,    -1, yylineno, yytext); return TK_COMMA;    }
"("             { add_token(TK_LPAREN,   -1, yylineno, yytext); return TK_LPAREN;   }
")"             { add_token(TK_RPAREN,   -1, yylineno, yytext); return TK_RPAREN;   }
"["             { add_token(TK_LBRACKET, -1, yylineno, yytext); return TK_LBRACKET; }
"]"             { add_token(TK_RBRACKET, -1, yylineno, yytext); return TK_RBRACKET; }
"{"             { add_token(TK_LCURLY,   -1, yylineno, yytext); return TK_LCURLY;   }
"}"             { add_token(TK_RCURLY,   -1, yylineno, yytext); return TK_RCURLY;   }

/* ── EOF inside unterminated comment ─────────────────────────────────────── */
<<EOF>>         {
                    /* Normal EOF — stop scanning */
                    return 0;
                }

/* ── Catch-all: any unrecognized character ───────────────────────────────── */
.               {
                    print_error("Invalid character", yylineno, yytext);
                }

%%

/*=============================================================================
 * SECTION 3 — USER CODE
 * Helper functions and main()
 *=============================================================================*/

/* ── to_lower: converts string to lowercase in-place ─────────────────────── */
void to_lower(char *str) {
    for (int i = 0; str[i]; i++)
        str[i] = tolower((unsigned char)str[i]);
}

/* ── lookup_keyword: returns token ID if word is a keyword, 0 otherwise ──── */
int lookup_keyword(char *word) {
    for (int i = 0; keywords[i].word != NULL; i++)
        if (strcmp(keywords[i].word, word) == 0)
            return keywords[i].token;
    return 0;
}

/* ── lookup_or_insert_id: finds existing ID or inserts new one ───────────── */
int lookup_or_insert_id(char *lexeme, int line) {
    for (int i = 0; i < count_ids; i++)
        if (strcmp(table_ids[i].lexeme, lexeme) == 0)
            return i;   /* already exists, return its index */

    /* Not found — insert */
    if (count_ids >= MAX_IDS) {
        fprintf(stderr, "ERROR: identifier table overflow\n");
        exit(1);
    }
    strncpy(table_ids[count_ids].lexeme, lexeme, MAX_LEXEME - 1);
    table_ids[count_ids].line = line;
    return count_ids++;
}

/* ── insert_num: inserts a number into the number table ──────────────────── */
int insert_num(char *lexeme, int token_type, int line) {
    if (count_nums >= MAX_NUMS) {
        fprintf(stderr, "ERROR: number table overflow\n");
        exit(1);
    }
    strncpy(table_nums[count_nums].lexeme, lexeme, MAX_LEXEME - 1);
    table_nums[count_nums].token_type = token_type;
    table_nums[count_nums].line       = line;
    return count_nums++;
}

/* ── insert_string: inserts a string literal into the string table ────────── */
int insert_string(char *lexeme, int line) {
    if (count_strings >= MAX_STRINGS) {
        fprintf(stderr, "ERROR: string table overflow\n");
        exit(1);
    }
    strncpy(table_strings[count_strings].lexeme, lexeme, MAX_LEXEME - 1);
    table_strings[count_strings].line = line;
    return count_strings++;
}

/* ── add_token: appends a token to the output token list ─────────────────── */
void add_token(int token_id, int table_index, int line, char *lexeme) {
    if (count_tokens >= 5000) {
        fprintf(stderr, "ERROR: token list overflow\n");
        exit(1);
    }
    token_list[count_tokens].token_id    = token_id;
    token_list[count_tokens].table_index = table_index;
    token_list[count_tokens].line        = line;
    strncpy(token_list[count_tokens].lexeme, lexeme, MAX_LEXEME - 1);
    count_tokens++;
}

/* ── print_error: prints a formatted error message ───────────────────────── */
void print_error(char *msg, int line, char *lexeme) {
    fprintf(stderr, "[LEXICAL ERROR] Line %d: %s -> '%s'\n", line, msg, lexeme);
    error_count++;
}

/* ── Token ID to name ────────────────────────────────────────────────────── */
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
        case TK_DQUOTE:     return "TK_DQUOTE";
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

/* ── print_token_list: prints the full token sequence ────────────────────── */
void print_token_list(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  TOKEN LIST\n");
    printf("=============================================================\n");
    printf("  %-5s  %-15s  %-8s  %-6s  %s\n",
           "No.", "Token", "ID", "Line", "Lexeme");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_tokens; i++) {
        printf("  %-5d  %-15s  %-8d  %-6d  %s\n",
               i + 1,
               token_name(token_list[i].token_id),
               token_list[i].token_id,
               token_list[i].line,
               token_list[i].lexeme);
    }
    printf("=============================================================\n");
    printf("  Total tokens: %d\n", count_tokens);
    printf("=============================================================\n");
}

/* ── print_table_ids ─────────────────────────────────────────────────────── */
void print_table_ids(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — IDENTIFIERS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-30s  %s\n", "Index", "Lexeme", "First Line");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_ids; i++)
        printf("  %-6d  %-30s  %d\n",
               i, table_ids[i].lexeme, table_ids[i].line);
    printf("=============================================================\n");
    printf("  Total identifiers: %d\n", count_ids);
    printf("=============================================================\n");
}

/* ── print_table_nums ────────────────────────────────────────────────────── */
void print_table_nums(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — NUMBERS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-15s  %-12s  %s\n", "Index", "Lexeme", "Type", "Line");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_nums; i++)
        printf("  %-6d  %-15s  %-12s  %d\n",
               i,
               table_nums[i].lexeme,
               table_nums[i].token_type == TK_INT_NUM ? "INTEGER" : "FLOAT",
               table_nums[i].line);
    printf("=============================================================\n");
    printf("  Total numbers: %d\n", count_nums);
    printf("=============================================================\n");
}

/* ── print_table_strings ─────────────────────────────────────────────────── */
void print_table_strings(void) {
    printf("\n");
    printf("=============================================================\n");
    printf("  SYMBOL TABLE — STRING LITERALS\n");
    printf("=============================================================\n");
    printf("  %-6s  %-40s  %s\n", "Index", "Content", "Line");
    printf("-------------------------------------------------------------\n");
    for (int i = 0; i < count_strings; i++)
        printf("  %-6d  %-40s  %d\n",
               i, table_strings[i].lexeme, table_strings[i].line);
    printf("=============================================================\n");
    printf("  Total strings: %d\n", count_strings);
    printf("=============================================================\n");
}

/* ── main ────────────────────────────────────────────────────────────────── */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <source_file.cm>\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "r");
    if (!fp) {
        fprintf(stderr, "ERROR: Cannot open file '%s'\n", argv[1]);
        return 1;
    }

    printf("=============================================================\n");
    printf("  C-- Lexical Analyzer\n");
    printf("  File: %s\n", argv[1]);
    printf("=============================================================\n");

    /* Point lex to the input file */
    yyin = fp;

    /* Run the scanner */
    yylex();

    fclose(fp);

    /* Print results */
    print_token_list();
    print_table_ids();
    print_table_nums();
    print_table_strings();

    /* Summary */
    printf("\n");
    printf("=============================================================\n");
    printf("  SCAN COMPLETE\n");
    printf("  Tokens found : %d\n", count_tokens);
    printf("  Identifiers  : %d\n", count_ids);
    printf("  Numbers      : %d\n", count_nums);
    printf("  Strings      : %d\n", count_strings);
    printf("  Errors       : %d\n", error_count);
    printf("=============================================================\n");

    return (error_count > 0) ? 1 : 0;
}
