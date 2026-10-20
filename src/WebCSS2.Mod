MODULE WebCSS2;	(* OutLines.Expand * OutLines.Collapse *)

IMPORT HTML4 := WebHTML4, Pieces := WebPieces, Files, Fonts, Strings;

CONST
	DefaultColor* = 0*256*256 + 0*256 + 0;
	GrooveColor* = 48*256*256 + 48*256 + 48;
	RidgeColor* = 192*256*256 + 192*256 + 192;

CONST
	(*FontNameLen = 26;*) maxTagLen = 10;

CONST
	top* = 0; right* = 1; bottom* = 2; left* = 3;

CONST
	elementName* = 1; parent* = 2; over* = 3; preceeder* = 4; (* .. better word for over? *)

CONST (* Reihenfolge wichtig, z.B. in WebCSS2.CalcWidth *)
	dimless * = 0;
	em* = 1; ex* = 2; px* = 3 ; cm* = 4; mm* = 5; in* = 6; pt* = 7; pc*=8;
	percent* = 9;
	deg* = 10; rad* = 11; grad* = 12;
	ms* = 21; s* = 22; 
	Hz* = 31 ; kHz* = 32;
	color* = 40;
	piece* = 50;
	unknownUnit* = 60;

CONST
	fontSizes = 7;
	greatestFont = fontSizes - 1;

CONST
	transparent* = -1;
	noColor* = -2;

VAR
	DefFontSize : ARRAY fontSizes OF REAL;

CONST
	allMedia* = 0; aural* = 1; braille* = 2; emboss* = 3; handheld* = 4; print* = 5; projection* = 6; screen* = 7; tty* = 8; tv* = 9;
	
CONST
	firstChild* = 1; link* = 2; visited* = 3;
	hover* = 11; activ*= 12; focus*=13; 
	lang* = 21; firstLine* = 22; firstLetter* = 23;
	before* = 31; after* = 32;

CONST
	notDefined* = MAX(LONGINT);

TYPE
	Specifity* = SHORTINT ;

TYPE
	StyleSheet* = POINTER TO StyleSheetDesc;
	Import* = POINTER TO ImportDesc;
	RuleSet* = POINTER TO RuleSetDesc;
	Selector* = POINTER TO SelectorDesc;
	SimpleSelector* = POINTER TO SimpleSelectorDesc;
	FontName* = POINTER TO FontNameDesc;
	Declaration* = POINTER TO DeclarationDesc;
	Term* = POINTER TO TermDesc;
	SubSelector* = POINTER TO SubSelectorDesc;
	AttributeS* = POINTER TO AttributeSDesc;
	Pseudo* = POINTER TO PseudoClassDesc;
	ID* = POINTER TO IDDesc;
	Class* = POINTER TO ClassDesc;
	Media* = POINTER TO MediaDesc ;

	StyleSheetDesc* = RECORD
		(* charset* : ... ; wird ignoriert und ISO angenommen *)
		import* : Import ;
		rulesets* : RuleSet;
		media* : Media ;
		(* page* : ... ; wird ignoriert *)
		(* fontFace* : ... ; wird ignoriert *)
	END;
	
	ImportDesc* = RECORD
		next* : Import ;
		url* : Pieces.Piece ;
		media* : SET ;
	END;
	
	MediaDesc* = RECORD
		next* : Media ;
		media* : SET ;
		rulesets* : RuleSet;
	END ;
	
	RuleSetDesc* = RECORD
		next* : RuleSet;
		selectors* : Selector;
		declarations* : Declaration;
	END;
	
	SelectorDesc* = RECORD
		next* : Selector;
		specifity* : Specifity;
		simpleSelector* : SimpleSelector;
	END;
	
	SimpleSelectorDesc* = RECORD
		next* : SimpleSelector;
		type* : ARRAY maxTagLen + 1 OF CHAR ; (* Type of the element (e.g. "H1") or "*" *)
		combinator* : SHORTINT;
		subselectors* : SubSelector; (* for attributes, ID-selectors and pseude-classes *)
	END;
	
	SubSelectorDesc* = RECORD next* : SubSelector END ;
	AttributeSDesc* = RECORD (SubSelectorDesc) attribute* : Declaration END ;
	PseudoClassDesc* = RECORD (SubSelectorDesc)
		kind* : SHORTINT ;
		lang* : ARRAY 3 OF CHAR END ;
	IDDesc* = RECORD (SubSelectorDesc) id* : ARRAY 12 OF CHAR END ;
	ClassDesc* = RECORD (SubSelectorDesc) class* : ARRAY 12 OF CHAR END;
	
	FontNameDesc* = RECORD;
		next* : FontName ;
		piece* : Pieces.Piece;
	END; 
	
	DeclarationDesc* = RECORD
		next* : Declaration;
		property* : ARRAY 32 OF CHAR;
		firstTerm* : Term; (* "Expression" not needed *)
		important* : BOOLEAN;
	END;
		
	TermDesc* = RECORD
		next* : Term;
		operator* : CHAR; (* Operator before *this* term. First term has operator = " " *)
		unit* : SHORTINT;
		num* : LONGINT; 
		realNum* : REAL;
		color* : LONGINT;
		piece* : Pieces.Piece ;
	END;
	
TYPE
	Properties* = RECORD
		top*, bottom*, left*, right * : Term ;
		width*, height* : Term ;
		backgroundFixed* : BOOLEAN ;
		backgroundColor* : LONGINT ;
		backgroundImage* : Pieces.Piece ;
		backgroundPositionH*, backgroundPositionV* : Term;
		backgroundRepeatH*, backgroundRepeatV* : BOOLEAN; 
		borderCollapse* : BOOLEAN ;
		borderColor* : ARRAY 4 OF LONGINT ;
		borderSpacing* : ARRAY 2 OF Term ;
		borderStyle* : ARRAY 4 OF SHORTINT ;
		borderWidth* : ARRAY 4 OF Term;
		captionSide* : SHORTINT ;
		clearLeft*, clearRight* : BOOLEAN ;
		clip* : Pieces.Piece ;
		color* : LONGINT ;
		content*: Pieces.Piece ;
		(* cursor*: Declaration ; *)
		directionLTR* : BOOLEAN ;
		display* : SHORTINT;
		emptyCellsShow* : BOOLEAN ;
		floatLeft*, floatRight* : BOOLEAN ;
		font* : Fonts.Font;
		fontFamily : Declaration ;
		fontSize : LONGINT;
		(*fontSizeAdjust : INTEGER ;*)
		(*fontStretch : INTEGER ;*)
		fontStyle : SHORTINT ;
		fontVariant : SHORTINT ;
		fontWeight : SHORTINT ;
		letterSpacing* : Term ;
		lineHeightTerm : Term ;
		lineHeight* : LONGINT;
		listStyleImage* : Term ;
		listStylePositionOutside* : BOOLEAN ;
		listStyleType* : SHORTINT ;
		margin* : ARRAY 4 OF Term;
		markerOffset* : Term ;
		maxHeight*, maxWidth* : Term ;
		minHeight*, minWidth* : Term ;
		overflow* : SHORTINT ;
		padding* : ARRAY 4 OF Term ;
		position* : SHORTINT ;
		quotes* : ARRAY 2 OF CHAR ;
		tableLayoutFixed* : BOOLEAN ;
		textAlign* : Term ;
		textDecoration* : SET ;
		textDecorationColor* : LONGINT;
		textIndent* : Term ;
		textShadow* : Term ;
		textTransform* : SET ;
		(* unicodeBidi* : INTEGER ; *)
		verticalAlignTerm : Term;
		verticalAlign* : LONGINT;
		verticalAlignType* : SET;
		visibility* : SHORTINT ;
		whiteSpacePre* : BOOLEAN ;
		wordSpacing* : Term ;
		zIndex* : LONGINT ;
	END ;

CONST (* display *)
		none* = 0 ;
		inline* =  1 ; block* =  2 ; listItem* =  3 ; runIn* =  4 ; compact* =  5 ; marker* =  6 ;
		table* =  7 ; inlineTable* =  8 ; tableRowGroup* =  9 ; tableHeaderGroup* = 10 ; tableFooterGroup* = 11 ;
		tableRow* = 12 ; tableColumnGroup* = 13 ; tableColumn* = 14; tableCell* = 15; tableCaption*= 16; 

CONST (* borderStyle *)
		(* none* = 0 *)
		hidden* = 1; dotted* = 2; dashed* = 3; solid* = 4; double* = 5;

CONST (* fontStyle *)
		normal* = 1; italic* = 2; oblique* = 3;

CONST (* listStyleType *)
		(* none* = 0 *)
		disc* = 1; circle* = 2; square* = 3; decimal* = 4; decimalLeadingZero* = 5; lowerRoman* = 6;
		upperRoman* = 7; lowerGreek* = 8; lowerAlpha* = 9; lowerLatin* = 10; upperAlpha* = 11; upperLatin* = 12;
		hebrew* = 13; armenian* = 14; georgian* = 15; cjkIdeographic* = 16; hiraGana* = 17; katakana* = 18;
		hiraGanaIroha* = 19; katakanaIroha* = 20; (* :-) *)
		
CONST (* overflow *)
		(* hidden = 1 *)
		auto* = 2; visible* = 3; scroll* = 4;
		
CONST (* position *)
		static* = 1; relative* = 2; absolute* = 3; fixed* = 4;
		
CONST (* text-decoration *)
		underline* = 1; overline* = 2; lineThrough* = 3; blink* = 4;

CONST (* visibility *)
		(* visible = 3, hidden = 1 *)
		collapse* = 2;
		
CONST (* vertical-align-type (wird gebraucht, um rekursive Inlines zu umgehen) *)
		(* top = 0; normal = 1; bottom = 2 *)
		middle* = 3;

TYPE
	Hit = POINTER TO HitDesc ;
	HitDesc = RECORD
		nextBetter : Hit;
		specifity : Specifity;
		declarations :Declaration;
	END;
	(*HitList = Hit;*)

VAR
	term0Percent, term50Percent, term100Percent, term2px, termAuto, termLeft, term0 : Term;
VAR
	autoStr : ARRAY 5 OF CHAR; autoPiece : Pieces.Piece;
	leftStr : ARRAY 5 OF CHAR; leftPiece : Pieces.Piece;

VAR
	defaultProperties* : Properties ;
	
VAR
	Unit* : ARRAY pc + 1 OF REAL;
	devicePixelSize : LONGINT; (* in 1/36000 mm *)

		
PROCEDURE matchingSelector(selector : Selector; element : HTML4.Element) : BOOLEAN; 
VAR
	ss : SimpleSelector ;
	
BEGIN
	ss := selector.simpleSelector;  
	IF ss = NIL THEN HALT(86) END ;
	IF (element = NIL) OR (element.type = NIL) OR (ss.type # element.type.name) THEN RETURN FALSE END;
	
	(* .. WHILE ? *)
	REPEAT
		(* .. IF ss.subselectors # NIL THEN not yet implemented *)
		ss := ss.next ;
		IF ss # NIL THEN
			CASE ss.combinator OF
				parent :
					element := element.parent ;
					IF (element.type = NIL) OR (ss.type # element.type.name) THEN RETURN FALSE END
				| over:
					element := element.parent ;
					WHILE (element # NIL) & ((element.type = NIL) OR (ss.type # element.type.name)) DO element := element.parent END;
					IF element = NIL THEN RETURN FALSE END
					
(* ..			| preceeder: 	(* man m…sste die bisherigen Br…der aufspeichern *)
					IF preceederUsed THEN RETURN FALSE END ; (* .. to do : E + F + G wird nicht erkannt (man m…sste den ganzen Baum speichern *)
					IF ss.type # stack.preceeder.name THEN RETURN FALSE END ;
					preceederUsed := TRUE ;  *)
					
				ELSE
					HALT(85)
			END
		END
	UNTIL ss = NIL; RETURN TRUE
END matchingSelector;


PROCEDURE matchingRuleSet(ruleset : RuleSet; element : HTML4.Element) : Specifity;
VAR
	s : Selector ;
	bestSpecifity : Specifity ;
	
BEGIN
	s := ruleset.selectors; bestSpecifity := MIN(Specifity) ;
	WHILE s # NIL DO
		IF matchingSelector(s, element) & (s.specifity > bestSpecifity) THEN bestSpecifity := s.specifity END;
		s := s.next
	END; RETURN bestSpecifity
END matchingRuleSet;


PROCEDURE JeanLucWicki(element : HTML4.Element; styleSheet : StyleSheet) : Hit ;

VAR
	ruleset : RuleSet ;
	hit, insertPoint : Hit;
	specifity : Specifity ;
	hitList : Hit;
	
BEGIN
	ruleset := styleSheet.rulesets; IF ruleset = NIL THEN HALT(83) END;
	WHILE ruleset # NIL DO
		 specifity := matchingRuleSet(ruleset, element) ;
		 IF specifity > MIN(Specifity) THEN
			NEW(hit); 
			hit.declarations := ruleset.declarations ;
			hit.specifity := specifity;
			
			IF hitList = NIL THEN hitList := hit ELSE
				insertPoint := hitList ;
				WHILE (insertPoint.nextBetter # NIL) & (specifity > insertPoint.specifity) DO
					insertPoint := insertPoint.nextBetter
				END ;
				hit.nextBetter := insertPoint.nextBetter;
				insertPoint.nextBetter := hit
			END
		END;
		ruleset := ruleset.next
	END; RETURN hitList
END JeanLucWicki;

PROCEDURE Equal*(term : Term; str : ARRAY OF CHAR) : BOOLEAN;
VAR
	R : Files.Rider;
	pos : LONGINT;
	ch : CHAR;
	strLen : LONGINT;
	
BEGIN
	IF term.unit # piece THEN RETURN FALSE END;
	strLen := Strings.Length(str);
	IF term.piece.len # strLen THEN RETURN FALSE END;
	Files.Set(R, term.piece.f, term.piece.off);pos := 0;
	WHILE (pos < term.piece.len) & ~R.eof & (pos < strLen) DO
		Files.Read(R, ch);
		IF CAP(ch) # CAP(str[pos]) THEN RETURN FALSE END;
		INC(pos)
	END; RETURN pos = strLen
END Equal;

PROCEDURE CalcWidth*(term : Term; percentOf : LONGINT; font : Fonts.Font; parentWidth : LONGINT) : LONGINT;
BEGIN
	IF term = NIL THEN RETURN 0
	ELSIF Equal(term, "inherit") THEN RETURN parentWidth
	END;
	CASE term.unit OF
		  dimless, px : RETURN term.num
		| percent : RETURN term.num * percentOf DIV 100
		| cm .. pc : RETURN ENTIER (term.realNum * Unit[term.unit])
		| em : RETURN ENTIER (term.realNum * font.height)
		| ex : RETURN ENTIER (term.realNum * font.height / 2)
	ELSE RETURN 0 (* TRAP *)
	END
	(* TRAP *)
END CalcWidth;

PROCEDURE CalcBorderWidth*(term : Term; font : Fonts.Font; parentWidth : LONGINT) : LONGINT;
VAR res : LONGINT;
BEGIN
	IF (term = NIL) OR Equal(term, "thin") THEN RETURN ENTIER(Unit[px])
	ELSIF Equal(term, "medium") THEN RETURN ENTIER(2*Unit[px])
	ELSIF Equal(term, "thick") THEN RETURN ENTIER(3*Unit[px])
	ELSIF Equal(term, "inherit") THEN RETURN parentWidth
	ELSIF term.unit > pc THEN RETURN ENTIER(Unit[px])
	ELSE
		res := CalcWidth(term, 0, font, parentWidth);
		IF res < 0 THEN RETURN 0 ELSE RETURN res END
	END
END CalcBorderWidth;

PROCEDURE InheritProperties*(VAR (** out *) properties : Properties; VAR (** in *) parentP : Properties);
BEGIN
	properties.borderCollapse := parentP.borderCollapse ;
	properties.borderSpacing[0] := parentP.borderSpacing[0]; properties.borderSpacing[1] := parentP.borderSpacing[1] ;
	properties.captionSide := parentP.captionSide ;
	properties.color := parentP.color ;
	(* properties.cursor := parentP.cursor ; *)
	properties.emptyCellsShow := parentP.emptyCellsShow ;
	properties.fontFamily := parentP.fontFamily;
	properties.fontSize := parentP.fontSize;
	properties.fontStyle := parentP.fontStyle;
	properties.fontVariant := parentP.fontVariant;
	properties.fontWeight := parentP.fontWeight ;
	properties.letterSpacing := parentP.letterSpacing ;
	properties.lineHeight := parentP.lineHeight ;
	properties.listStyleImage := parentP.listStyleImage;
	properties.listStylePositionOutside := parentP.listStylePositionOutside;
	properties.listStyleType := parentP.listStyleType;
	(* properties.quotes := parentP.quotes; *)
	properties.textAlign := parentP.textAlign;
	properties.textDecoration := parentP.textDecoration;
	properties.textDecorationColor := parentP.textDecorationColor;
	properties.textIndent := parentP.textIndent;
	properties.textTransform := parentP.textTransform;
	properties.whiteSpacePre := parentP.whiteSpacePre;
	properties.wordSpacing := parentP.wordSpacing;
END InheritProperties;

PROCEDURE ^ CheckValues*(VAR properties : Properties; VAR parentP : Properties);

PROCEDURE AssignValues*(VAR (** out *) properties : Properties; element : HTML4.Element;
	VAR (** in *) parentP : Properties; stylesheet : StyleSheet);

VAR
	hitList : Hit;
	size: Pieces.Piece;
	sizeStr : ARRAY 8 OF CHAR;
	j : INTEGER;
	color : LONGINT;
	
	PROCEDURE nextSmallerFont;
	VAR
		oldSize : LONGINT;
		i : INTEGER;
	BEGIN
		oldSize := properties.fontSize; properties.fontSize := 0;
		IF oldSize <= DefFontSize[0] * Unit[px] THEN properties.fontSize := oldSize END;
		i := 1; WHILE (properties.fontSize = 0) & (i <= greatestFont) DO
			IF oldSize <= DefFontSize[i] * Unit[px] THEN 
				properties.fontSize := ENTIER(DefFontSize[i-1] * Unit[px])
			END; INC(i)
		END;
		IF properties.fontSize = 0 THEN properties.fontSize := ENTIER(DefFontSize[0] * Unit[px]) END
	END nextSmallerFont;
	
	PROCEDURE nextLargerFont;
	VAR
		oldSize : LONGINT;
		i : INTEGER;
	BEGIN
		oldSize := properties.fontSize; properties.fontSize := 0;
		IF oldSize >= DefFontSize[greatestFont] * Unit[px] THEN properties.fontSize := oldSize END;
		i := fontSizes-1; WHILE (properties.fontSize = 0) & (i >= 0) DO
			IF oldSize >= DefFontSize[i] * Unit[px] THEN 
				properties.fontSize := ENTIER(DefFontSize[i+1] * Unit[px])
			END; DEC(i)
		END;
		IF properties.fontSize = 0 THEN properties.fontSize := ENTIER(DefFontSize[greatestFont] * Unit[px]) END
	END nextLargerFont;


	PROCEDURE PlayHitList;
	VAR
		hit : Hit;
		declaration : Declaration;
		term1, term2, term3, term4, term5, term6 : Term;
		edge : SHORTINT;
		color : LONGINT; colorStr : ARRAY 16 OF CHAR;
		
		PROCEDURE Is(what : SHORTINT; term : Term) : BOOLEAN;
		BEGIN RETURN term.unit = what END Is;
		
		PROCEDURE IsLength(term : Term) : BOOLEAN;
		BEGIN RETURN term.unit <= pc END IsLength;

		(* folgende IF - Verzweigungen werden mehrmals gebraucht. Entweder in Shorthands oder
			in normaler Form. Daher habe ich sie in Prozeduren ausgelagert *)

		PROCEDURE backgroundAttachment(term : Term);
		BEGIN
			IF Equal(term, "scroll") THEN properties.backgroundFixed := FALSE
			ELSIF Equal(term, "fixed") THEN properties.backgroundFixed := TRUE
			ELSIF Equal(term, "inherit") THEN properties.backgroundFixed := parentP.backgroundFixed
			END
		END backgroundAttachment;
		
		PROCEDURE backgroundColor(term : Term);
		BEGIN
			IF term.color # noColor THEN properties.backgroundColor := term.color
			ELSIF term1.piece # NIL THEN
				Pieces.Convert(term1.piece, colorStr);
				color := HTML4.NamedColor(colorStr);
				IF color >= 0 THEN properties.backgroundColor := color END
			ELSIF Equal(term, "inherit") THEN properties.backgroundColor := parentP.backgroundColor
			END
		END backgroundColor;
		
		PROCEDURE backgroundImage(term : Term);
		BEGIN
			IF Is(piece, term) THEN properties.backgroundImage := term.piece
			ELSIF Equal(term, "none") THEN properties.backgroundImage := NIL
			ELSIF Equal(term, "inherit") THEN properties.backgroundImage := parentP.backgroundImage
			END
		END backgroundImage;
		
		PROCEDURE backgroundPosition(term1, term2 : Term);
		BEGIN
			IF IsLength(term1) OR Is(percent, term1) THEN properties.backgroundPositionV := term1
			ELSIF Equal(term1, "top") THEN properties.backgroundPositionV := term0Percent	
			ELSIF Equal(term1, "center") THEN properties.backgroundPositionV := term50Percent	
			ELSIF Equal(term1, "bottom") THEN properties.backgroundPositionV := term100Percent		
			ELSIF Equal(term1, "inherit") THEN
				properties.backgroundPositionV := term1; properties.backgroundPositionH := term1
			END;
			IF term2 # NIL THEN
				IF IsLength(term2) OR Is(percent, term2) THEN properties.backgroundPositionH := term2
				ELSIF Equal(term2, "top") THEN properties.backgroundPositionH := term0Percent	
				ELSIF Equal(term2, "center") THEN properties.backgroundPositionH := term50Percent	
				ELSIF Equal(term2, "bottom") THEN properties.backgroundPositionH := term100Percent
				END
			END
		END backgroundPosition;
		
		PROCEDURE backgroundRepeat(term : Term);
		BEGIN
			IF Equal(term, "repeat") THEN	
				properties.backgroundRepeatH := TRUE; properties.backgroundRepeatV := TRUE
			ELSIF Equal(term, "repeat-x") THEN
				properties.backgroundRepeatH := TRUE; properties.backgroundRepeatV := FALSE
			ELSIF Equal(term, "repeat-y") THEN
				properties.backgroundRepeatH := FALSE; properties.backgroundRepeatV := TRUE
			ELSIF Equal(term, "no-repeat") THEN
				properties.backgroundRepeatH := FALSE; properties.backgroundRepeatV := FALSE
			ELSIF Equal(term, "inherit") THEN
				properties.backgroundRepeatH := parentP.backgroundRepeatH;
				properties.backgroundRepeatV := parentP.backgroundRepeatV
			END
		END backgroundRepeat;
		
		PROCEDURE borderColor(term : Term; edge : SHORTINT);
		BEGIN
			IF Equal(term, "transparent") THEN properties.borderColor[edge] := -1;
			ELSIF term.color # noColor THEN properties.borderColor[edge] := term.color
			ELSIF term1.piece # NIL THEN
				Pieces.Convert(term1.piece, colorStr);
				color := HTML4.NamedColor(colorStr);
				IF color >= 0 THEN properties.borderColor[edge] := color END
			ELSIF Equal(term, "inherit") THEN properties.borderColor[edge] := parentP.borderColor[edge]
			END
		END borderColor;
		
		PROCEDURE borderStyle(term : Term; edge : SHORTINT);
		BEGIN
			IF Equal(term, "none") THEN properties.borderStyle[edge] := none 
			ELSIF Equal(term, "hidden") THEN properties.borderStyle[edge] := hidden 
			ELSIF Equal(term, "dotted") THEN properties.borderStyle[edge] := dotted 
			ELSIF Equal(term, "dashed") THEN properties.borderStyle[edge] := dashed 
			ELSIF Equal(term, "solid") THEN properties.borderStyle[edge] := solid
			ELSIF Equal(term, "double") THEN properties.borderStyle[edge] := double 
			ELSIF Equal(term, "groove") THEN
				properties.borderStyle[edge] := solid; properties.borderColor[edge] := GrooveColor
			ELSIF Equal(term, "ridge") THEN
				properties.borderStyle[edge] := solid; properties.borderColor[edge] := RidgeColor
			ELSIF Equal(term, "inset") THEN
				properties.borderStyle[edge] := solid;
				IF (edge = top) OR (edge = left) THEN
					properties.borderColor[edge] := GrooveColor
				ELSE
					properties.borderColor[edge] := RidgeColor
				END;
			ELSIF Equal(term, "outset") THEN
				properties.borderStyle[edge] := solid;
				IF (edge = top) OR (edge = left) THEN
					properties.borderColor[edge] := RidgeColor
				ELSE
					properties.borderColor[edge] := GrooveColor
				END;
			ELSIF Equal(term, "inherit") THEN properties.borderStyle[edge] := parentP.borderStyle[edge]
			END;
		END borderStyle;
		
		PROCEDURE FontSize(term : Term);
		BEGIN
			IF term = NIL THEN RETURN
			ELSIF Equal(term, "x-small") OR Equal(term, "xx-small") THEN
				properties.fontSize := ENTIER(DefFontSize[0] * Unit[px])
			ELSIF Equal(term, "small") THEN properties.fontSize := ENTIER(DefFontSize[1] * Unit[px])
			ELSIF Equal(term, "medium") THEN properties.fontSize := ENTIER(DefFontSize[2] * Unit[px])
			ELSIF Equal(term, "large") THEN properties.fontSize := ENTIER(DefFontSize[3] * Unit[px])
			ELSIF Equal(term, "x-large") THEN properties.fontSize := ENTIER(DefFontSize[4] * Unit[px])
			ELSIF Equal(term, "xx-large") THEN properties.fontSize := ENTIER(DefFontSize[5] * Unit[px])
			ELSIF Equal(term, "larger") THEN properties.fontSize := parentP.fontSize; nextLargerFont
			ELSIF Equal(term, "smaller") THEN properties.fontSize := parentP.fontSize; nextSmallerFont
			ELSIF Equal(term, "inherit") THEN properties.fontSize := parentP.fontSize
			ELSE
				properties.fontSize := CalcWidth(term, parentP.fontSize, parentP.font, parentP.fontSize)
			END;
		END FontSize;
		
		PROCEDURE FontStyle(term : Term);
		BEGIN
			IF Equal(term, "normal") THEN properties.fontStyle := normal
			ELSIF Equal(term, "italic") THEN properties.fontStyle := italic
			ELSIF Equal(term, "oblique") THEN properties.fontStyle := oblique
			ELSIF Equal(term, "inherit") THEN properties.fontStyle := parentP.fontStyle
			END
		END FontStyle;
		
		PROCEDURE FontWeight(term : Term);
		BEGIN
			IF Equal(term, "normal") THEN properties.fontWeight := 4
			ELSIF Equal(term, "bold") THEN properties.fontWeight := 6
			ELSIF Equal(term, "bolder") THEN
				properties.fontWeight := parentP.fontWeight+2;
				IF properties.fontWeight > 9 THEN properties.fontWeight := 9 END
			ELSIF Equal(term, "lighter") THEN
				properties.fontWeight := parentP.fontWeight-2;
				IF properties.fontWeight < 1 THEN properties.fontWeight := 1 END
			ELSIF Equal(term, "inherit") THEN properties.fontWeight := parentP.fontWeight
			ELSIF term.unit = dimless THEN
				IF term.num < 100 THEN properties.fontWeight := 1
				ELSIF term.num > 900 THEN properties.fontWeight := 9
				ELSE properties.fontWeight := SHORT(SHORT(term.num DIV 100))
				END
			END	
		END FontWeight;
		
		PROCEDURE listStyleImage(term : Term);
		BEGIN
			IF Equal(term, "none") THEN properties.listStyleImage := NIL
			ELSIF Equal(term, "inherit") THEN properties.listStyleImage := parentP.listStyleImage
			ELSE properties.listStyleImage := term
			END
		END listStyleImage;
		
		PROCEDURE listStylePosition(term : Term);
		BEGIN
			IF Equal(term, "inside") THEN properties.listStylePositionOutside := FALSE
			ELSIF Equal(term, "outside") THEN properties.listStylePositionOutside := TRUE
			ELSIF Equal(term, "inherit") THEN properties.listStylePositionOutside := parentP.listStylePositionOutside
			END
		END listStylePosition;
		
		PROCEDURE listStyleType(term : Term);
		BEGIN
			IF Equal(term, "none") THEN properties.listStyleType := none
			ELSIF Equal(term, "disc") THEN properties.listStyleType := disc
			ELSIF Equal(term, "square") THEN properties.listStyleType := square
			ELSIF Equal(term, "decimal") THEN properties.listStyleType := decimal
			(* .. *)
			ELSIF Equal(term, "inherit") THEN properties.listStyleType := parentP.listStyleType
			END
		END listStyleType;
		
		PROCEDURE textDecoration(term : Term);
		BEGIN
			IF Equal(term, "underline") THEN INCL(properties.textDecoration, underline)
			ELSIF Equal(term, "overline") THEN INCL(properties.textDecoration, overline)
			ELSIF Equal(term, "line-through") THEN INCL(properties.textDecoration, lineThrough)
			ELSIF Equal(term, "blink") THEN INCL(properties.textDecoration, blink)
			END
		END textDecoration;
		
		
	BEGIN
		hit := hitList;
		WHILE hit # NIL DO
			declaration := hit.declarations;
			WHILE declaration # NIL DO
				term1 := declaration.firstTerm; term2 := term1.next;
				IF term2 # NIL THEN
					term3 := term2.next; IF term3 # NIL THEN
						term4 := term3.next; IF term4 # NIL THEN
							term5 := term4.next ; IF term5 # NIL THEN
								term6 := term5.next 
							END
						END
					END
				END;
				CASE declaration.property[0] OF
				"b" :
					IF declaration.property = "background" THEN
						IF Equal(term1, "inherit") THEN
							properties.backgroundFixed := parentP.backgroundFixed;
							properties.backgroundColor := parentP.backgroundColor;
							properties.backgroundImage := parentP.backgroundImage;
							properties.backgroundPositionV := term1;
							properties.backgroundPositionH := term1;
							properties.backgroundRepeatH := parentP.backgroundRepeatH;
							properties.backgroundRepeatV := parentP.backgroundRepeatV
						ELSE
							backgroundColor(term1);
							IF term2 # NIL THEN backgroundImage(term2);
								IF term3 # NIL THEN backgroundRepeat(term3);
									IF term4 # NIL THEN backgroundAttachment(term4);
										IF term6 # NIL THEN backgroundPosition(term5, term6) END
									END
								END
							END
						END	
					ELSIF declaration.property = "background-attachment" THEN backgroundAttachment(term1)
					ELSIF declaration.property = "background-color" THEN backgroundColor(term1)
					ELSIF declaration.property = "background-image" THEN backgroundImage(term1)
					ELSIF declaration.property = "background-position" THEN backgroundPosition(term1, term2)
					ELSIF declaration.property = "background-repeat" THEN backgroundRepeat(term1)
					
					ELSIF declaration.property = "border" THEN
						IF Equal(term1, "inherit") THEN
							FOR edge := top TO left DO
								properties.borderWidth[edge] := term1; borderStyle(term1, edge); borderColor(term1, edge)
							END
						ELSE
							FOR edge := top TO left DO
								properties.borderWidth[edge] := term1;
								IF term2 # NIL THEN borderStyle(term2, edge);
									IF term3 # NIL THEN borderColor(term3, edge) END
								END
							END
						END
					ELSIF declaration.property = "border-color" THEN
						borderColor(term1, top);
						IF term2 # NIL THEN
							borderColor(term2, right);
							IF term3 # NIL THEN
								borderColor(term3, bottom);
								IF term4 # NIL THEN borderColor(term4, left)
								ELSE borderColor(term2, left)
								END
							ELSE borderColor(term1, bottom); borderColor(term2, left)
							END
						ELSE borderColor(term1, right); borderColor(term1, bottom); borderColor(term1, left)
						END
					ELSIF declaration.property = "border-top-color" THEN borderColor(term1, top)
					ELSIF declaration.property = "border-right-color" THEN borderColor(term1, right)
					ELSIF declaration.property = "border-bottom-color" THEN borderColor(term1, bottom)
					ELSIF declaration.property = "border-left-color" THEN borderColor(term1, left)
					ELSIF declaration.property = "border-top-style" THEN borderStyle(term1, top)
					ELSIF declaration.property = "border-right-style" THEN borderStyle(term1, right)
					ELSIF declaration.property = "border-bottom-style" THEN borderStyle(term1, bottom)
					ELSIF declaration.property = "border-left-style" THEN borderStyle(term1, left)
					ELSIF declaration.property = "border-top-width" THEN properties.borderWidth[top] := term1;
					ELSIF declaration.property = "border-right-width" THEN properties.borderWidth[right] := term1;
					ELSIF declaration.property = "border-bottom-width" THEN properties.borderWidth[bottom] := term1;
					ELSIF declaration.property = "border-left-width" THEN properties.borderWidth[left] := term1 ;
					ELSIF declaration.property = "border-style" THEN
						borderStyle(term1, top);
						IF term2 # NIL THEN
							borderStyle(term2, right);
							IF term3 # NIL THEN
								borderStyle(term3, bottom);
								IF term4 # NIL THEN borderStyle(term4, left);
								ELSE borderStyle(term2, left);
								END
							ELSE borderStyle(term1, bottom); borderStyle(term1, left);
							END
						ELSE borderStyle(term1, right); borderStyle(term1, bottom);borderStyle(term1, left)
						END
					ELSIF declaration.property = "border-width" THEN
						properties.borderWidth[top] := term1;
						IF term2 # NIL THEN
							properties.borderWidth[right] := term2;
							IF term3 # NIL THEN
								properties.borderWidth[bottom] := term3;
								IF term4 # NIL THEN properties.borderWidth[left] := term4
								ELSE properties.borderWidth[left] := term2
								END
							ELSE properties.borderWidth[bottom] := term1; properties.borderWidth[left] := term2
							END
						ELSE
							properties.borderWidth[right] := term1;
							properties.borderWidth[bottom] := term1;
							properties.borderWidth[left] := term1
						END
					ELSIF declaration.property = "border-spacing" THEN
						properties.borderSpacing[0] := term1;
						IF term2 # NIL THEN properties.borderSpacing[1] := term2
						ELSE properties.borderSpacing[1] := term1
						END;
					ELSIF declaration.property = "bottom" THEN properties.bottom := term1
					END
			| "c" :
					IF declaration.property = "caption-side" THEN
						IF Equal(term1, "left") THEN properties.captionSide := left
						ELSIF Equal(term1, "right") THEN properties.captionSide := right
						ELSIF Equal(term1, "top") THEN properties.captionSide := top
						ELSIF Equal(term1, "bottom") THEN properties.captionSide := bottom
						ELSIF Equal(term1, "inherit") THEN properties.captionSide := parentP.captionSide
						END
					ELSIF declaration.property = "clear" THEN
						IF Equal(term1, "left") THEN properties.clearLeft := TRUE; properties.clearRight := FALSE
						ELSIF Equal(term1, "right") THEN properties.clearLeft := FALSE; properties.clearRight := TRUE
						ELSIF Equal(term1, "both") THEN properties.clearLeft := TRUE; properties.clearRight := TRUE
						ELSIF Equal(term1, "none") THEN properties.clearLeft := FALSE; properties.clearRight := FALSE
						ELSIF Equal(term1, "inherit") THEN
							properties.clearLeft := parentP.clearLeft; properties.clearRight := parentP.clearRight
						END
					ELSIF declaration.property = "clip" THEN
						IF Is(piece, term1) THEN properties.clip := term1.piece
						ELSIF Equal(term1, "inherit") THEN properties.clip := parentP.clip
						END
					ELSIF declaration.property = "color" THEN
						IF term1.color # noColor THEN properties.color := term1.color
						ELSIF term1.piece # NIL THEN
							Pieces.Convert(term1.piece, colorStr);
							color := HTML4.NamedColor(colorStr);
							IF color >= 0 THEN properties.color := color END
						ELSIF Equal(term1, "inherit") THEN properties.color := parentP.color
						END
					END
		| "d" :
					IF declaration.property = "directory" THEN
						IF Equal(term1, "ltr") THEN properties.directionLTR := TRUE
						ELSIF Equal(term1, "rtl") THEN properties.directionLTR := FALSE
						ELSIF Equal(term1, "inherit") THEN properties.directionLTR := parentP.directionLTR
						END
					ELSIF declaration.property = "display" THEN
						IF Equal(term1, "inline") THEN properties.display := inline
						ELSIF Equal(term1, "block") THEN properties.display := block
						ELSIF Equal(term1, "list-item") THEN properties.display := listItem
						ELSIF Equal(term1, "run-in") THEN properties.display := runIn
						ELSIF Equal(term1, "compact") THEN properties.display := compact
						ELSIF Equal(term1, "marker") THEN properties.display := marker
						ELSIF Equal(term1, "table") THEN properties.display := table
						ELSIF Equal(term1, "inline-table") THEN properties.display := inlineTable
						ELSIF Equal(term1, "table-row-group") THEN properties.display := tableRowGroup
						ELSIF Equal(term1, "table-header-group") THEN properties.display := tableHeaderGroup
						ELSIF Equal(term1, "table-footer-group") THEN properties.display := tableFooterGroup
						ELSIF Equal(term1, "table-row") THEN properties.display := tableRow
						ELSIF Equal(term1, "table-column-group") THEN properties.display := tableColumnGroup
						ELSIF Equal(term1, "table-column") THEN properties.display := tableColumn
						ELSIF Equal(term1, "table-cell") THEN properties.display := tableCell
						ELSIF Equal(term1, "table-caption") THEN properties.display := tableCaption
						ELSIF Equal(term1, "none") THEN properties.display := none
						ELSIF Equal(term1, "inherit") THEN properties.display := parentP.display
						END
					END
		| "e" :
					IF declaration.property = "empty-cells" THEN
						IF Equal(term1, "show") THEN properties.emptyCellsShow := TRUE
						ELSIF Equal(term1, "hide") THEN properties.emptyCellsShow := FALSE
						ELSIF Equal(term1, "inherit") THEN properties.emptyCellsShow := parentP.emptyCellsShow
						END
					END
		| "f" :
					IF declaration.property = "float" THEN
						IF Equal(term1, "left") THEN properties.floatLeft := TRUE; properties.floatRight := FALSE
						ELSIF Equal(term1, "right") THEN properties.floatLeft := FALSE; properties.floatRight := TRUE
						ELSIF Equal(term1, "none") THEN properties.floatLeft := FALSE; properties.floatRight := FALSE
						ELSIF Equal(term1, "inherit") THEN properties.floatLeft := parentP.floatLeft; properties.floatRight := parentP.floatRight
						END
					ELSIF declaration.property = "font-size" THEN FontSize(term1)
					ELSIF declaration.property = "font-style" THEN FontStyle(term1)
					ELSIF declaration.property = "font-weight" THEN FontWeight(term1)
					END
		| "h" :
					IF declaration.property = "height" THEN properties.height := term1 END
		| "l" :
					IF declaration.property = "left" THEN properties.left := term1
					ELSIF declaration.property = "letter-spacing" THEN properties.letterSpacing := term1
					ELSIF declaration.property = "line-height" THEN properties.lineHeightTerm := term1
					ELSIF declaration.property = "list-style" THEN
						listStyleType(term1);
						IF Equal(term1, "inherit") THEN
							listStylePosition(term1); listStyleImage(term1)
						ELSIF term2 # NIL THEN listStylePosition(term2);
							IF term3 # NIL THEN listStyleImage(term3) END
						END
					ELSIF declaration.property = "list-style-image" THEN listStyleImage(term1)
					ELSIF declaration.property = "list-style-position" THEN listStylePosition(term1)
					ELSIF declaration.property = "list-style-type" THEN listStyleType(term1)
					END	
		| "m" :
					IF declaration.property = "margin" THEN
						properties.margin[top] := term1;
						IF term2 # NIL THEN
							properties.margin[right] := term2;
							IF term3 # NIL THEN
								properties.margin[bottom] := term3;
								IF term4 # NIL THEN properties.margin[left] := term4
								ELSE properties.margin[left] := term2
								END
							ELSE properties.margin[bottom] := term1; properties.margin[left] := term2
							END
						ELSE
							properties.margin[right] := term1;
							properties.margin[bottom] := term1;
							properties.margin[left] := term1
						END
					ELSIF declaration.property = "margin-top" THEN properties.margin[top] := term1
					ELSIF declaration.property = "margin-right" THEN properties.margin[right] := term1
					ELSIF declaration.property = "margin-bottom" THEN properties.margin[bottom] := term1
					ELSIF declaration.property = "margin-left" THEN properties.margin[left] := term1
					
					ELSIF declaration.property = "marker-offset" THEN properties.markerOffset := term1

					ELSIF declaration.property = "max-height" THEN properties.maxHeight := term1
					ELSIF declaration.property = "max-width" THEN properties.maxWidth := term1
					ELSIF declaration.property = "min-height" THEN properties.minHeight := term1
					ELSIF declaration.property = "min-width" THEN properties.minWidth := term1
					END	
		| "o" :
					IF declaration.property = "overflow" THEN
						IF Equal(term1, "visible") THEN properties.overflow := visible
						ELSIF Equal(term1, "hidden") THEN properties.overflow := hidden
						ELSIF Equal(term1, "scroll") THEN properties.overflow := scroll
						ELSIF Equal(term1, "auto") THEN properties.overflow := auto
						ELSIF Equal(term1, "inherit") THEN properties.overflow := parentP.overflow
						END
					END
		| "p" :
					IF declaration.property = "padding" THEN
						properties.padding[top] := term1;
						IF term2 # NIL THEN
							properties.padding[right] := term2;
							IF term3 # NIL THEN
								properties.padding[bottom] := term3;
								IF term4 # NIL THEN properties.padding[left] := term4
								ELSE properties.padding[left] := term2
								END
							ELSE properties.padding[bottom] := term1; properties.padding[left] := term2
							END
						ELSE
							properties.padding[right] := term1;
							properties.padding[bottom] := term1;
							properties.padding[left] := term1
						END
					ELSIF declaration.property = "padding-top" THEN properties.padding[top] := term1
					ELSIF declaration.property = "padding-right" THEN properties.padding[right] := term1
					ELSIF declaration.property = "padding-bottom" THEN properties.padding[bottom] := term1
					ELSIF declaration.property = "padding-left" THEN properties.padding[left] := term1
					
					ELSIF declaration.property = "position" THEN
						IF Equal(term1, "static") THEN properties.position := static
						ELSIF Equal(term1, "relative") THEN properties.position := relative
						ELSIF Equal(term1, "absolute") THEN properties.position := absolute
						ELSIF Equal(term1, "fixed") THEN properties.position := fixed
						ELSIF Equal(term1, "inherit") THEN properties.position := parentP.position
						END
					END
		| "q" :
				IF declaration.property = "quotes" THEN
					(* .. *)
				END;
		| "r" :
				IF declaration.property = "right" THEN properties.right := term1 END
		| "t" :
				IF declaration.property = "table-layout" THEN
					IF Equal(term1, "fixed") THEN properties.tableLayoutFixed := TRUE
						ELSIF Equal(term1, "auto") THEN properties.tableLayoutFixed := FALSE
						ELSIF Equal(term1, "inherit") THEN properties.tableLayoutFixed := parentP.tableLayoutFixed
					END
				ELSIF declaration.property = "text-align" THEN properties.textAlign := term1
				ELSIF declaration.property = "text-decoration" THEN 
					IF Equal(term1, "inherit") THEN properties.textDecoration := parentP.textDecoration
					ELSIF Equal(term1, "none") THEN properties.textDecoration := {}
					ELSE
						properties.textDecoration := {};
						textDecoration(term1);
						IF term2 # NIL THEN textDecoration(term2) END;
						IF term3 # NIL THEN textDecoration(term3) END;
						IF term4 # NIL THEN textDecoration(term4) END;
					END
				ELSIF declaration.property = "text-indent" THEN properties.textAlign := term1
				ELSIF declaration.property = "text-shadow" THEN 
					(* .. *)
				ELSIF declaration.property = "text-transform" THEN 
					(* .. *)
				ELSIF declaration.property = "top" THEN properties.top := term1
				END
		| "v" :
				IF declaration.property = "vertical-align" THEN properties.verticalAlignTerm := term1
				ELSIF declaration.property = "visibility" THEN 
					IF Equal(term1, "visible") THEN properties.visibility := visible
					ELSIF Equal(term1, "hidden") THEN properties.visibility := hidden
					ELSIF Equal(term1, "collapse") THEN properties.visibility := collapse
					ELSIF Equal(term1, "inherit") THEN properties.visibility := parentP.visibility
					END
				END
		| "w" :
				IF declaration.property = "white-space" THEN
					IF Equal(term1, "pre") THEN properties.whiteSpacePre := TRUE
					ELSIF Equal(term1, "normal") OR Equal(term1, "nowrap") THEN properties.whiteSpacePre := FALSE
					ELSIF Equal(term1, "inherit") THEN properties.whiteSpacePre := parentP.whiteSpacePre
					END
				ELSIF declaration.property = "width" THEN  properties.width := term1
				ELSIF declaration.property = "word-spacing" THEN  properties.width := term1
				END
		| "z" :
				IF declaration.property = "z-index" THEN
					IF Equal(term1, "auto") THEN properties.zIndex := -1
					ELSIF Equal(term1, "inherit") THEN properties.zIndex := parentP.zIndex
					ELSIF term1.unit = dimless THEN properties.zIndex := term1.num
					END
				END
				ELSE (* ignore *)
				END; (* case *)
				declaration := declaration.next
			END; (* while *)
			hit := hit.nextBetter
		END; (* while *)
	
	END PlayHitList;
	
	(*PROCEDURE CalcLineHeight;
	BEGIN
		IF (properties.lineHeightTerm = NIL) OR Equal(properties.lineHeightTerm, "normal") THEN
			properties.lineHeight := properties.font.height
		ELSIF properties.lineHeightTerm.unit = dimless THEN
			properties.lineHeight := ENTIER(properties.font.height * properties.lineHeightTerm.realNum)
		ELSE
			properties.lineHeight := CalcWidth(properties.lineHeightTerm, properties.font.height,
																	properties.font, parentP.lineHeight)
		END
	END CalcLineHeight;*)
	
	(*PROCEDURE CalcVerticalAlign;
	BEGIN
		properties.verticalAlignType := {normal}; properties.verticalAlign := 0;
		IF (properties.verticalAlignTerm = NIL) OR Equal(properties.verticalAlignTerm, "baseline") THEN
		ELSIF Equal(properties.verticalAlignTerm, "sub") THEN
			properties.verticalAlignType := parentP.verticalAlignType; 
			properties.verticalAlign := parentP.verticalAlign - properties.font.height DIV 3
		ELSIF Equal(properties.verticalAlignTerm, "super") THEN
			properties.verticalAlignType := parentP.verticalAlignType; 
			properties.verticalAlign := parentP.verticalAlign + properties.font.height DIV 3
		ELSIF Equal(properties.verticalAlignTerm, "text-top") THEN
			properties.verticalAlignType := parentP.verticalAlignType;
			properties.verticalAlign := parentP.verticalAlign + parentP.font.height - properties.font.height
		ELSIF Equal(properties.verticalAlignTerm, "text-bottom") OR Equal(properties.verticalAlignTerm, "inherit") THEN
			properties.verticalAlignType := parentP.verticalAlignType;
			properties.verticalAlign := parentP.verticalAlign 
		ELSIF Equal(properties.verticalAlignTerm, "top") THEN
			properties.verticalAlignType := {top}
		ELSIF Equal(properties.verticalAlignTerm, "middle") THEN
			properties.verticalAlignType := {middle}
		ELSIF Equal(properties.verticalAlignTerm, "bottom") THEN
			properties.verticalAlignType := {bottom}
		ELSE
			properties.verticalAlign := CalcWidth(properties.verticalAlignTerm, properties.lineHeight,
																		properties.font, parentP.verticalAlign)
		END
	END CalcVerticalAlign;*)
	
	(*PROCEDURE CheckBorderWidth;
	VAR edge : SHORTINT;
	BEGIN
		FOR edge := top TO left DO
			IF properties.borderStyle[edge] = none THEN
				properties.borderWidth[edge] := term0
			END
		END
	END CheckBorderWidth;*)
		

BEGIN
	properties := defaultProperties;
	InheritProperties(properties, parentP);

	hitList := NIL;
	IF element # NIL THEN
		hitList := JeanLucWicki(element, stylesheet); (* makes Hitlist *)
		
		(* Add the declarations from the attributes and from the style attribute .. 
		NEW(hit); hit.declarations := element.style;
		IF hitList # NIL THEN
			bestHit := hitList; WHILE bestHit.nextBetter # NIL DO bestHit := bestHit.nextBetter END;
			bestHit.nextBetter := hit
		ELSE hitList := hit
		END *)
	END;

	PlayHitList;
	
	IF element.type.name = "FONT" THEN
		size := HTML4.ThisAttribute(element, "size");
		IF size # NIL THEN
			Pieces.Convert(size, sizeStr);
			IF (sizeStr[0] >= "1") & (sizeStr[0] <= "7") THEN
				properties.fontSize := ENTIER(DefFontSize[ORD(sizeStr[0])-ORD("1")] * Unit[px]);
			ELSIF (sizeStr[1] >= "1") & (sizeStr[1] <= "7") THEN
				IF sizeStr[0] = "+" THEN
					FOR j := 0 TO ORD(sizeStr[1])-ORD("1") DO
						nextLargerFont
					END
				ELSIF sizeStr[0] = "-" THEN
					FOR j := 0 TO ORD(sizeStr[1])-ORD("1") DO
						nextSmallerFont
					END
				END
			END
		END;
		color := HTML4.Color(HTML4.ThisAttribute(element, "color"));
		IF color >= 0 THEN
			properties.color := color
		END
	END;
			
	CheckValues(properties, parentP)
END AssignValues ;

PROCEDURE CheckValues*(VAR properties : Properties; VAR parentP : Properties);

	PROCEDURE FindFont;
	VAR
		fontName : ARRAY 20 OF CHAR;
		size : ARRAY 8 OF CHAR ;
	BEGIN
		fontName := "Default" ;
		Strings.IntToStr(ENTIER(properties.fontSize / Unit[px]), size) ;
		Strings.Append(fontName, size) ;
		IF properties.fontWeight >= 5 THEN Strings.Append(fontName, "b") END;
		IF properties.fontStyle = italic THEN Strings.Append(fontName, "i") END;
		Strings.Append(fontName, ".Scn.Fnt") ;
		properties.font := Fonts.This(fontName)
	END FindFont;
	
	PROCEDURE CalcLineHeight;
	BEGIN
		IF (properties.lineHeightTerm = NIL) OR Equal(properties.lineHeightTerm, "normal") THEN
			properties.lineHeight := properties.font.height
		ELSIF properties.lineHeightTerm.unit = dimless THEN
			properties.lineHeight := ENTIER(properties.font.height * properties.lineHeightTerm.realNum)
		ELSE
			properties.lineHeight := CalcWidth(properties.lineHeightTerm, properties.font.height,
																	properties.font, parentP.lineHeight)
		END
	END CalcLineHeight;
	
	PROCEDURE CalcVerticalAlign;
	BEGIN
		properties.verticalAlignType := {normal}; properties.verticalAlign := 0;
		IF (properties.verticalAlignTerm = NIL) OR Equal(properties.verticalAlignTerm, "baseline") THEN
		ELSIF Equal(properties.verticalAlignTerm, "sub") THEN
			properties.verticalAlignType := parentP.verticalAlignType; 
			properties.verticalAlign := parentP.verticalAlign - properties.font.height DIV 3
		ELSIF Equal(properties.verticalAlignTerm, "super") THEN
			properties.verticalAlignType := parentP.verticalAlignType; 
			properties.verticalAlign := parentP.verticalAlign + properties.font.height DIV 3
		ELSIF Equal(properties.verticalAlignTerm, "text-top") THEN
			properties.verticalAlignType := parentP.verticalAlignType;
			properties.verticalAlign := parentP.verticalAlign + parentP.font.height - properties.font.height
		ELSIF Equal(properties.verticalAlignTerm, "text-bottom") OR Equal(properties.verticalAlignTerm, "inherit") THEN
			properties.verticalAlignType := parentP.verticalAlignType;
			properties.verticalAlign := parentP.verticalAlign 
		ELSIF Equal(properties.verticalAlignTerm, "top") THEN
			properties.verticalAlignType := {top}
		ELSIF Equal(properties.verticalAlignTerm, "middle") THEN
			properties.verticalAlignType := {middle}
		ELSIF Equal(properties.verticalAlignTerm, "bottom") THEN
			properties.verticalAlignType := {bottom}
		ELSE
			properties.verticalAlign := CalcWidth(properties.verticalAlignTerm, properties.lineHeight,
																		properties.font, parentP.verticalAlign)
		END
	END CalcVerticalAlign;
	
	PROCEDURE CheckBorderWidth;
	VAR edge : SHORTINT;
	BEGIN
		FOR edge := top TO left DO
			IF properties.borderStyle[edge] = none THEN
				properties.borderWidth[edge] := term0
			END
		END
	END CheckBorderWidth;

BEGIN
	FindFont; (* Sucht den passenden Font *)
	CalcLineHeight; (* VerticalAlign muss hier berechnet werden, um eine spƒtere Verschachtelung der *)
	CalcVerticalAlign; (*  Inline-Elemente umgehen zu k„nnen. Dazu braucht man auch die Linien-H„he *)
	CheckBorderWidth; (* If border-style is none then border-width is 0 *)
END CheckValues;


PROCEDURE InitDefaultProperties;
BEGIN
	defaultProperties.top := termAuto; defaultProperties.bottom := termAuto;
	defaultProperties.left := termAuto; defaultProperties.right := termAuto;
	defaultProperties.width := termAuto; defaultProperties.height := termAuto;
	defaultProperties.backgroundFixed := FALSE;
	defaultProperties.backgroundColor := -1;
	defaultProperties.backgroundImage := NIL;
	defaultProperties.backgroundPositionH := term0Percent; defaultProperties.backgroundPositionV := term0Percent;
	defaultProperties.backgroundRepeatH := TRUE; defaultProperties.backgroundRepeatV := TRUE; 
	defaultProperties.borderCollapse := FALSE;
	defaultProperties.borderColor[top] := 0; defaultProperties.borderColor[bottom] := 0; 
	defaultProperties.borderColor[left] := 0; defaultProperties.borderColor[right] := 0;
	defaultProperties.borderWidth[top] := term2px; defaultProperties.borderWidth[bottom] := term2px; 
	defaultProperties.borderWidth[left] := term2px; defaultProperties.borderWidth[right] := term2px;
	defaultProperties.borderStyle[top] := none; defaultProperties.borderStyle[bottom] := none; 
	defaultProperties.borderStyle[left] := none; defaultProperties.borderStyle[right] := none;
	defaultProperties.captionSide := bottom;
	defaultProperties.clearLeft := FALSE; defaultProperties.clearRight := FALSE; 
	defaultProperties.clip := NIL;
	defaultProperties.color:= 0*256*256 + 0*256 + 0;
	defaultProperties.content := NIL;
	defaultProperties.directionLTR := TRUE;
	defaultProperties.display := inline;
	defaultProperties.emptyCellsShow := TRUE;
	defaultProperties.floatLeft := FALSE; defaultProperties.floatRight := FALSE; 
	defaultProperties.fontFamily := NIL;
	defaultProperties.fontSize := ENTIER(DefFontSize[2] * Unit[px]);
	defaultProperties.fontStyle := normal;
	defaultProperties.fontWeight := 4; (* = 400 *)
	defaultProperties.letterSpacing := NIL;
	defaultProperties.lineHeightTerm := NIL;
	defaultProperties.listStyleImage := NIL;
	defaultProperties.listStylePositionOutside := TRUE;
	defaultProperties.listStyleType := disc;
	defaultProperties.margin[top] := term0Percent; defaultProperties.margin[bottom] := term0Percent; 
	defaultProperties.margin[left] := term0Percent; defaultProperties.margin[right] := term0Percent;
	defaultProperties.markerOffset := NIL;
	defaultProperties.maxHeight := NIL; defaultProperties.maxWidth := NIL; 
	defaultProperties.minHeight := NIL; defaultProperties.minWidth := NIL; 
	defaultProperties.overflow := visible;
	defaultProperties.padding[top] := term0Percent; defaultProperties.padding[bottom] := term0Percent; 
	defaultProperties.padding[left] := term0Percent; defaultProperties.padding[right] := term0Percent;
	defaultProperties.position := static;
	defaultProperties.quotes[0] := '"' ; defaultProperties.quotes[1] := '"' ; 
	defaultProperties.tableLayoutFixed := FALSE;
	defaultProperties.textAlign := termLeft;
	defaultProperties.textDecoration := {};
	defaultProperties.textDecorationColor := 0*256*256 + 0*256 + 0;
	defaultProperties.textIndent := term0Percent;
	defaultProperties.textShadow := NIL;
	defaultProperties.textTransform := {};
	defaultProperties.verticalAlignTerm := NIL;
	defaultProperties.visibility := visible;
	defaultProperties.whiteSpacePre := FALSE;
	defaultProperties.wordSpacing := NIL;
	defaultProperties.zIndex := -1;
END InitDefaultProperties;

PROCEDURE InitUnits;
VAR i : SHORTINT;

BEGIN
	devicePixelSize := 914400 DIV 75;

	Unit[px] := 914400 DIV 75;	(* -> 1 pixel on screen, 4 on a printer (300 DPI) *)
	Unit[mm] := 36000;
	Unit[cm] := 10 * 36000;
	Unit[in] := 914400;
	Unit[pt] := 914400 DIV 72;
	Unit[pc] := 914400 DIV 72 * 12;
	
	FOR i := px TO pc DO Unit[i] := Unit[i] / devicePixelSize END;
END InitUnits;

PROCEDURE NewTerm*(num : LONGINT; realNum : REAL; unit : SHORTINT) : Term;
VAR term : Term;
BEGIN
	NEW(term);
	term.num := num; term.realNum := realNum; term.unit := unit;
	RETURN term
END NewTerm;


BEGIN
	InitUnits;
	term0Percent := NewTerm(0, 0.0, percent);
	term50Percent := NewTerm(50, 50.0, percent);
	term100Percent := NewTerm(100, 100.0, percent);
	term2px := NewTerm(2, 2.0, px);
	term0 := NewTerm(0, 0.0, dimless);
	
	autoStr := "auto"; Pieces.ConvertToPiece(autoPiece, autoStr); 
	NEW(termAuto); termAuto.unit := piece; termAuto.piece := autoPiece;
	
	leftStr := "left"; Pieces.ConvertToPiece(leftPiece, leftStr); 
	NEW(termLeft); termLeft.unit := piece; termLeft.piece := leftPiece;
	
	DefFontSize[0] := 8; DefFontSize[1] := 8; 
	DefFontSize[1] := 10;
	DefFontSize[2] := 12;
	DefFontSize[3] := 14;
	DefFontSize[4] := 16;
	DefFontSize[5] := 20;
	DefFontSize[6] := 24;

	InitDefaultProperties;
END WebCSS2.