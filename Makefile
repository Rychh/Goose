# Makefile generated by BNFC.

# List of goals not corresponding to file names.

.PHONY : all clean distclean

# Default goal.

all : TestGrammar

# Rules for building the parser.

ErrM.hs LexGrammar.x PrintGrammar.hs ParGrammar.y TestGrammar.hs : Grammar.cf
	bnfc --haskell Grammar.cf

%.hs : %.y
	happy --ghc --coerce --array --info $<

%.hs : %.x
	alex --ghc $<

TestGrammar : TestGrammar.hs ErrM.hs LexGrammar.hs ParGrammar.hs PrintGrammar.hs SkelGrammar.hs
	ghc --make $< -o $@

# Rules for cleaning generated files.

clean :
	-rm -f *.hi *.o *.log *.aux *.dvi

distclean : clean
	-rm -f AbsGrammar.hs AbsGrammar.hs.bak ComposOp.hs ComposOp.hs.bak DocGrammar.txt DocGrammar.txt.bak ErrM.hs ErrM.hs.bak LayoutGrammar.hs LayoutGrammar.hs.bak LexGrammar.x LexGrammar.x.bak ParGrammar.y ParGrammar.y.bak PrintGrammar.hs PrintGrammar.hs.bak SharedString.hs SharedString.hs.bak SkelGrammar.hs SkelGrammar.hs.bak TestGrammar.hs TestGrammar.hs.bak XMLGrammar.hs XMLGrammar.hs.bak ASTGrammar.agda ASTGrammar.agda.bak ParserGrammar.agda ParserGrammar.agda.bak IOLib.agda IOLib.agda.bak Main.agda Main.agda.bak Grammar.dtd Grammar.dtd.bak TestGrammar LexGrammar.hs ParGrammar.hs ParGrammar.info ParDataGrammar.hs Makefile


# EOF
