MODULE WebCSS2P;		(* Outlines.Expand * Outlines.Collapse *)

IMPORT Scanner := WebCSS2Scanner, CSS2 := WebCSS2, Strings, Files, Pieces := WebPieces, Out ;

CONST
	debug = FALSE;

(*
CONST
	lengthYes = TRUE; percentYes = TRUE ; autoYes = TRUE; inheritYes = TRUE; noneYes = TRUE; normalYes = TRUE;
	lengthNo = FALSE; percentNo = FALSE ; autoNo = FALSE; inheritNo = FALSE; noneNo = FALSE; normalNo = FALSE;
*)

CONST
	maxASpecifity = 1 ; maxBSpecifity = 7 ; maxCSpecifity = 7;
	ASpecifityMult = 64 ; BSpecifityMult = 8;
	
VAR
	sym : INTEGER;
	valid : BOOLEAN;

PROCEDURE term() : CSS2.Term;
VAR
	term : CSS2.Term;
	i : INTEGER;
	
	PROCEDURE piece() : Pieces.Piece;
	VAR piece : Pieces.Piece;
	BEGIN
		piece := Pieces.From(Scanner.file, Scanner.pStart);
		Pieces.Lengthen(piece, Scanner.pEnd - Scanner.pStart);
		RETURN piece
	END piece;
	
BEGIN
	NEW(term); term.color := CSS2.noColor;
	IF sym = Scanner.number THEN
		term.num := Scanner.val; term.realNum := Scanner.realVal;
		Scanner.Get(sym);
		IF sym = Scanner.ident THEN	
			IF Scanner.id= "em" THEN term.unit := CSS2.em; Scanner.Get(sym)
			ELSIF Scanner.id= "ex" THEN term.unit := CSS2.ex; Scanner.Get(sym)
			ELSIF Scanner.id= "px" THEN term.unit := CSS2.px; Scanner.Get(sym)
			ELSIF Scanner.id= "cm" THEN term.unit := CSS2.cm; Scanner.Get(sym)
			ELSIF Scanner.id= "mm" THEN term.unit := CSS2.mm; Scanner.Get(sym)
			ELSIF Scanner.id= "in" THEN term.unit := CSS2.in; Scanner.Get(sym)
			ELSIF Scanner.id= "pt" THEN term.unit := CSS2.pt; Scanner.Get(sym)
			ELSIF Scanner.id= "pc" THEN term.unit := CSS2.pc; Scanner.Get(sym)
			ELSIF Scanner.id= "deg" THEN term.unit := CSS2.deg; Scanner.Get(sym)
			ELSIF Scanner.id= "rad" THEN term.unit := CSS2.rad; Scanner.Get(sym)
			ELSIF Scanner.id= "grad" THEN term.unit := CSS2.grad; Scanner.Get(sym)
			ELSIF Scanner.id= "ms" THEN term.unit := CSS2.ms; Scanner.Get(sym)
			ELSIF Scanner.id= "s" THEN term.unit := CSS2.s; Scanner.Get(sym)
			ELSIF Scanner.id= "kHz" THEN term.unit := CSS2.kHz; Scanner.Get(sym)
			ELSIF Scanner.id= "Hz" THEN term.unit := CSS2.Hz; Scanner.Get(sym)
			ELSE term.unit := CSS2.dimless 
			END
		ELSIF sym = Scanner.percent THEN term.unit := CSS2.percent; Scanner.Get(sym)
		ELSE term.unit := CSS2.dimless
		END; RETURN term
	ELSIF sym = Scanner.hash THEN
		IF Strings.Length(Scanner.id) = 6 THEN
  		i := 0; term.color := 0; WHILE i < 6 DO
  			IF (Scanner.id[i] >= "0") & (Scanner.id[i] <= "9") THEN
  				term.color := term.color * 16 + ORD(Scanner.id[i]) - ORD("0")
  			 ELSIF (Scanner.id[i] >= "a") & (Scanner.id[i] <= "f") THEN
  				term.color := term.color * 16 + ORD(Scanner.id[i]) - ORD("a") + 10
  			 ELSE term.color := CSS2.noColor; i := 99
  			END; INC(i)
			END
		ELSIF Strings.Length(Scanner.id) = 3 THEN
			i := 0; term.color := 0; WHILE i < 3 DO
				IF (Scanner.id[i] >= "0") & (Scanner.id[i] <= "9") THEN
					term.color := term.color * 256 + (ORD(Scanner.id[i]) - ORD("0")) * 17
				 ELSIF (Scanner.id[i] >= "a") & (Scanner.id[i] <= "f") THEN
					term.color := term.color * 256 + (ORD(Scanner.id[i]) - ORD("a") + 10) * 17
				 ELSE term.color := CSS2.noColor; i := 99
				END; INC(i)
			END
		END
	END;
	term.piece := piece();
	term.unit := CSS2.piece;
	Scanner.Get(sym);
	RETURN term
END term;


PROCEDURE expression() : CSS2.Term;
(* Returns a list of terms. Expression doesnt have a own Type *)
VAR
	firstTerm, t, lastTerm : CSS2.Term;
	operator : CHAR;
BEGIN
	firstTerm := term(); firstTerm.operator := " ";
	lastTerm := firstTerm;
	WHILE (sym # Scanner.semicolon) & (sym # Scanner.rbrace) & (sym # Scanner.eof) DO
		IF sym = Scanner.slash THEN operator := "/"; Scanner.Get(sym)
		ELSIF sym = Scanner.comma THEN operator := ","; Scanner.Get(sym)
		ELSE operator := " "
		END;
		t := term(); t.operator := operator;
		lastTerm.next := t; lastTerm := t
	END;
	RETURN firstTerm
END expression;


PROCEDURE declaration() : CSS2.Declaration;
VAR
	d : CSS2.Declaration;
BEGIN
	IF debug THEN Out.String("Declaration(") END;
	NEW(d);
	IF sym = Scanner.ident THEN
		COPY(Scanner.id, d.property);
		Scanner.Get(sym);
		IF sym = Scanner.colon THEN Scanner.Get(sym) ELSE valid := FALSE END;
		d.firstTerm := expression();
			
	ELSE valid := FALSE
	END;
	IF debug THEN Out.Char(")") END;
	RETURN d
END declaration;


PROCEDURE selector() : CSS2.Selector;
VAR
	s : CSS2.Selector;
	ss : CSS2.SimpleSelector;
	a, b, c : SHORTINT ;
	
	PROCEDURE IncASpecifity;
	(* see CSS2, Page 74 *)
	BEGIN INC(a); IF a > maxASpecifity THEN a := maxASpecifity END
	END IncASpecifity;
	
	PROCEDURE IncBSpecifity;
	BEGIN INC(b); IF b > maxBSpecifity THEN b := maxBSpecifity END
	END IncBSpecifity;

	PROCEDURE IncCSpecifity;
	BEGIN INC(c); IF c > maxCSpecifity THEN c := maxCSpecifity END
	END IncCSpecifity;

	PROCEDURE CalculateSpecifity() : CSS2.Specifity ;
	BEGIN RETURN a * ASpecifityMult + b * BSpecifityMult + c
	END CalculateSpecifity ;
	
	PROCEDURE simpleSelector() : CSS2.SimpleSelector;
	VAR
		s : CSS2.SimpleSelector;
		pseudo: CSS2.Pseudo; id : CSS2.ID; class : CSS2.Class;
		
		PROCEDURE getPseudo() : CSS2.Pseudo ;
		VAR
			pseudo: CSS2.Pseudo;
		BEGIN
			NEW(pseudo);
			IF sym = Scanner.ident THEN
				IF Scanner.id = "first-child" THEN pseudo.kind := CSS2.firstChild
				ELSIF Scanner.id = "link" THEN pseudo.kind := CSS2.link
				ELSIF Scanner.id = "visited" THEN pseudo.kind := CSS2.visited
				ELSIF Scanner.id = "hover" THEN pseudo.kind := CSS2.hover
				ELSIF Scanner.id = "activ" THEN pseudo.kind := CSS2.activ
				ELSIF Scanner.id = "focus" THEN pseudo.kind := CSS2.focus
				ELSIF Scanner.id = "lang" THEN pseudo.kind := CSS2.lang;
					Scanner.Get(sym);
					IF sym = Scanner.lparen THEN
						Scanner.Get(sym);
						IF sym = Scanner.ident THEN
							COPY(Scanner.id, pseudo.lang); Scanner.Get(sym);
							IF sym = Scanner.rparen THEN Scanner.Get(sym) ELSE valid := FALSE END
						ELSE valid := FALSE
						END
					ELSE valid := FALSE
					END
				ELSIF Scanner.id = "first-line" THEN pseudo.kind := CSS2.firstLine
				ELSIF Scanner.id = "first-letter" THEN pseudo.kind := CSS2.firstLetter
				ELSIF Scanner.id = "before" THEN pseudo.kind := CSS2.before
				ELSIF Scanner.id = "after" THEN pseudo.kind := CSS2.before
				ELSE valid := FALSE
			END
			ELSE valid := FALSE
			END; RETURN pseudo
		END getPseudo;

	
	BEGIN
		NEW(s);
		IF sym = Scanner.ident THEN
			Strings.Upper(Scanner.id, s.type);
			IF debug THEN Out.String(Scanner.id) END; Scanner.Get(sym);
			IncCSpecifity;
		ELSIF (sym = Scanner.asterix) THEN s.type := "*"; Scanner.Get(sym)
		ELSIF (sym = Scanner.hash) OR (sym = Scanner.point) THEN s.type := "*"
		ELSE valid := FALSE
		END;
		
		WHILE (sym = Scanner.hash) OR (sym = Scanner.point) OR (sym = Scanner.lbrak) OR (sym = Scanner.colon) DO
			CASE sym OF
				Scanner.hash :
					Scanner.Get(sym);
					IF sym = Scanner.ident THEN
						NEW(id); IncASpecifity;
						COPY(Scanner.id, id.id); Scanner.Get(sym);
						id.next := s.subselectors; s.subselectors  := id
					 ELSE valid := FALSE
					END |
				Scanner.point : 
					Scanner.Get(sym);
					IF sym = Scanner.ident THEN
						NEW(class); IncBSpecifity;
						COPY(Scanner.id, class.class); Scanner.Get(sym);
						class.next := s.subselectors; s.subselectors  := class
					 ELSE valid := FALSE
					END |				
				Scanner.colon:
					Scanner.Get(sym);
					pseudo := getPseudo() ;
					IF pseudo # NIL THEN
						IncBSpecifity;
						pseudo.next := s.subselectors; s.subselectors  := pseudo
					END |
				Scanner.lbrak :
					(* not yet implemented *) IncBSpecifity;
					WHILE (sym # Scanner.rbrak) & (sym # Scanner.eof) DO Scanner.Get(sym) END;
					IF sym = Scanner.rbrak THEN Scanner.Get(sym) END
			END 
		END; RETURN s
	END simpleSelector;


BEGIN
	IF debug THEN Out.String("Selector(") END;
	NEW(s); s.simpleSelector := simpleSelector();
	WHILE (sym=Scanner.ident) OR (sym=Scanner.greater) OR (sym=Scanner.plus) DO
		CASE sym OF
			Scanner.ident : s.simpleSelector.combinator := CSS2.over |
			Scanner.greater : Scanner.Get(sym); s.simpleSelector.combinator := CSS2.parent |
			Scanner.plus : Scanner.Get(sym); s.simpleSelector.combinator := CSS2.preceeder
		END; (* CASE *)
		ss := simpleSelector(); ss.next := s.simpleSelector; s.simpleSelector := ss
	END; s.specifity := CalculateSpecifity(); 
	
	IF debug THEN Out.Char(")") END;
	RETURN s 
END selector;


PROCEDURE ruleset() : CSS2.RuleSet;
VAR
	r : CSS2.RuleSet;
	s : CSS2.Selector ;
	d, last : CSS2.Declaration;
BEGIN
	IF debug THEN Out.String("Ruleset(") END;

	NEW(r); r.selectors := selector();
	WHILE sym = Scanner.comma DO
		Scanner.Get(sym);
		IF debug THEN Out.Char(",") END;
		s := selector();
		s.next := r.selectors; r.selectors := s
	END;
	
	IF sym = Scanner.lbrace THEN
		Scanner.Get(sym);
		IF debug THEN Out.Char("{") END;
		r.declarations := declaration() ;
		WHILE sym = Scanner.semicolon DO
			IF debug THEN Out.Char(";") END;
			Scanner.Get(sym);
			d := declaration();
			IF r.declarations # NIL THEN
				last := r.declarations; WHILE last.next # NIL DO last := last.next END ;
				last.next := d
			 ELSE
				r.declarations := d
			END
		END;
		WHILE sym # Scanner.rbrace DO Scanner.Get(sym) END;
		Scanner.Get(sym) ; IF debug THEN Out.Char("}") END;
	 ELSE valid := FALSE
	END; 
	IF debug THEN Out.Char(")"); Out.Ln END;
	RETURN r
END ruleset;

PROCEDURE mediaList() : SET;
VAR m : SET;
BEGIN
	m := {}; REPEAT
		IF Scanner.id = "all" THEN m := {CSS2.aural..CSS2.tv}
		ELSIF Scanner.id = "aural" THEN INCL(m, CSS2.aural)
		ELSIF Scanner.id = "braille" THEN INCL(m, CSS2.braille)
		ELSIF Scanner.id = "emboss" THEN INCL(m, CSS2.emboss)
		ELSIF Scanner.id = "handheld" THEN INCL(m, CSS2.handheld)
		ELSIF Scanner.id = "print" THEN INCL(m, CSS2.print)
		ELSIF Scanner.id = "projection" THEN INCL(m, CSS2.projection)
		ELSIF Scanner.id = "screen" THEN INCL(m, CSS2.screen)
		ELSIF Scanner.id = "tty" THEN INCL(m, CSS2.tty)
		ELSIF Scanner.id = "tv" THEN INCL(m, CSS2.tv)
		END ;
		Scanner.Get(sym);
		IF sym = Scanner.comma THEN Scanner.Get(sym) END;
	UNTIL sym # Scanner.ident ;
	RETURN m
END mediaList;
		
PROCEDURE media() : CSS2.Media ;
VAR
	m : CSS2.Media ;
BEGIN
	NEW(m) ;
	IF sym = Scanner.ident THEN m.media := mediaList() END;
	IF sym = Scanner.lbrace THEN
		Scanner.Get(sym);
		m.rulesets := ruleset(); (* falsch *)
		IF sym = Scanner.rbrace THEN Scanner.Get(sym) END
	END;
	RETURN m
END media;


PROCEDURE Page ;
(* not yet .. *)
VAR pageDecl : CSS2.Declaration ;
BEGIN
	IF sym = Scanner.ident THEN Scanner.Get(sym) END;
	IF sym = Scanner.colon THEN
		Scanner.Get(sym);
		IF sym = Scanner.ident THEN Scanner.Get(sym) END
	END ;
	IF sym = Scanner.lbrace THEN
		Scanner.Get(sym);
		REPEAT
			pageDecl := declaration() ;
			IF sym = Scanner.semicolon THEN Scanner.Get(sym) END
		UNTIL sym = Scanner.rbrace;
		IF sym = Scanner.lbrace THEN Scanner.Get(sym) END
	END
END Page ;




PROCEDURE styleSheet() : CSS2.StyleSheet;
VAR
	s : CSS2.StyleSheet;
	r : CSS2.RuleSet;
	m : CSS2.Media ;
BEGIN
	NEW(s);
	IF sym = Scanner.at THEN
		IF Scanner.id = "charset" THEN
			Scanner.Get(sym);
			IF sym = Scanner.ident THEN Scanner.Get(sym) END;
			IF sym = Scanner.semicolon THEN Scanner.Get(sym) END;
		END;
		
		(* imports werden ignoriert *)
		WHILE (sym = Scanner.at) & (Scanner.id = "import") DO
			REPEAT
				Scanner.Get(sym)
			UNTIL sym = Scanner.semicolon; Scanner.Get(sym)
		END;
	END;
	
	WHILE sym # Scanner.eof DO
		IF sym = Scanner.at THEN
			IF Scanner.id = "media" THEN
				Scanner.Get(sym);
				m := media() ;	 
				m.next := s.media; s.media := m
			ELSIF Scanner.id = "page" THEN Scanner.Get(sym); Page
			ELSE Scanner.Get(sym);
			END		
		ELSIF sym = Scanner.ident THEN
			r := ruleset();
			IF ~valid & debug THEN Out.String("CSS2.Declaration not valid? ") ; Out.Ln END ;
			r.next := s.rulesets; s.rulesets := r
		ELSE Scanner.Get(sym);
		END
	END; RETURN s
END styleSheet;


PROCEDURE ReadStyleSheet*(f : Files.File; offset : LONGINT) : CSS2.StyleSheet ;
BEGIN
	Scanner.Init(f, offset); Scanner.Get(sym); RETURN styleSheet()
END ReadStyleSheet;

PROCEDURE ReadDeclaration*(f : Files.File; offset : LONGINT) : CSS2.Declaration ;
BEGIN
	Scanner.Init(f, offset); RETURN declaration()
END ReadDeclaration;


PROCEDURE HTML4LengthTerm*(piece : Pieces.Piece) : CSS2.Term;
VAR
	term : CSS2.Term;
	R : Files.Rider;
	pos : LONGINT;
	ch : CHAR;
BEGIN
	NEW(term);
	IF piece = NIL THEN RETURN term END;
	Files.Set(R, piece.f, piece.off); pos := 1; Files.Read(R, ch);
	WHILE (pos <= piece.len) & ~R.eof & (ch >= "0") & (ch <= "9") DO
		term.num := term.num * 10 + ORD(ch) - ORD("0");
		Files.Read(R, ch); INC(pos);
	END;
	IF ch = "%" THEN term.unit := CSS2.percent
	ELSE term.unit := CSS2.dimless
	END;
	term.realNum := term.num;
	RETURN term
END HTML4LengthTerm;


END WebCSS2P.