/*
 *  The scanner definition for COOL.
 */
%option noyywrap
%x COMMENTS INLINE_COMMENT STRING

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

static int comments_layer = 0;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
LE              <=
ASSIGN          <-

NOTION          "+"|"-"|"*"|"/"|"<"|"="|">"|"."|";"|"~"|"{"|"}"|"("|")"|":"|"@"|","

%%

 /*
  *  Nested comments
  */

<INITIAL,COMMENTS>"(*" {
    comments_layer++;
    BEGIN COMMENTS;
}

<COMMENTS>"*)" {
    comments_layer--;
    if (comments_layer == 0) {
        BEGIN INITIAL;
    }
}

<COMMENTS><<EOF>> {
    cool_yylval.error_msg = "EOF in comment";
    BEGIN INITIAL;
    return ERROR;
}

<COMMENTS>. {}

"*)" {
    cool_yylval.error_msg = "Unmatched *)";
    BEGIN INITIAL;
    return ERROR;
}

"--" {
    comments_layer++;
    BEGIN INLINE_COMMENT;
}

<INLINE_COMMENT>\n {
    curr_lineno++;
    BEGIN INITIAL;
}

<INLINE_COMMENT>. {}

 /*
  *  The multiple-character operators.
  */

{DARROW}		{ return (DARROW); }

{LE}            { return LE; }

{ASSIGN}        { return ASSIGN; }

{NOTION}        { return (int)*yytext; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

(?i:class) {
    return CLASS;
}

(?i:else) {
    return ELSE;
}

(?:fi) {
    return FI;
}

(?:if) {
    return IF;
}

(?:in) {
    return IN;
}

(?:inherits) {
    return INHERITS;
}

(?:isvoid) {
    return ISVOID;
}

(?:let) {
    return LET;
}

(?:loop) {
    return LOOP;
}

(?:pool) {
    return POOL;
}

(?:then) {
    return THEN;
}

(?:while) {
    return WHILE;
}

(?:case) {
    return CASE;
}

(?:esac) {
    return ESAC;
}

(?:new) {
    return NEW;
}

(?:of) {
    return OF;
}

(?:not) {
    return NOT;
}

t(?:rue) {
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

f(?:alse) {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

"\"" {
    yymore();
    BEGIN STRING;
}

<STRING>"\\0" {
    yylval.error_msg = "Unterminated string constant";
    BEGIN INITIAL;
    return ERROR;
}

<STRING>\n {
    yylval.error_msg = "Unterminated string constant";
    curr_lineno++;
    BEGIN INITIAL;
    return ERROR;
}

<STRING>"\\"[^\n] {
    yymore();
}


<STRING>"\\\n" {
    curr_lineno++;
    yymore();
}

<STRING>[^\\\"\n] {
    yymore();
}

<STRING><<EOF>> {
    yylval.error_msg = "EOF in string constant";
    BEGIN INITIAL;
    return ERROR;
}

<STRING>"\"" {
    std::string input(yytext, yyleng);
    input = input.substr(1, yyleng - 2);

    std::string output = "";
    std::string::size_type pos;

    while ((pos = input.find_first_of("\\")) != std::string::npos) {
        output += input.substr(0, pos);

        switch (input[pos+1]) {
            case 'b':
                output += "\b";
                break;
            case 't':
                output += "\t";
                break;
            case 'n':
                output += "\n";
                break;
            case 'f':
                output += "\f";
                break;
            default:
                output += input[pos+1];
                break;
        }

        input = input.substr(pos+2, input.length()-2);
    }

    output += input;
    if (output.length() >= MAX_STR_CONST) {
        cool_yylval.error_msg = "String constant too long";
        BEGIN INITIAL;
        return ERROR;
    }

    cool_yylval.symbol = stringtable.add_string((char*)output.c_str());
    BEGIN INITIAL;
    return STR_CONST;
}

[0-9]+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

[A-Z][a-zA-Z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

[a-z][a-zA-Z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

\n {
    curr_lineno++;
}

[ \f\r\t\v]+ {

}

. {
    yylval.error_msg = yytext;
    BEGIN INITIAL;
    return ERROR;
}

%%
