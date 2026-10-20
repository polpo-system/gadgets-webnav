MODULE WebHTML4Scanner ;

IMPORT Pieces := WebPieces, Strings, Files ;


CONST
	maxtaglen* = 10 ;
	maxattrlen* = 20 ;
	
CONST (** syms *)
	anError* = 0;
	aTag* = 1 ;
	aPiece* = 2 ;
	anAttribute* = 3;

VAR
	entityFile : Files.File;
	
VAR
	R* : Files.Rider;
	Input : Files.File;
	ch : CHAR;
	
	tagName* : ARRAY maxtaglen OF CHAR ;
	tagEnd* : BOOLEAN;
	attributeName* : ARRAY maxattrlen OF CHAR;
	attributeValue* : Pieces.Piece; 
	p* : Pieces.Piece;

VAR
	state : SHORTINT;
	
VAR
	entities: ARRAY 68, 7 OF CHAR;
	
CONST
	normal = 0;
	inTag = 1;

PROCEDURE Init*(file : Files.File) ;
BEGIN
	Input := file;
	Files.Set(R, file, 0);
	Files.Read(R, ch);
	state := normal
END Init; 


PROCEDURE Get*(VAR sym: SHORTINT);
VAR
	len, Nr : INTEGER ;
		
	PROCEDURE SkipSpaces ;
	BEGIN
		WHILE (ch <= " ") &  ~R.eof DO
			Files.Read(R, ch)
		END
	END SkipSpaces ;

		
	PROCEDURE Entity(VAR Nr : INTEGER) : BOOLEAN ;
	VAR
		pos : LONGINT;
		name : ARRAY 8 OF CHAR;
		i : INTEGER;
		
	BEGIN
		Files.Read(R, ch); pos := Files.Pos(R);
		WHILE (i < LEN(name)-1) & (ch # ";") & ~R.eof DO
			name[i] := ch; Files.Read(R, ch); INC(i)
		END; name[i] := 0X; IF ch = ";" THEN Files.Read(R, ch) END;
		(* ..
		IF name[0] := "#" THEN
				code := 0; WHILE (ch >= "0") & (ch <= "9") & (code < MAX(LONGINT) DIV 10) DO
					code := code * 10 + ORD(ch) - ORD("0"); Files.Read(R, ch) ;
				END; IF ch = ";" THEN Files.Read(R, ch) END;
				CASE code OF
					171, 187 : Nr := 7; RETURN TRUE |
					228 : Nr := 1; RETURN TRUE |
					246 : Nr := 2; RETURN TRUE |
					252 : Nr := 3; RETURN TRUE
				ELSE RETURN FALSE
				END;
		*)
		i := 0; WHILE i < LEN(entities) DO
			IF entities[i] = name THEN Nr := i; RETURN TRUE END;
			INC(i)
		END;
		Files.Set(R, Input, pos); RETURN FALSE		
	END Entity ;
	
	PROCEDURE Comment;
		PROCEDURE ReadTillGreater;
		BEGIN
			WHILE (ch # ">") & ~R.eof DO Files.Read(R, ch); END;
			IF ~R.eof THEN Files.Read(R, ch) END
	END ReadTillGreater;
		
	BEGIN
		IF ch # "!" THEN ReadTillGreater; RETURN END;
		Files.Read(R, ch);
		IF ch = "-" THEN
			Files.Read(R, ch);
			IF ch = "-" THEN
				Files.Read(R, ch);
				LOOP
					IF R.eof THEN EXIT END;
					LOOP
						IF R.eof THEN EXIT END;
						IF ch = "-" THEN Files.Read(R, ch); EXIT
						ELSE Files.Read(R, ch) END;
					END;
					IF R.eof THEN EXIT END;
					IF ch = "-" THEN Files.Read(R, ch); EXIT
					ELSE Files.Read(R, ch) END;
				END
			END
		END; ReadTillGreater
	END Comment;
	

BEGIN
	IF Input = NIL THEN sym := anError-1 ; RETURN END ;
	IF R.eof THEN sym := anError-8 ; RETURN END ;
	
	LOOP
	IF state = normal THEN
	
		IF ch = "<" THEN
			IF R.eof THEN sym := anError-2 ; RETURN END ;
			Files.Read(R, ch) ;
			
			IF ch = "/" THEN tagEnd := TRUE ; Files.Read(R, ch)
			ELSE tagEnd := FALSE
			END;
			
			IF Strings.IsAlpha(ch) THEN
				len := 0 ; WHILE Strings.IsAlpha(ch) OR Strings.IsDigit(ch) DO
					IF (ch >= "a") & (ch <= "z") THEN ch:=CAP(ch) END ;
					IF len < maxtaglen THEN tagName[len] := ch ; INC(len) END ;
					IF R.eof THEN sym := anError-3 ; RETURN END ;
					Files.Read(R, ch)
				END ;
				IF len < maxtaglen THEN tagName[len] := 0X ELSE tagName[maxtaglen-1] := 0X END ;
				state := inTag;
				sym := aTag; RETURN
			 ELSE
				Comment
			END 
			
		 ELSIF ch = "&" THEN
			IF ~Entity(Nr) THEN Nr := LEN(entities)-1 END;
			p := Pieces.From(entityFile, Nr) ;
			Pieces.Lengthen(p,1) ;
			tagName := "#PCDATA";
			sym := aPiece ; RETURN
 		 				
		 ELSE
			p := Pieces.From(Input, Files.Pos(R)-1);
			len := 0; WHILE (ch # "<") & (ch # "&") & ~R.eof  DO
				INC(len); Files.Read(R, ch)
			END;
			Pieces.Lengthen(p,len) ;
			tagName := "#PCDATA"; sym := aPiece ; RETURN
		END
		
	ELSIF state = inTag THEN
		SkipSpaces ;
		IF ch = ">" THEN
			Files.Read(R, ch);
			state := normal
		ELSE
			len := 0;
			WHILE (ch # ">") & (ch # " ") & (ch # "=") & (ch # 9X) & (ch # 12X) DO
				IF (ch >= "a") & (ch <= "z") THEN ch:=CAP(ch) END ;
				IF len < maxattrlen THEN attributeName[len] := ch ; INC(len) END ;
				IF R.eof THEN sym := anError-4 ; RETURN END ;
				Files.Read(R, ch)
			END ;
			IF len < maxattrlen THEN attributeName[len] := 0X ELSE attributeName[maxattrlen-1] := 0X END ;
			
			SkipSpaces ;
			IF ch = "=" THEN
				Files.Read(R, ch) ;
				SkipSpaces ; len := 0 ;
				IF ch = '"' THEN
					Files.Read(R, ch) ;
					attributeValue := Pieces.From(Input, Files.Pos(R)-1);
					WHILE ch # '"' DO
						INC(len);
						IF R.eof THEN sym := anError-5 ; RETURN END ;
						Files.Read(R, ch)
					END ;
					Pieces.Lengthen(attributeValue, len);
					Files.Read(R, ch) ;
				 ELSE
					attributeValue := Pieces.From(Input, Files.Pos(R)-1);
					WHILE (ch # ">") & (ch # " ") & (ch # 9X) & (ch # 12X) DO
						INC(len) ;
						IF R.eof THEN sym := anError-6 ; RETURN END ;
						Files.Read(R, ch)
					END ;
					Pieces.Lengthen(attributeValue, len);
				END ;
				SkipSpaces ;
			ELSE
				attributeValue := NIL
			END;
			
			sym := anAttribute; RETURN
		END ;
	ELSE
		HALT(100)	
	END (* IF state = .. *)

	END (* LOOP *)
END Get;

PROCEDURE InitEntities();
BEGIN
	entities[0] := "AElig";
	entities[1] := "Aacute";
	entities[2] := "Acirc";
	entities[3] := "Agrave";
	entities[4] := "Aring";
	entities[5] := "Atilde";
	entities[6] := "Auml";
	entities[7] := "Ccedil";
	entities[8] := "ETH";
	entities[9] := "Eacute";
	entities[10] := "Ecirc";
	entities[11] := "Egrave";
	entities[12] := "Euml";
	entities[13] := "Iacute";
	entities[14] := "Icirc";
	entities[15] := "Igrave";
	entities[16] := "Iuml";
	entities[17] := "Ntilde";
	entities[18] := "Oacute";
	entities[19] := "Ocirc";
	entities[20] := "Ograve";
	entities[21] := "Oslash";
	entities[22] := "Otilde";
	entities[23] := "Ouml";
	entities[24] := "THORN";
	entities[25] := "Uacute";
	entities[26] := "Ucirc";
	entities[27] := "Ugrave";
	entities[28] := "Uuml";
	entities[29] := "Yacute";
	entities[30] := "aacute";
	entities[31] := "acirc";
	entities[32] := "aelig";
	entities[33] := "agrave";
	entities[34] := "amp";
	entities[35] := "aring";
	entities[36] := "atilde";
	entities[37] := "auml";
	entities[38] := "ccedil";
	entities[39] := "eacute";
	entities[40] := "ecirc";
	entities[41] := "egrave";
	entities[42] := "eth";
	entities[43] := "euml";
	entities[44] := "gt";
	entities[45] := "iacute";
	entities[46] := "icirc";
	entities[47] := "igrave";
	entities[48] := "iuml";
	entities[49] := "lt";
	entities[50] := "ntilde";
	entities[51] := "oacute";
	entities[52] := "ocirc";
	entities[53] := "ograve";
	entities[54] := "oslash";
	entities[55] := "otilde";
	entities[56] := "ouml";
	entities[57] := "quot";
	entities[58] := "szlig";
	entities[59] := "thorn";
	entities[60] := "uacute";
	entities[61] := "ucirc";
	entities[62] := "ugrave";
	entities[63] := "uuml";
	entities[64] := "yacute";
	entities[65] := "yuml";
	entities[66] := "quote";
	entities[67] := "nbsp";
	entityFile := Files.New("umlaute.txt");
	Files.Set(R, entityFile, 0);
	Files.WriteString(R, 'AAAAAAÄCDEEEEIIIINOOOOOÅPUUUÇYîÜaã&aaÉìêáådë>iàçí<ïoâéooÑ"ñpuäèÖyy" &')
END InitEntities;


BEGIN
	InitEntities
END WebHTML4Scanner.