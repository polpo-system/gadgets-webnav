MODULE WebSGMLScanner;  

IMPORT Oberon, Texts;  

CONST 
	debug = FALSE;  

CONST 
	IdLen = 32;  KW = 2;  maxentitylen = 32;  
	
	(* symbols *)
	null = 0;  element* = 1;  attlist* = 2;  ident* = 3;  unknownKeyWord = 4;  eof* = 10;  and* = 11;  or* = 12;  
	times* = 13;  plus* = 13;  minus* = 14;  lparen* = 15;  rparen* = 16;  question* = 17;  comma* = 18;  
	gt* = 19;  

TYPE 
	Ident* = ARRAY IdLen OF CHAR;  
	
	Entity = POINTER TO EntityDesc;  
	EntityDesc = RECORD;  
			next: Entity;  
			name: ARRAY maxentitylen + 1 OF CHAR;  
			pos, endpos: LONGINT;  
	END;  
	
	TextStackElement = POINTER TO TextStackElementDesc;  
	TextStackElementDesc = RECORD 
			parent: TextStackElement;  
			saved: LONGINT;  
			endpos: LONGINT;  
	END;  

VAR 
	val*: LONGINT;  id*: Ident;  error*: BOOLEAN;  preSpace*: BOOLEAN;  

	ch: CHAR;  nkw: INTEGER;  T: Texts.Text;  R: Texts.Reader;  W: Texts.Writer;  
	keyTab: ARRAY KW OF RECORD 
			sym: INTEGER;  
			id: ARRAY 12 OF CHAR
	END;  
	errpos: LONGINT;  

	Entities: Entity;  TextStack: TextStackElement;  

	PROCEDURE Mark*( msg: ARRAY OF CHAR );  
	VAR p: LONGINT;  
	BEGIN 
		IF debug THEN 
			p := Texts.Pos( R ) - 1;  
			IF p > errpos THEN 
				Texts.WriteString( W, " pos " );  Texts.WriteInt( W, p, 1 );  Texts.Write( W, " " );  
				Texts.WriteString( W, msg );  Texts.WriteLn( W );  Texts.Append( Oberon.Log, W.buf )
			END;  
			errpos := p;  error := TRUE
		END 
	END Mark;  

	PROCEDURE VerySimpleNextChar;  
	BEGIN 
		Texts.Read( R, ch );  
		WHILE (TextStack # NIL ) & (Texts.Pos( R ) >= TextStack.endpos) DO 
			Texts.OpenReader( R, T, TextStack.saved );  TextStack := TextStack.parent
		END 
	END VerySimpleNextChar;  

	PROCEDURE SimpleNextChar;  			(* Doesn't replace at % , but skips comments *)
	VAR oldPos: LONGINT;  hyphen: BOOLEAN;  
	BEGIN 
		VerySimpleNextChar;  
		LOOP 
			IF ch # "-" THEN EXIT END;  
			oldPos := Texts.Pos( R );  Texts.Read( R, ch );  
			IF ch = "-" THEN 
				WHILE (TextStack # NIL ) & (Texts.Pos( R ) >= TextStack.endpos) DO 
					Texts.OpenReader( R, T, TextStack.saved );  TextStack := TextStack.parent
				END;  
				
				VerySimpleNextChar;  hyphen := FALSE;  
				LOOP 
					IF R.eot THEN Mark( "comment not terminated" );  EXIT END;  
					IF ch = "-" THEN 
						IF hyphen THEN EXIT ELSE hyphen := TRUE END;  
					ELSE hyphen := FALSE
					END;  
					VerySimpleNextChar;  
				END;   (* LOOP *)
				VerySimpleNextChar;  
			ELSE Texts.OpenReader( R, T, oldPos );  ch := "-";  EXIT 
			END 
		END 
	END SimpleNextChar;  

	PROCEDURE NextChar;  
	VAR name: Ident;  entity: Entity;  i: INTEGER;  textStackElement: TextStackElement;  
	BEGIN 
		SimpleNextChar;  
		IF ch = "%" THEN 
			i := 0;  SimpleNextChar;  
			WHILE ((CAP( ch ) >= "A") & (CAP( ch ) <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = ".")) & ~R.eot DO 
				name[i] := ch;  INC( i );  NextChar
			END;  
			name[i] := 0X;  entity := Entities;  
			WHILE (entity # NIL ) & (entity.name # name) DO entity := entity.next END;  
			IF entity = NIL THEN Mark( "unknown entity" ) 
			ELSE 
				NEW( textStackElement );  textStackElement.saved := Texts.Pos( R );  
				textStackElement.endpos := entity.endpos;  Texts.OpenReader( R, T, entity.pos );  

				textStackElement.parent := TextStack;  TextStack := textStackElement;  

				NextChar
			END 
		END 
	END NextChar;  

	PROCEDURE SkipSpaces;  
	BEGIN 
		WHILE ch <= " " DO NextChar END;  
	END SkipSpaces;  

	PROCEDURE ReadEntity;  
	VAR entity: Entity;  i: INTEGER;  
	BEGIN 
		WHILE ch <= " " DO SimpleNextChar END;  
		IF ch # "%" THEN Mark( "% ?" ) ELSE SimpleNextChar END;  
		SkipSpaces;  

		NEW( entity );  i := 0;  
		WHILE ((CAP( ch ) >= "A") & (CAP( ch ) <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = ".")) & ~R.eot DO 
			entity.name[i] := ch;  INC( i );  NextChar
		END;  
		entity.name[i] := 0X;  

		SkipSpaces;  
		
		IF ch = '"' THEN 
			entity.pos := Texts.Pos( R );  NextChar;  
			WHILE (ch # '"') & ~R.eot DO NextChar END;  
			entity.endpos := Texts.Pos( R ) - 1;  NextChar
		ELSE 
			entity.pos := Texts.Pos( R ) - 1;  
			WHILE (ch > " ") & ~R.eot DO NextChar END;  
			entity.endpos := Texts.Pos( R ) - 1;  
		END;  
		
		WHILE (ch # ">") & ~R.eot DO NextChar
		END;  
		NextChar;  

		entity.next := Entities;  Entities := entity
	END ReadEntity;  

	PROCEDURE Get*( VAR sym: INTEGER );  

		PROCEDURE KeyWord;  
		VAR i, k: INTEGER;  end: BOOLEAN;  
		BEGIN 
			i := 0;  end := FALSE;  
			REPEAT 
				ch := CAP( ch );  
				IF (i < IdLen) & (ch >= "A") & (ch <= "Z") THEN id[i] := ch;  INC( i );  NextChar ELSE end := TRUE END;  
			UNTIL end;  
			id[i] := 0X;  
			IF id = "ENTITY" THEN ReadEntity;  sym := null 
			ELSE 
				k := 0;  
				WHILE (k < nkw) & (id # keyTab[k].id) DO INC( k ) END;  
				IF k < nkw THEN sym := keyTab[k].sym ELSE sym := unknownKeyWord END 
			END 
		END KeyWord;  

		PROCEDURE Ident;  
		VAR end: BOOLEAN;  i: INTEGER;  
		BEGIN 
			i := 0;  end := FALSE;  
			REPEAT 
				IF (ch >= "a") & (ch <= "z") THEN ch := CAP( ch ) END;  
				IF (i < IdLen) & ((ch >= "A") & (ch <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = "#") OR (ch = "-")) THEN 
					id[i] := ch;  INC( i );  NextChar
				ELSE end := TRUE
				END;  
			UNTIL end;  
			IF (i < IdLen) THEN id[i] := 0X ELSE id[IdLen - 1] := 0X END 
		END Ident;  

	BEGIN 
		sym := null;  
		WHILE sym = null DO 
			preSpace := FALSE;  
			WHILE ~R.eot & (ch <= " ") DO NextChar;  preSpace := TRUE END;  
			IF R.eot THEN sym := eof
			ELSIF ch = "<" THEN 
				NextChar;  
				IF ch = "!" THEN NextChar;  KeyWord 
				ELSE 
					Mark( "< without !" );  
					REPEAT NextChar UNTIL ch = ">";  
					NextChar
				END;  
			ELSIF ch = "&" THEN sym := and;  NextChar
			ELSIF ch = "|" THEN sym := or;  NextChar
			ELSIF ch = "+" THEN sym := plus;  NextChar
			ELSIF ch = "-" THEN sym := minus;  NextChar
			ELSIF ch = "*" THEN sym := times;  NextChar
			ELSIF ch = "?" THEN sym := question;  NextChar
			ELSIF ch = "(" THEN sym := lparen;  NextChar
			ELSIF ch = ")" THEN sym := rparen;  NextChar
			ELSIF ch = "," THEN sym := comma;  NextChar
			ELSIF ch = ">" THEN sym := gt;  NextChar
			ELSIF ((ch >= "a") & (ch <= "z") OR (ch >= "A") & (ch <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = "#")) THEN 
				sym := ident;  Ident;  
			ELSE Mark( "Unknown Char" );  NextChar;  
			END 
		END;  
	END Get;  

	PROCEDURE Init*( Text: Texts.Text;  pos: LONGINT );  
	BEGIN 
		error := FALSE;  errpos := pos;  Texts.OpenReader( R, Text, pos );  Texts.Read( R, ch );  T := Text;  
	END Init;  

	PROCEDURE EnterKW( sym: INTEGER;  name: ARRAY OF CHAR );  
	BEGIN 
		keyTab[nkw].sym := sym;  COPY( name, keyTab[nkw].id );  INC( nkw )
	END EnterKW;  

BEGIN 
	Texts.OpenWriter( W );  error := TRUE;  nkw := 0;  
	EnterKW( element, "ELEMENT" );  
	EnterKW( attlist, "ATTLIST" );  
END WebSGMLScanner.		
	


