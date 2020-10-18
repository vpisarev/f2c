/****************************************************************
Copyright 1990, 1993 by AT&T Bell Laboratories, Bellcore.

Permission to use, copy, modify, and distribute this software
and its documentation for any purpose and without fee is hereby
granted, provided that the above copyright notice appear in all
copies and that both that the copyright notice and this
permission notice and warranty disclaimer appear in supporting
documentation, and that the names of AT&T Bell Laboratories or
Bellcore or any of their entities not be used in advertising or
publicity pertaining to distribution of the software without
specific, written prior permission.

AT&T and Bellcore disclaim all warranties with regard to this
software, including all implied warranties of merchantability
and fitness.  In no event shall AT&T or Bellcore be liable for
any special, indirect or consequential damages or any damages
whatsoever resulting from loss of use, data or profits, whether
in an action of contract, negligence or other tortious action,
arising out of or in connection with the use or performance of
this software.
****************************************************************/

%{
#include "defs.h"
#include "p1defs.h"

static int nstars;			/* Number of labels in an
					   alternate return CALL */
static int datagripe;
static int ndim;
static int vartype;
int new_dcl;
static ftnint varleng;
static struct Dims dims[MAXDIM+1];
extern struct Labelblock **labarray;	/* Labels in an alternate
						   return CALL */
extern int maxlablist;

/* The next two variables are used to verify that each statement might be reached
   during runtime.   lastwasbranch   is tested only in the defintion of the
   stat:   nonterminal. */

int lastwasbranch = NO;
static int thiswasbranch = NO;
extern ftnint yystno;
extern flag intonly;
static chainp datastack;
extern long laststfcn, thisstno;
extern int can_include;	/* for netlib */
extern void endcheck Argdcl((void));
extern struct Primblock *primchk Argdcl((expptr));

#define ESNULL (Extsym *)0
#define NPNULL (Namep)0
#define LBNULL (struct Listblock *)0

 static void
pop_datastack(Void) {
	chainp d0 = datastack;
	if (d0->datap)
		curdtp = (chainp)d0->datap;
	datastack = d0->nextp;
	d0->nextp = 0;
	frchain(&d0);
	}

%}

%token SEOS 1
%token SCOMMENT 2
%token SLABEL 3
%token SUNKNOWN 4
%token SHOLLERITH 5
%token SICON 6
%token SRCON 7
%token SDCON 8
%token SBITCON 9
%token SOCTCON 10
%token SHEXCON 11
%token STRUE 12
%token SFALSE 13
%token SNAME 14
%token SNAMEEQ 15
%token SFIELD 16
%token SSCALE 17
%token SINCLUDE 18
%token SLET 19
%token SASSIGN 20
%token SAUTOMATIC 21
%token SBACKSPACE 22
%token SBLOCK 23
%token SCALL 24
%token SCHARACTER 25
%token SCLOSE 26
%token SCOMMON 27
%token SCOMPLEX 28
%token SCONTINUE 29
%token SDATA 30
%token SDCOMPLEX 31
%token SDIMENSION 32
%token SDO 33
%token SDOUBLE 34
%token SELSE 35
%token SELSEIF 36
%token SEND 37
%token SENDFILE 38
%token SENDIF 39
%token SENTRY 40
%token SEQUIV 41
%token SEXTERNAL 42
%token SFORMAT 43
%token SFUNCTION 44
%token SGOTO 45
%token SASGOTO 46
%token SCOMPGOTO 47
%token SARITHIF 48
%token SLOGIF 49
%token SIMPLICIT 50
%token SINQUIRE 51
%token SINTEGER 52
%token SINTRINSIC 53
%token SLOGICAL 54
%token SNAMELIST 55
%token SOPEN 56
%token SPARAM 57
%token SPAUSE 58
%token SPRINT 59
%token SPROGRAM 60
%token SPUNCH 61
%token SREAD 62
%token SREAL 63
%token SRETURN 64
%token SREWIND 65
%token SSAVE 66
%token SSTATIC 67
%token SSTOP 68
%token SSUBROUTINE 69
%token STHEN 70
%token STO 71
%token SUNDEFINED 72
%token SWRITE 73
%token SLPAR 74
%token SRPAR 75
%token SEQUALS 76
%token SCOLON 77
%token SCOMMA 78
%token SCURRENCY 79
%token SPLUS 80
%token SMINUS 81
%token SSTAR 82
%token SSLASH 83
%token SPOWER 84
%token SCONCAT 85
%token SAND 86
%token SOR 87
%token SNEQV 88
%token SEQV 89
%token SNOT 90
%token SEQ 91
%token SLT 92
%token SGT 93
%token SLE 94
%token SGE 95
%token SNE 96
%token SENDDO 97
%token SWHILE 98
%token SSLASHD 99
%token SBYTE 100
%token SRECURSIVE 101
%token SEXIT 102

/* Specify precedences and associativities. */

%union	{
	int ival;
	ftnint lval;
	char *charpval;
	chainp chval;
	tagptr tagval;
	expptr expval;
	struct Labelblock *labval;
	struct Nameblock *namval;
	struct Eqvchain *eqvval;
	Extsym *extval;
	}

%left SCOMMA
%nonassoc SCOLON
%right SEQUALS
%left SEQV SNEQV
%left SOR
%left SAND
%left SNOT
%nonassoc SLT SGT SLE SGE SEQ SNE
%left SCONCAT
%left SPLUS SMINUS
%left SSTAR SSLASH
%right SPOWER

%start program
%type <labval> thislabel label assignlabel
%type <tagval> other inelt
%type <ival> type typespec typename dcl letter addop relop stop nameeq
%type <lval> lengspec
%type <charpval> filename
%type <chval> datavar datavarlist namelistlist funarglist funargs
%type <chval> dospec dospecw
%type <chval> callarglist arglist args exprlist inlist outlist out2 substring
%type <namval> name arg call var
%type <expval> lhs expr uexpr opt_expr fexpr unpar_fexpr
%type <expval> ubound simple value callarg complex_const simple_const bit_const
%type <extval> common comblock entryname progname
%type <eqvval> equivlist

%%

program:
	| program stat SEOS
	;

stat:	  thislabel  entry
		{
/* stat:   is the nonterminal for Fortran statements */

		  lastwasbranch = NO; }
	| thislabel  spec
	| thislabel  exec
		{ /* forbid further statement function definitions... */
		  if (parstate == INDATA && laststfcn != thisstno)
			parstate = INEXEC;
		  thisstno++;
		  if($1 && ($1->labelno==dorange))
			enddo($1->labelno);
		  if(lastwasbranch && thislabel==NULL)
			warn("statement cannot be reached");
		  lastwasbranch = thiswasbranch;
		  thiswasbranch = NO;
		  if($1)
			{
			if($1->labtype == LABFORMAT)
				err("label already that of a format");
			else
				$1->labtype = LABEXEC;
			}
		  freetemps();
		}
	| thislabel SINCLUDE filename
		{ if (can_include)
			doinclude( $3 );
		  else {
			fprintf(diagfile, "Cannot open file %s\n", $3);
			done(1);
			}
		}
	| thislabel  SEND  end_spec
		{ if ($1)
			lastwasbranch = NO;
		  endcheck();
		  endproc(); /* lastwasbranch = NO; -- set in endproc() */
		}
	| thislabel SUNKNOWN
		{ unclassifiable();

/* flline flushes the current line, ignoring the rest of the text there */

		  flline(); }
	| error
		{ flline();  needkwd = NO;  inioctl = NO;
		  yyerrok; yyclearin; }
	;

thislabel:  SLABEL
		{
		if(yystno != 0)
			{
			$$ = thislabel =  mklabel(yystno);
			if( ! headerdone ) {
				if (procclass == CLUNKNOWN)
					procclass = CLMAIN;
				puthead(CNULL, procclass);
				}
			if(thislabel->labdefined)
				execerr("label %s already defined",
					convic(thislabel->stateno) );
			else	{
				if(thislabel->blklevel!=0 && thislabel->blklevel<blklevel
				    && thislabel->labtype!=LABFORMAT)
					warn1("there is a branch to label %s from outside block",
					      convic( (ftnint) (thislabel->stateno) ) );
				thislabel->blklevel = blklevel;
				thislabel->labdefined = YES;
				if(thislabel->labtype != LABFORMAT)
					p1_label((long)(thislabel - labeltab));
				}
			}
		else    $$ = thislabel = NULL;
		}
	;

entry:	  SPROGRAM new_proc progname
		   {startproc($3, CLMAIN); }
	| SPROGRAM new_proc progname progarglist
		   {	warn("ignoring arguments to main program");
			/* hashclear(); */
			startproc($3, CLMAIN); }
	| SBLOCK new_proc progname
		{ if($3) NO66("named BLOCKDATA");
		  startproc($3, CLBLOCK); }
	| SSUBROUTINE new_proc entryname arglist
		{ entrypt(CLPROC, TYSUBR, (ftnint) 0,  $3, $4); }
	| SRECURSIVE SSUBROUTINE new_proc entryname arglist
		{ entrypt(CLPROC, TYSUBR, (ftnint) 0,  $4, $5); }
	| SFUNCTION new_proc entryname arglist
		{ entrypt(CLPROC, TYUNKNOWN, (ftnint) 0, $3, $4); }
	| SRECURSIVE SFUNCTION new_proc entryname arglist
		{ entrypt(CLPROC, TYUNKNOWN, (ftnint) 0, $4, $5); }
	| type SFUNCTION new_proc entryname arglist
		{ entrypt(CLPROC, $1, varleng, $4, $5); }
	| SENTRY entryname arglist
		 { if(parstate==OUTSIDE || procclass==CLMAIN
			|| procclass==CLBLOCK)
				execerr("misplaced entry statement", CNULL);
		  entrypt(CLENTRY, 0, (ftnint) 0, $2, $3);
		}
	;

new_proc:
		{ newproc(); }
	;

entryname:  name
		{ $$ = newentry($1, 1); }
	;

name:	  SNAME
		{ $$ = mkname(token); }
	;

progname:		{ $$ = NULL; }
	| entryname
	;

progarglist:
	  SLPAR SRPAR
	| SLPAR progargs SRPAR
	;

progargs: progarg
	| progargs SCOMMA progarg
	;

progarg:  SNAME
	| SNAME SEQUALS SNAME
	;

arglist:
		{ $$ = 0; }
	| SLPAR SRPAR
		{ NO66(" () argument list");
		  $$ = 0; }
	| SLPAR args SRPAR
		{$$ = $2; }
	;

args:	  arg
		{ $$ = ($1 ? mkchain((char *)$1,CHNULL) : CHNULL ); }
	| args SCOMMA arg
		{ if($3) $1 = $$ = mkchain((char *)$3, $1); }
	;

arg:	  name
		{ if($1->vstg!=STGUNKNOWN && $1->vstg!=STGARG)
			dclerr("name declared as argument after use", $1);
		  $1->vstg = STGARG;
		}
	| SSTAR
		{ NO66("altenate return argument");

/* substars   means that '*'ed formal parameters should be replaced.
   This is used to specify alternate return labels; in theory, only
   parameter slots which have '*' should accept the statement labels.
   This compiler chooses to ignore the '*'s in the formal declaration, and
   always return the proper value anyway.

   This variable is only referred to in   proc.c   */

		  $$ = 0;  substars = YES; }
	;



filename:   SHOLLERITH
		{
		char *s;
		s = copyn(toklen+1, token);
		s[toklen] = '\0';
		$$ = s;
		}
	;
spec:	  dcl
	| common
	| external
	| intrinsic
	| equivalence
	| data
	| implicit
	| namelist
	| SSAVE
		{ NO66("SAVE statement");
		  saveall = YES; }
	| SSAVE savelist
		{ NO66("SAVE statement"); }
	| SFORMAT
		{ fmtstmt(thislabel); setfmt(thislabel); }
	| SPARAM in_dcl SLPAR paramlist SRPAR
		{ NO66("PARAMETER statement"); }
	;

dcl:	  type opt_comma name in_dcl new_dcl dims lengspec
		{ settype($3, $1, $7);
		  if(ndim>0) setbound($3,ndim,dims);
		}
	| dcl SCOMMA name dims lengspec
		{ settype($3, $1, $5);
		  if(ndim>0) setbound($3,ndim,dims);
		}
	| dcl SSLASHD datainit vallist SSLASHD
		{ if (new_dcl == 2) {
			err("attempt to give DATA in type-declaration");
			new_dcl = 1;
			}
		}
	;

new_dcl:	{ new_dcl = 2; } ;

type:	  typespec lengspec
		{ varleng = $2; }
	;

typespec:  typename
		{ varleng = ($1<0 || ONEOF($1,M(TYLOGICAL)|M(TYLONG))
				? 0 : typesize[$1]);
		  vartype = $1; }
	;

typename:    SINTEGER	{ $$ = TYLONG; }
	| SREAL		{ $$ = tyreal; }
	| SCOMPLEX	{ ++complex_seen; $$ = tycomplex; }
	| SDOUBLE	{ $$ = TYDREAL; }
	| SDCOMPLEX	{ ++dcomplex_seen; NOEXT("DOUBLE COMPLEX statement"); $$ = TYDCOMPLEX; }
	| SLOGICAL	{ $$ = TYLOGICAL; }
	| SCHARACTER	{ NO66("CHARACTER statement"); $$ = TYCHAR; }
	| SUNDEFINED	{ $$ = TYUNKNOWN; }
	| SDIMENSION	{ $$ = TYUNKNOWN; }
	| SAUTOMATIC	{ NOEXT("AUTOMATIC statement"); $$ = - STGAUTO; }
	| SSTATIC	{ NOEXT("STATIC statement"); $$ = - STGBSS; }
	| SBYTE		{ $$ = TYINT1; }
	;

lengspec:
		{ $$ = varleng; }
	| SSTAR intonlyon expr intonlyoff
		{
		expptr p;
		p = $3;
		NO66("length specification *n");
		if( ! ISICON(p) || p->constblock.Const.ci <= 0 )
			{
			$$ = 0;
			dclerr("length must be a positive integer constant",
				NPNULL);
			}
		else {
			if (vartype == TYCHAR)
				$$ = p->constblock.Const.ci;
			else switch((int)p->constblock.Const.ci) {
				case 1:	$$ = 1; break;
				case 2: $$ = typesize[TYSHORT];	break;
				case 4: $$ = typesize[TYLONG];	break;
				case 8: $$ = typesize[TYDREAL];	break;
				case 16: $$ = typesize[TYDCOMPLEX]; break;
				default:
					dclerr("invalid length",NPNULL);
					$$ = varleng;
				}
			}
		}
	| SSTAR intonlyon SLPAR SSTAR SRPAR intonlyoff
		{ NO66("length specification *(*)"); $$ = -1; }
	;

common:	  SCOMMON in_dcl var
		{ incomm( $$ = comblock("") , $3 ); }
	| SCOMMON in_dcl comblock var
		{ $$ = $3;  incomm($3, $4); }
	| common opt_comma comblock opt_comma var
		{ $$ = $3;  incomm($3, $5); }
	| common SCOMMA var
		{ incomm($1, $3); }
	;

comblock:  SCONCAT
		{ $$ = comblock(""); }
	| SSLASH SNAME SSLASH
		{ $$ = comblock(token); }
	;

external: SEXTERNAL in_dcl name
		{ setext($3); }
	| external SCOMMA name
		{ setext($3); }
	;

intrinsic:  SINTRINSIC in_dcl name
		{ NO66("INTRINSIC statement"); setintr($3); }
	| intrinsic SCOMMA name
		{ setintr($3); }
	;

equivalence:  SEQUIV in_dcl equivset
	| equivalence SCOMMA equivset
	;

equivset:  SLPAR equivlist SRPAR
		{
		struct Equivblock *p;
		if(nequiv >= maxequiv)
			many("equivalences", 'q', maxequiv);
		p  =  & eqvclass[nequiv++];
		p->eqvinit = NO;
		p->eqvbottom = 0;
		p->eqvtop = 0;
		p->equivs = $2;
		}
	;

equivlist:  lhs
		{ $$=ALLOC(Eqvchain);
		  $$->eqvitem.eqvlhs = primchk($1);
		}
	| equivlist SCOMMA lhs
		{ $$=ALLOC(Eqvchain);
		  $$->eqvitem.eqvlhs = primchk($3);
		  $$->eqvnextp = $1;
		}
	;

data:	  SDATA in_data datalist
	| data opt_comma datalist
	;

in_data:
		{ if(parstate == OUTSIDE)
			{
			newproc();
			startproc(ESNULL, CLMAIN);
			}
		  if(parstate < INDATA)
			{
			enddcl();
			parstate = INDATA;
			datagripe = 1;
			}
		}
	;

datalist:  datainit datavarlist SSLASH datapop vallist SSLASH
		{ ftnint junk;
		  if(nextdata(&junk) != NULL)
			err("too few initializers");
		  frdata($2);
		  frrpl();
		}
	;

datainit: /* nothing */ { frchain(&datastack); curdtp = 0; } ;

datapop: /* nothing */ { pop_datastack(); } ;

vallist:  { toomanyinit = NO; }  val
	| vallist SCOMMA val
	;

val:	  value
		{ dataval(ENULL, $1); }
	| simple SSTAR value
		{ dataval($1, $3); }
	;

value:	  simple
	| addop simple
		{ if( $1==OPMINUS && ISCONST($2) )
			consnegop((Constp)$2);
		  $$ = $2;
		}
	| complex_const
	;

savelist: saveitem
	| savelist SCOMMA saveitem
	;

saveitem: name
		{ int k;
		  $1->vsave = YES;
		  k = $1->vstg;
		if( ! ONEOF(k, M(STGUNKNOWN)|M(STGBSS)|M(STGINIT)) )
			dclerr("can only save static variables", $1);
		}
	| comblock
	;

paramlist:  paramitem
	| paramlist SCOMMA paramitem
	;

paramitem:  name SEQUALS expr
		{ if($1->vclass == CLUNKNOWN)
			make_param((struct Paramblock *)$1, $3);
		  else dclerr("cannot make into parameter", $1);
		}
	;

var:	  name dims
		{ if(ndim>0) setbound($1, ndim, dims); }
	;

datavar:	  lhs
		{ Namep np;
		  struct Primblock *pp = (struct Primblock *)$1;
		  int tt = $1->tag;
		  if (tt != TPRIM) {
			if (tt == TCONST)
				err("parameter in data statement");
			else
				erri("tag %d in data statement",tt);
			$$ = 0;
			err_lineno = lineno;
			break;
			}
		  np = pp -> namep;
		  vardcl(np);
		  if ((pp->fcharp || pp->lcharp)
		   && (np->vtype != TYCHAR || np->vdim && !pp->argsp))
			sserr(np);
		  if(np->vstg == STGCOMMON)
			extsymtab[np->vardesc.varno].extinit = YES;
		  else if(np->vstg==STGEQUIV)
			eqvclass[np->vardesc.varno].eqvinit = YES;
		  else if(np->vstg!=STGINIT && np->vstg!=STGBSS) {
			errstr(np->vstg == STGARG
				? "Dummy argument \"%.60s\" in data statement."
				: "Cannot give data to \"%.75s\"",
				np->fvarname);
			$$ = 0;
			err_lineno = lineno;
			break;
			}
		  $$ = mkchain((char *)$1, CHNULL);
		}
	| SLPAR datavarlist SCOMMA dospec SRPAR
		{ chainp p; struct Impldoblock *q;
		pop_datastack();
		q = ALLOC(Impldoblock);
		q->tag = TIMPLDO;
		(q->varnp = (Namep) ($4->datap))->vimpldovar = 1;
		p = $4->nextp;
		if(p)  { q->implb = (expptr)(p->datap); p = p->nextp; }
		if(p)  { q->impub = (expptr)(p->datap); p = p->nextp; }
		if(p)  { q->impstep = (expptr)(p->datap); }
		frchain( & ($4) );
		$$ = mkchain((char *)q, CHNULL);
		q->datalist = hookup($2, $$);
		}
	;

datavarlist: datavar
		{ if (!datastack)
			curdtp = 0;
		  datastack = mkchain((char *)curdtp, datastack);
		  curdtp = $1; curdtelt = 0;
		  }
	| datavarlist SCOMMA datavar
		{ $$ = hookup($1, $3); }
	;

dims:
		{ ndim = 0; }
	| SLPAR dimlist SRPAR
	;

dimlist:   { ndim = 0; }   dim
	| dimlist SCOMMA dim
	;

dim:	  ubound
		{
		  if(ndim == maxdim)
			err("too many dimensions");
		  else if(ndim < maxdim)
			{ dims[ndim].lb = 0;
			  dims[ndim].ub = $1;
			}
		  ++ndim;
		}
	| expr SCOLON ubound
		{
		  if(ndim == maxdim)
			err("too many dimensions");
		  else if(ndim < maxdim)
			{ dims[ndim].lb = $1;
			  dims[ndim].ub = $3;
			}
		  ++ndim;
		}
	;

ubound:	  SSTAR
		{ $$ = 0; }
	| expr
	;

labellist: label
		{ nstars = 1; labarray[0] = $1; }
	| labellist SCOMMA label
		{ if(nstars < maxlablist)  labarray[nstars++] = $3; }
	;

label:	  SICON
		{ $$ = execlab( convci(toklen, token) ); }
	;

implicit:  SIMPLICIT in_dcl implist
		{ NO66("IMPLICIT statement"); }
	| implicit SCOMMA implist
	;

implist:  imptype SLPAR letgroups SRPAR
	| imptype
		{ if (vartype != TYUNKNOWN)
			dclerr("-- expected letter range",NPNULL);
		  setimpl(vartype, varleng, 'a', 'z'); }
	;

imptype:   { needkwd = 1; } type
		/* { vartype = $2; } */
	;

letgroups: letgroup
	| letgroups SCOMMA letgroup
	;

letgroup:  letter
		{ setimpl(vartype, varleng, $1, $1); }
	| letter SMINUS letter
		{ setimpl(vartype, varleng, $1, $3); }
	;

letter:  SNAME
		{ if(toklen!=1 || token[0]<'a' || token[0]>'z')
			{
			dclerr("implicit item must be single letter", NPNULL);
			$$ = 0;
			}
		  else $$ = token[0];
		}
	;

namelist:	SNAMELIST
	| namelist namelistentry
	;

namelistentry:  SSLASH name SSLASH namelistlist
		{
		if($2->vclass == CLUNKNOWN)
			{
			$2->vclass = CLNAMELIST;
			$2->vtype = TYINT;
			$2->vstg = STGBSS;
			$2->varxptr.namelist = $4;
			$2->vardesc.varno = ++lastvarno;
			}
		else dclerr("cannot be a namelist name", $2);
		}
	;

namelistlist:  name
		{ $$ = mkchain((char *)$1, CHNULL); }
	| namelistlist SCOMMA name
		{ $$ = hookup($1, mkchain((char *)$3, CHNULL)); }
	;

in_dcl:
		{ switch(parstate)
			{
			case OUTSIDE:	newproc();
					startproc(ESNULL, CLMAIN);
			case INSIDE:	parstate = INDCL;
			case INDCL:	break;

			case INDATA:
				if (datagripe) {
					errstr(
				"Statement order error: declaration after DATA",
						CNULL);
					datagripe = 0;
					}
				break;

			default:
				dclerr("declaration among executables", NPNULL);
			}
		}
	;
funarglist:
		{ $$ = 0; }
	| funargs
		{ $$ = revchain($1); }
	;

funargs:  expr
		{ $$ = mkchain((char *)$1, CHNULL); }
	| funargs SCOMMA expr
		{ $$ = mkchain((char *)$3, $1); }
	;


expr:	  uexpr
	| SLPAR expr SRPAR	{ $$ = $2; if ($$->tag == TPRIM)
					paren_used(&$$->primblock); }
	| complex_const
	;

uexpr:	  lhs
	| simple_const
	| expr addop expr   %prec SPLUS
		{ $$ = mkexpr($2, $1, $3); }
	| expr SSTAR expr
		{ $$ = mkexpr(OPSTAR, $1, $3); }
	| expr SSLASH expr
		{ $$ = mkexpr(OPSLASH, $1, $3); }
	| expr SPOWER expr
		{ $$ = mkexpr(OPPOWER, $1, $3); }
	| addop expr  %prec SSTAR
		{ if($1 == OPMINUS)
			$$ = mkexpr(OPNEG, $2, ENULL);
		  else {
			$$ = $2;
			if ($$->tag == TPRIM)
				paren_used(&$$->primblock);
			}
		}
	| expr relop expr  %prec SEQ
		{ $$ = mkexpr($2, $1, $3); }
	| expr SEQV expr
		{ NO66(".EQV. operator");
		  $$ = mkexpr(OPEQV, $1,$3); }
	| expr SNEQV expr
		{ NO66(".NEQV. operator");
		  $$ = mkexpr(OPNEQV, $1, $3); }
	| expr SOR expr
		{ $$ = mkexpr(OPOR, $1, $3); }
	| expr SAND expr
		{ $$ = mkexpr(OPAND, $1, $3); }
	| SNOT expr
		{ $$ = mkexpr(OPNOT, $2, ENULL); }
	| expr SCONCAT expr
		{ NO66("concatenation operator //");
		  $$ = mkexpr(OPCONCAT, $1, $3); }
	;

addop:	  SPLUS		{ $$ = OPPLUS; }
	| SMINUS	{ $$ = OPMINUS; }
	;

relop:	  SEQ	{ $$ = OPEQ; }
	| SGT	{ $$ = OPGT; }
	| SLT	{ $$ = OPLT; }
	| SGE	{ $$ = OPGE; }
	| SLE	{ $$ = OPLE; }
	| SNE	{ $$ = OPNE; }
	;

lhs:	 name
		{ $$ = mkprim($1, LBNULL, CHNULL); }
	| name substring
		{ NO66("substring operator :");
		  $$ = mkprim($1, LBNULL, $2); }
	| name SLPAR funarglist SRPAR
		{ $$ = mkprim($1, mklist($3), CHNULL); }
	| name SLPAR funarglist SRPAR substring
		{ NO66("substring operator :");
		  $$ = mkprim($1, mklist($3), $5); }
	;

substring:  SLPAR opt_expr SCOLON opt_expr SRPAR
		{ $$ = mkchain((char *)$2, mkchain((char *)$4,CHNULL)); }
	;

opt_expr:
		{ $$ = 0; }
	| expr
	;

simple:	  name
		{ if($1->vclass == CLPARAM)
			$$ = (expptr) cpexpr(
				( (struct Paramblock *) ($1) ) -> paramval);
		}
	| simple_const
	;

simple_const:   STRUE	{ $$ = mklogcon(1); }
	| SFALSE	{ $$ = mklogcon(0); }
	| SHOLLERITH  { $$ = mkstrcon(toklen, token); }
	| SICON	{ $$ = mkintqcon(toklen, token); }
	| SRCON	{ $$ = mkrealcon(tyreal, token); }
	| SDCON	{ $$ = mkrealcon(TYDREAL, token); }
	| bit_const
	;

complex_const:  SLPAR uexpr SCOMMA uexpr SRPAR
		{ $$ = mkcxcon($2,$4); }
	;

bit_const:  SHEXCON
		{ NOEXT("hex constant");
		  $$ = mkbitcon(4, toklen, token); }
	| SOCTCON
		{ NOEXT("octal constant");
		  $$ = mkbitcon(3, toklen, token); }
	| SBITCON
		{ NOEXT("binary constant");
		  $$ = mkbitcon(1, toklen, token); }
	;

fexpr:	  unpar_fexpr
	| SLPAR fexpr SRPAR
		{ $$ = $2; }
	;

unpar_fexpr:	  lhs
	| simple_const
	| fexpr addop fexpr   %prec SPLUS
		{ $$ = mkexpr($2, $1, $3); }
	| fexpr SSTAR fexpr
		{ $$ = mkexpr(OPSTAR, $1, $3); }
	| fexpr SSLASH fexpr
		{ $$ = mkexpr(OPSLASH, $1, $3); }
	| fexpr SPOWER fexpr
		{ $$ = mkexpr(OPPOWER, $1, $3); }
	| addop fexpr  %prec SSTAR
		{ if($1 == OPMINUS)
			$$ = mkexpr(OPNEG, $2, ENULL);
		  else $$ = $2;
		}
	| fexpr SCONCAT fexpr
		{ NO66("concatenation operator //");
		  $$ = mkexpr(OPCONCAT, $1, $3); }
	;
exec:	  iffable
	| SDO end_spec label opt_comma dospecw
		{
		if($3->labdefined)
			execerr("no backward DO loops", CNULL);
		$3->blklevel = blklevel+1;
		exdo($3->labelno, NPNULL, $5);
		}
	| SDO end_spec opt_comma dospecw
		{
		exdo((int)(ctls - ctlstack - 2), NPNULL, $4);
		NOEXT("DO without label");
		}
	| SENDDO
		{ exenddo(NPNULL); }
	| logif iffable
		{ exendif();  thiswasbranch = NO; }
	| logif STHEN
	| SELSEIF end_spec SLPAR {westart(1);} expr SRPAR STHEN
		{ exelif($5); lastwasbranch = NO; }
	| SELSE end_spec
		{ exelse(); lastwasbranch = NO; }
	| SENDIF end_spec
		{ exendif(); lastwasbranch = NO; }
	;

logif:	  SLOGIF end_spec SLPAR expr SRPAR
		{ exif($4); }
	;

dospec:	  name SEQUALS exprlist
		{ $$ = mkchain((char *)$1, $3); }
	;

dospecw:  dospec
	| SWHILE {westart(0);} SLPAR expr SRPAR
		{ $$ = mkchain(CNULL, (chainp)$4); }
	;

iffable:  let lhs SEQUALS expr
		{ exequals((struct Primblock *)$2, $4); }
	| SASSIGN end_spec assignlabel STO name
		{ exassign($5, $3); }
    | SEXIT
        { exgoto(execlab(0)); thiswasbranch = YES; }
	| SCONTINUE end_spec
	| goto
	| io
		{ inioctl = NO; }
	| SARITHIF end_spec SLPAR expr SRPAR label SCOMMA label SCOMMA label
		{ exarif($4, $6, $8, $10);  thiswasbranch = YES; }
	| call
		{ excall($1, LBNULL, 0, labarray); }
	| call SLPAR SRPAR
		{ excall($1, LBNULL, 0, labarray); }
	| call SLPAR callarglist SRPAR
		{ if(nstars < maxlablist)
			excall($1, mklist(revchain($3)), nstars, labarray);
		  else
			many("alternate returns", 'l', maxlablist);
		}
	| SRETURN end_spec opt_expr
		{ exreturn($3);  thiswasbranch = YES; }
	| stop end_spec opt_expr
		{ exstop($1, $3);  thiswasbranch = $1; }
	;

assignlabel:   SICON
		{ $$ = mklabel( convci(toklen, token) ); }
	;

let:	  SLET
		{ if(parstate == OUTSIDE)
			{
			newproc();
			startproc(ESNULL, CLMAIN);
			}
		}
	;

goto:	  SGOTO end_spec label
		{ exgoto($3);  thiswasbranch = YES; }
	| SASGOTO end_spec name
		{ exasgoto($3);  thiswasbranch = YES; }
	| SASGOTO end_spec name opt_comma SLPAR labellist SRPAR
		{ exasgoto($3);  thiswasbranch = YES; }
	| SCOMPGOTO end_spec SLPAR labellist SRPAR opt_comma expr
		{ if(nstars < maxlablist)
			putcmgo(putx(fixtype($7)), nstars, labarray);
		  else
			many("labels in computed GOTO list", 'l', maxlablist);
		}
	;

opt_comma:
	| SCOMMA
	;

call:	  SCALL end_spec name
		{ nstars = 0; $$ = $3; }
	;

callarglist:  callarg
		{ $$ = $1 ? mkchain((char *)$1,CHNULL) : CHNULL; }
	| callarglist SCOMMA callarg
		{ $$ = $3 ? mkchain((char *)$3, $1) : $1; }
	;

callarg:  expr
	| SSTAR label
		{ if(nstars < maxlablist) labarray[nstars++] = $2; $$ = 0; }
	;

stop:	  SPAUSE
		{ $$ = 0; }
	| SSTOP
		{ $$ = 2; }
	;

exprlist:  expr
		{ $$ = mkchain((char *)$1, CHNULL); }
	| exprlist SCOMMA expr
		{ $$ = hookup($1, mkchain((char *)$3,CHNULL) ); }
	;

end_spec:
		{ if(parstate == OUTSIDE)
			{
			newproc();
			startproc(ESNULL, CLMAIN);
			}

/* This next statement depends on the ordering of the state table encoding */

		  if(parstate < INDATA) enddcl();
		}
	;

intonlyon:
		{ intonly = YES; }
	;

intonlyoff:
		{ intonly = NO; }
	;
  /*  Input/Output Statements */

io:	  io1
		{ endio(); }
	;

io1:	  iofmove ioctl
	| iofmove unpar_fexpr
		{ ioclause(IOSUNIT, $2); endioctl(); }
	| iofmove SSTAR
		{ ioclause(IOSUNIT, ENULL); endioctl(); }
	| iofmove SPOWER
		{ ioclause(IOSUNIT, IOSTDERR); endioctl(); }
	| iofctl ioctl
	| read ioctl
		{ doio(CHNULL); }
	| read infmt
		{ doio(CHNULL); }
	| read ioctl inlist
		{ doio(revchain($3)); }
	| read infmt SCOMMA inlist
		{ doio(revchain($4)); }
	| read ioctl SCOMMA inlist
		{ doio(revchain($4)); }
	| write ioctl
		{ doio(CHNULL); }
	| write ioctl outlist
		{ doio(revchain($3)); }
	| write ioctl SCOMMA outlist
		{ doio(revchain($4)); }
	| print
		{ doio(CHNULL); }
	| print SCOMMA outlist
		{ doio(revchain($3)); }
	;

iofmove:   fmkwd end_spec in_ioctl
	;

fmkwd:	  SBACKSPACE
		{ iostmt = IOBACKSPACE; }
	| SREWIND
		{ iostmt = IOREWIND; }
	| SENDFILE
		{ iostmt = IOENDFILE; }
	;

iofctl:  ctlkwd end_spec in_ioctl
	;

ctlkwd:	  SINQUIRE
		{ iostmt = IOINQUIRE; }
	| SOPEN
		{ iostmt = IOOPEN; }
	| SCLOSE
		{ iostmt = IOCLOSE; }
	;

infmt:	  unpar_fexpr
		{
		ioclause(IOSUNIT, ENULL);
		ioclause(IOSFMT, $1);
		endioctl();
		}
	| SSTAR
		{
		ioclause(IOSUNIT, ENULL);
		ioclause(IOSFMT, ENULL);
		endioctl();
		}
	;

ioctl:	  SLPAR fexpr SRPAR
		{
		  ioclause(IOSUNIT, $2);
		  endioctl();
		}
	| SLPAR ctllist SRPAR
		{ endioctl(); }
	;

ctllist:  ioclause
	| ctllist SCOMMA ioclause
	;

ioclause:  fexpr
		{ ioclause(IOSPOSITIONAL, $1); }
	| SSTAR
		{ ioclause(IOSPOSITIONAL, ENULL); }
	| SPOWER
		{ ioclause(IOSPOSITIONAL, IOSTDERR); }
	| nameeq expr
		{ ioclause($1, $2); }
	| nameeq SSTAR
		{ ioclause($1, ENULL); }
	| nameeq SPOWER
		{ ioclause($1, IOSTDERR); }
	;

nameeq:  SNAMEEQ
		{ $$ = iocname(); }
	;

read:	  SREAD end_spec in_ioctl
		{ iostmt = IOREAD; }
	;

write:	  SWRITE end_spec in_ioctl
		{ iostmt = IOWRITE; }
	;

print:	  SPRINT end_spec fexpr in_ioctl
		{
		iostmt = IOWRITE;
		ioclause(IOSUNIT, ENULL);
		ioclause(IOSFMT, $3);
		endioctl();
		}
	| SPRINT end_spec SSTAR in_ioctl
		{
		iostmt = IOWRITE;
		ioclause(IOSUNIT, ENULL);
		ioclause(IOSFMT, ENULL);
		endioctl();
		}
	;

inlist:	  inelt
		{ $$ = mkchain((char *)$1, CHNULL); }
	| inlist SCOMMA inelt
		{ $$ = mkchain((char *)$3, $1); }
	;

inelt:	  lhs
		{ $$ = (tagptr) $1; }
	| SLPAR inlist SCOMMA dospec SRPAR
		{ $$ = (tagptr) mkiodo($4,revchain($2)); }
	;

outlist:  uexpr
		{ $$ = mkchain((char *)$1, CHNULL); }
	| other
		{ $$ = mkchain((char *)$1, CHNULL); }
	| out2
	;

out2:	  uexpr SCOMMA uexpr
		{ $$ = mkchain((char *)$3, mkchain((char *)$1, CHNULL) ); }
	| uexpr SCOMMA other
		{ $$ = mkchain((char *)$3, mkchain((char *)$1, CHNULL) ); }
	| other SCOMMA uexpr
		{ $$ = mkchain((char *)$3, mkchain((char *)$1, CHNULL) ); }
	| other SCOMMA other
		{ $$ = mkchain((char *)$3, mkchain((char *)$1, CHNULL) ); }
	| out2  SCOMMA uexpr
		{ $$ = mkchain((char *)$3, $1); }
	| out2  SCOMMA other
		{ $$ = mkchain((char *)$3, $1); }
	;

other:	  complex_const
		{ $$ = (tagptr) $1; }
	| SLPAR expr SRPAR
		{ $$ = (tagptr) $2; }
	| SLPAR uexpr SCOMMA dospec SRPAR
		{ $$ = (tagptr) mkiodo($4, mkchain((char *)$2, CHNULL) ); }
	| SLPAR other SCOMMA dospec SRPAR
		{ $$ = (tagptr) mkiodo($4, mkchain((char *)$2, CHNULL) ); }
	| SLPAR out2  SCOMMA dospec SRPAR
		{ $$ = (tagptr) mkiodo($4, revchain($2)); }
	;

in_ioctl:
		{ startioctl(); }
	;
