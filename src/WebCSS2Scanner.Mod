MODULE WebCSS2Scanner ;

IMPORT Files;

CONST
	IdLen = 32 ;
	
(* symbols *)
	null = 0 ;
	eof* = 10 ;
	lparen* = 11 ; rparen*=12 ;lbrak*=13 ; rbrak*=13; lbrace*=14 ; rbrace*=15;
	ident*=20; number*=21 ; realNumber*=22; at* = 23; hash* = 24;
	semicolon* = 30; asterix* = 31; comma* = 32; equal* = 33; colon* =34; percent* = 35; slash* = 36; plus* = 37; greater* = 38; point* = 39;
	color* = 40;
		
	(*LF = CHR(10) ; FF = CHR(12) ; CR = CHR(13) ;*)
		
TYPE
	Ident* = ARRAY IdLen OF CHAR ;

VAR
	realVal* : REAL;
	val* : LONGINT;
	id* : Ident ;
	
	file* : Files.File;
	pStart*, pEnd* : LONGINT;

	ch : CHAR ; 
	high : BOOLEAN ; (* is unicode of ch higher than 255? *)
	(*unicode : LONGINT ;*)
	R : Files.Rider  ;
	eofSent : BOOLEAN ;
	
	rgbStr : ARRAY 4 OF CHAR;


PROCEDURE NextChar ;
VAR
	valid : BOOLEAN ;
	(*d : INTEGER ;*)

BEGIN
	valid := FALSE ;
	REPEAT
		Files.Read(R,ch) ;
		
		(*
		IF ch = "\" THEN
			Files.Read(R,ch) ; 
			IF ch = LF THEN
				Files.Read(R,ch) ; valid := FALSE
			 ELSIF ch = CR THEN
				Files.Read(R,ch) ;
				IF ch = LF THEN Files.Read(R,ch) END ;
				valid := FALSE
			 ELSIF ch = FF THEN
				Files.Read(R,ch) ; valid := FALSE
			 ELSIF (ch >= "0") & (ch <="9") OR (CAP(ch) >= "A") & (CAP(ch) <="F") THEN
				d := 0 ; unicode := 0 ;
				WHILE (d < 6) DO
					IF (ch >= "a") & (ch <="f") THEN ch := CAP(ch) END ;
					IF (ch >= "A") & (ch <="F") THEN
						unicode := 16 * unicode + ORD(ch) - ORD("A") + 10 ; Files.Read(R,ch)
					 ELSIF (ch >= "0") & (ch <="9") THEN
						unicode := 16 * unicode + ORD(ch) - ORD("0") ; Files.Read(R,ch)
					 ELSE
					 	d := 6 
					 END ;
					 INC(d)
				END ;
				IF unicode < 256 THEN
					ch := CHR(unicode) ; high := FALSE
				 ELSE
					ch := "?" ; high := TRUE
				END ;
				valid := TRUE
			 ELSE
				valid := TRUE
			END
		 ELSE
			valid := TRUE
		END (* ch = "\" *)
		
		*)
		valid := TRUE ;
	UNTIL valid OR (R.eof)
END NextChar ;


	
PROCEDURE Get*(VAR sym: INTEGER) ;

	PROCEDURE Ident ;
	VAR
		i : INTEGER ;
		end : BOOLEAN ;
	BEGIN
		i := 0 ; end := FALSE ;
		IF ch = "@" THEN sym := at ; NextChar
		ELSIF ch = "#" THEN sym := hash ; NextChar
		ELSE sym := ident
		END ;
		REPEAT
			IF (ch >= "A") & (ch <= "Z") THEN ch := CHR(ORD(ch)-ORD("A") + ORD("a")) END;
			IF (i <IdLen) & ((ch >= "a") & (ch <= "z") OR (ch = "-") OR (ch >= "0") & (ch <= "9")) & ~R.eof THEN 
				id[i] := ch ; INC(i) ; NextChar ELSE end := TRUE 
			END ;
		UNTIL end ;
		IF i < IdLen THEN id[i] := 0X
		ELSE 
			WHILE ((ch >= "a")  & (ch <= "z") OR (ch >= "A")  & (ch <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = "-")) & ~R.eof DO
				 NextChar ; 
			END
		END ;
	END Ident ;
	
	PROCEDURE String ;
	VAR
		i : INTEGER ;
		end : BOOLEAN ;
		endchar : CHAR ;
	BEGIN
		endchar := ch ; NextChar ;
		i := 0 ; end := FALSE ;
		REPEAT
			IF (i <IdLen) & (ch # endchar) & ~R.eof THEN id[i] := ch ; INC(i) ; NextChar ELSE end := TRUE END
		UNTIL end ;
		IF i < IdLen THEN id[i] := 0X
		ELSE WHILE (ch # endchar) & ~R.eof DO NextChar END; id[IdLen-1] := 0X
		END;
		IF ch = endchar THEN NextChar END;
		sym := ident
	END String ;
	
	PROCEDURE Number(point : BOOLEAN) ;
	VAR
		neg : BOOLEAN ;
		div : REAL ;
	BEGIN
		realVal := 0; val := 0 ; neg := FALSE;
		IF ~point THEN
			IF  ch="+" THEN NextChar; neg := FALSE; IF ~((ch >= "0") & (ch <="9")) THEN sym := plus; RETURN END
			ELSIF ch="-" THEN NextChar; neg := TRUE
			END ;
			WHILE (ch >= "0") & (ch <="9") DO
				realVal := realVal * 10 - ORD("0") + ORD(ch);
				val := val * 10 - ORD("0") + ORD(ch) ;
				NextChar
			END
		END;
		IF (ch = ".") OR point THEN
			IF ch = "." THEN NextChar END;
			div := 10 ;
			WHILE (ch >= "0") & (ch <="9") DO
				realVal := realVal + (ORD(ch) - ORD("0"))/div; div := div*10;
				NextChar
			END;
		END;
		IF neg THEN val := -val ; realVal := -realVal END;
		sym := number;
	END Number ;
	
	PROCEDURE comment ;
	BEGIN
		NextChar;
		LOOP
			LOOP
				WHILE ch = "/" DO NextChar;
					IF ch = "*" THEN comment END
				END;
				IF ch = "*" THEN NextChar; EXIT END;
				IF R.eof THEN EXIT END;
				NextChar
			END;
			IF ch = "/" THEN NextChar; EXIT END;
			IF R.eof THEN EXIT END
		END
	END comment ;
	
	
BEGIN
	sym := null; eofSent := FALSE;
	WHILE sym = null DO
		WHILE ~R.eof & (ch <= " ") DO NextChar END ;
		IF R.eof THEN
			IF eofSent THEN HALT(85) END;
			sym := eof; eofSent := TRUE ;
		 ELSE
			pStart := Files.Pos(R)-1;
			CASE ch OF
				"'", '"' : String |
				"0".."9", "+", "-" : Number(FALSE) |
				";" : sym := semicolon ; NextChar |
				"=" : sym := equal ; NextChar |
				":" : sym := colon; NextChar |
				"," : sym := comma ; NextChar |
				"%" : sym := percent ; NextChar |
				"{" : sym := lbrace ; NextChar |
				"}" : sym := rbrace ; NextChar |
				"(" : sym := lparen ; NextChar |
				")" : sym := rparen ; NextChar |
				"[" : sym := lbrak ; NextChar |
				"]" : sym := rbrak ; NextChar |
				"/" : sym := slash ; NextChar ; IF ch = "*" THEN comment ; sym := null END|
				">" : sym := greater ; NextChar |
				"." : sym := point ; NextChar; IF (ch >= "0") & (ch <= "9") THEN Number(TRUE) END |
				"*" : sym := asterix ; NextChar |
				"a".."z", "A".."Z", "@", "#" : Ident
			ELSE
				IF (ORD(ch) > 177) OR high THEN Ident
				ELSE NextChar ;
				END
			END
		END 
	END; pEnd := Files.Pos(R)-1
END Get ;
	

PROCEDURE Init*(f : Files.File; offset : LONGINT) ;
BEGIN
	file := f;
	Files.Set(R, f, offset) ; Files.Read(R,ch)
END Init ;


BEGIN
	rgbStr := "rgb"
END WebCSS2Scanner.			
	


