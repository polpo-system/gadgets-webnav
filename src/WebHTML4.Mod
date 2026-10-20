MODULE WebHTML4;  

(* Die Konvertierungsroutinen sind in HTML4Convert.Mod gesichert *)


IMPORT Pieces := WebPieces, Scanner := WebHTML4Scanner, SGML := WebSGML, Strings, Files, Out;  

(*
CONST (* for InsertAlign in Convert *)
	leftRightYes = TRUE; topBottomYes = TRUE; centerYes = TRUE;  middleYes = TRUE; justifyYes = TRUE;
	leftRightNo = TRUE; topBottomNo = TRUE; centerNo = TRUE;  middleNo = TRUE; justifyNo = TRUE;
*)

TYPE 
	OpenTag = POINTER TO OpenTagDesc;  
	OpenTagDesc = RECORD 
			next: OpenTag;  
			tag: ARRAY 12 OF CHAR
	END;  

TYPE 
	Object* = POINTER TO ObjectDesc;  
	Piece* = POINTER TO PieceDesc;  
	Element* = POINTER TO ElementDescr;  
	Attribute = POINTER TO AttributeDesc;  
	
	ObjectDesc* = RECORD 
			next-: Object;  
	END;  
	
	ElementDescr* = RECORD (ObjectDesc);  
			parent-: Element;  
			type-: SGML.ElementType;  
			attributes: Attribute;  
			objects-, lastObject: Object;  
	END;  
	
	PieceDesc* = RECORD (ObjectDesc)
			piece-: Pieces.Piece;   (* Piece (of Text) or Element *)
	END;  
	
	AttributeDesc = RECORD;  
			next: Attribute;  
			name: ARRAY 20 OF CHAR;  
			value: Pieces.Piece;  
	END;  

TYPE 
	Length* = POINTER TO LengthDesc;  
	LengthDesc* = RECORD 
			next-: Length;  
			value: LONGINT;  
			percent, asterix: BOOLEAN;  
			len-: LONGINT;  
	END;  
	
	Lengths* = RECORD;  
			first-, last: Length;  
	END;  

VAR 
	HTML4SGML: SGML.ElementType;  

	PROCEDURE ^ThisChild*( element: Element;  name: ARRAY OF CHAR ): Element;  

	PROCEDURE Read*( file: Files.File ): Element;  
	VAR sym: SHORTINT;  sgmlElementType: SGML.ElementType;  openTags: OpenTag;  sgml: Object;  

		PROCEDURE AddOpenTag( name: ARRAY OF CHAR );  
		VAR ot: OpenTag;  
		BEGIN 
			NEW( ot );  COPY( name, ot.tag );  ot.next := openTags;  openTags := ot
		END AddOpenTag;  

		PROCEDURE RemoveOpenTag( name: ARRAY OF CHAR );  
		VAR ot: OpenTag;  
		BEGIN 
			IF openTags # NIL THEN 
				IF openTags.tag = name THEN openTags := openTags.next 
				ELSE 
					ot := openTags.next;  
					WHILE ot # NIL DO 
						IF ot.tag = name THEN openTags := ot.next;  ot := NIL ELSE ot := ot.next END 
					END 
				END 
			END 
		END RemoveOpenTag;  

		PROCEDURE IsTagOpen( name: ARRAY OF CHAR ): BOOLEAN;  
		VAR ot: OpenTag;  
		BEGIN 
			ot := openTags;  
			WHILE ot # NIL DO 
				IF ot.tag = name THEN RETURN TRUE END;  
				ot := ot.next
			END;  
			RETURN FALSE
		END IsTagOpen;  

		PROCEDURE TagInFirst( content: SGML.ContentGroup ): BOOLEAN;  
		VAR child: SGML.ContentGroup;  
		BEGIN 
			IF content = NIL THEN RETURN FALSE END;  
			IF (sym = Scanner.aTag) & ~SGML.isElement( HTML4SGML, Scanner.tagName ) THEN RETURN TRUE END;  
			IF content.element # NIL THEN 
				IF content.element.name = Scanner.tagName THEN RETURN TRUE 
				ELSE 
					IF (sym = Scanner.aPiece) & Pieces.IsWhiteSpace( Scanner.p ) THEN RETURN FALSE END;  
					RETURN content.element.beginopt & TagInFirst( content.element.content )
				END 
			ELSE 
				child := content.children;  
				WHILE (child # NIL ) DO 
					IF TagInFirst( child ) THEN RETURN TRUE END;  
					child := child.next
				END;  
				RETURN FALSE
			END  (* if element *)
		END TagInFirst;  

		PROCEDURE NewElement( VAR e: Element;  type: SGML.ElementType );  
		BEGIN 
			NEW( e );  e.type := type
		END NewElement;  

		PROCEDURE AddAttributeTo( element: Element );  
		VAR attribute: Attribute;  
		BEGIN 
			NEW( attribute );  COPY( Scanner.attributeName, attribute.name );  
			attribute.value := Scanner.attributeValue;  attribute.next := element.attributes;  
			element.attributes := attribute
		END AddAttributeTo;  

		PROCEDURE AddObject( parent: Element;  object: Object );  
		BEGIN 
			IF (parent = NIL ) OR (object = NIL ) THEN RETURN END;  
			IF object IS Element THEN object( Element ).parent := parent;  END;  
			IF parent.lastObject # NIL THEN parent.lastObject.next := object ELSE parent.objects := object END;  
			parent.lastObject := object
		END AddObject;  

		PROCEDURE ^ReadElement( et: SGML.ElementType ): Object;  

		PROCEDURE ReadContent( content: SGML.ContentGroup ): Object;  
		VAR child: SGML.ContentGroup;  
		BEGIN 
			IF content.element # NIL THEN RETURN ReadElement( content.element ) END;  
			child := content.children;  
			IF child = NIL THEN Out.String( "Content without children" ) END;  
			WHILE child # NIL DO 
				IF TagInFirst( child ) THEN RETURN ReadContent( child ) END;   (* Liesse sich wohl auch nicht rekursiv l„sen *)
				child := child.next
			END;   (* Schleife sollte eigentlich nicht zum Ende kommen *)
			Scanner.Get( sym );  RETURN NIL 
		END ReadContent;  

		PROCEDURE ReadElement( et: SGML.ElementType ): Object;  
		VAR element: Element;  piece: Piece;  childET: SGML.ElementType;  
		BEGIN 
			IF et.name = "#PCDATA" THEN 
				NEW( piece );  
				IF sym = Scanner.aPiece THEN piece.piece := Scanner.p;  Scanner.Get( sym ) 
				ELSE 
					(* HALT(21) *)
					Out.String( "Halt 21" );  Out.Ln;  Scanner.Get( sym )
				END;  
				RETURN piece
			ELSE 
				NewElement( element, et );  AddOpenTag( et.name );  
				IF Scanner.tagName = et.name THEN 
					Scanner.Get( sym );  
					WHILE sym = Scanner.anAttribute DO 
						AddAttributeTo( element );  Scanner.Get( sym ) 
					END;  
				END;  
				IF ~et.empty THEN 
					LOOP 
						IF (sym = Scanner.aTag) & Scanner.tagEnd THEN 
							IF Scanner.tagName = et.name THEN Scanner.Get( sym );  EXIT 
							ELSE 
								IF IsTagOpen( Scanner.tagName ) THEN EXIT ELSE Scanner.Get( sym ) END 
							END;  
						ELSIF sym > Scanner.anError THEN 
							WHILE (sym = Scanner.aTag) & ~SGML.isElement( HTML4SGML, Scanner.tagName ) DO 
								Scanner.Get( sym );  
								WHILE sym = Scanner.anAttribute DO Scanner.Get( sym ) END 
							END;  
							IF TagInFirst( et.forbiddenContent ) & (sym # Scanner.aPiece) THEN EXIT 
							ELSIF TagInFirst( et.content ) THEN AddObject( element, ReadContent( et.content ) )
							ELSE 
								IF et.endopt & (sym # Scanner.aPiece) THEN EXIT 
								ELSE 
									IF sym = Scanner.aPiece THEN Scanner.tagName := "#PCDATA" END;  
									childET := SGML.ThisElementType( HTML4SGML, Scanner.tagName );  
									AddObject( element, ReadElement( childET ) )
								END 
							END 
						ELSE 
							EXIT  (* HALT(88) *)
						END 
					END  (* LOOP *)
				ELSE; 
				END;   (* ~empty *)
				RemoveOpenTag( et.name );  RETURN element
			END 
		END ReadElement;  

	BEGIN 
		Scanner.Init( file );  Scanner.Get( sym );  
		IF sym > Scanner.anError THEN 
			sgmlElementType := SGML.ThisElementType( HTML4SGML, "SGML" );  
			sgml := ReadElement( sgmlElementType );  
			RETURN ThisChild( sgml( Element ), "HTML" );  
		END 
		(* Trap *)
	END Read;  

	PROCEDURE NewElement*( VAR e: Element;  type: SGML.ElementType );  
	BEGIN 
		NEW( e );  e.type := type
	END NewElement;  

	PROCEDURE ThisChild*( element: Element;  name: ARRAY OF CHAR ): Element;  
	VAR object: Object;  
	BEGIN 
		object := element.objects;  
		WHILE object # NIL DO 
			IF object IS Element THEN 
				IF Strings.CAPCompare( object( Element ).type.name, name ) THEN RETURN object( Element ) END 
			END;  
			object := object.next
		END;  
		RETURN NIL 
	END ThisChild;  

	PROCEDURE ThisAttribute*( element: Element;  name: ARRAY OF CHAR ): Pieces.Piece;  
	VAR attribute: Attribute;  
		uName: ARRAY 16 OF CHAR;  
	BEGIN 
		Strings.Upper( name, uName );  attribute := element.attributes;  
		WHILE attribute # NIL DO 
			IF attribute.name = uName THEN RETURN attribute.value END;  
			attribute := attribute.next
		END;  
		RETURN NIL 
	END ThisAttribute;  

	PROCEDURE DeleteLengths*( VAR lens: Lengths );  
	BEGIN 
		lens.first := NIL;  lens.last := NIL 
	END DeleteLengths;  

	PROCEDURE AddMultiLength*( piece: Pieces.Piece;  VAR lens: Lengths );  
	VAR R: Files.Rider;  length: Length;  ch: CHAR;  pos: LONGINT;  
	BEGIN 
		Files.Set( R, piece.f, piece.off );  Files.Read( R, ch );  pos := 1;  
		LOOP 
			WHILE ((ch < "0") OR (ch > "9")) & (ch # "*") DO 
				Files.Read( R, ch );  INC( pos );  
				IF pos > piece.len THEN RETURN END;  
			END;  
			NEW( length );  
			IF lens.last = NIL THEN lens.first := length ELSE lens.last.next := length END;  
			lens.last := length;  length.percent := FALSE;  
			IF ch # "*" THEN 
				length.asterix := FALSE;  length.value := ORD( ch ) - ORD( "0" );  Files.Read( R, ch );  INC( pos );  
				IF pos > piece.len THEN RETURN END;  
				WHILE (ch >= "0") & (ch <= "9") DO 
					IF length.value > MAX( LONGINT ) DIV 10 THEN RETURN END;  
					length.value := 10*length.value + ORD( ch ) - ORD( "0" );  Files.Read( R, ch );  INC( pos );  
					IF pos > piece.len THEN RETURN END;  
				END;  
				IF ch = "*" THEN 
					length.asterix := TRUE;  Files.Read( R, ch );  INC( pos );  
					IF pos > piece.len THEN RETURN END 
				ELSIF ch = "%" THEN 
					length.percent := TRUE;  Files.Read( R, ch );  INC( pos );  
					IF pos > piece.len THEN RETURN END 
				END 
			ELSE 
				length.asterix := TRUE;  length.value := 1;  Files.Read( R, ch );  INC( pos );  
				IF pos > piece.len THEN RETURN END 
			END;  
		END;  
	END AddMultiLength;  

	PROCEDURE AddLength*( number: LONGINT;  len: LONGINT;  VAR lens: Lengths );  
	VAR length: Length;  i: LONGINT;  
	BEGIN 
		IF number > 0 THEN 
			FOR i := 1 TO number DO 
				NEW( length );  
				IF len = MIN( LONGINT ) THEN length.asterix := TRUE;  length.value := 1 
				ELSE length.asterix := FALSE;  length.value := len
				END;  
				length.percent := FALSE;  
				IF lens.last = NIL THEN lens.first := length ELSE lens.last.next := length END;  
				lens.last := length;  
			END 
		END 
	END AddLength;  

	PROCEDURE Len*( piece: Pieces.Piece ): LONGINT;  
	VAR R: Files.Rider;  pos: LONGINT;  ch: CHAR;  len: LONGINT;  
	BEGIN 
		Files.Set( R, piece.f, piece.off );  len := 0;  Files.Read( R, ch );  INC( pos );  
		IF pos > piece.len THEN RETURN 0 END;  
		WHILE ~((ch < "0") OR (ch > "9")) DO 
			IF len > MAX( LONGINT ) DIV 10 THEN RETURN MAX( LONGINT ) END;  
			len := len*10 + ORD( ch ) - ORD( "0" );  Files.Read( R, ch );  INC( pos );  
			IF pos > piece.len THEN RETURN len END 
		END;  
		RETURN len
	END Len;  

	PROCEDURE CalcLengths*( lens: Lengths;  total: LONGINT );  
	VAR len: Length;  sum: LONGINT;  asterixes: LONGINT;  rest: LONGINT;  
	BEGIN 
		sum := 0;  asterixes := 0;  len := lens.first;  
		WHILE len # NIL DO 
			IF len.percent THEN INC( sum, len.value*total DIV 100 )
			ELSIF ~len.asterix THEN INC( sum, len.value )
			ELSE INC( asterixes )
			END;  
			len := len.next
		END;  
		IF sum > total THEN 
			rest := total;  len := lens.first;  
			WHILE len # NIL DO 
				IF len.next = NIL THEN len.len := rest
				ELSIF len.percent THEN len.len := len.value*total DIV sum*total DIV 100
				ELSIF ~len.asterix THEN len.len := len.value*total DIV sum
				ELSE len.len := 0;  
				END;  
				DEC( rest, len.len );  len := len.next
			END 
		ELSE 
			rest := total;  len := lens.first;  
			WHILE len # NIL DO 
				IF len.next = NIL THEN len.len := rest
				ELSIF len.percent THEN len.len := len.value*total DIV 100
				ELSIF ~len.asterix THEN len.len := len.value
				ELSE len.len := (total - sum)*len.value DIV asterixes
				END;  
				DEC( rest, len.len );  len := len.next
			END 
		END 
	END CalcLengths;  

	PROCEDURE OutLengths*( lens: Lengths );  
	VAR len: Length;  
	BEGIN 
		len := lens.first;  
		WHILE len # NIL DO 
			Out.String( "Len : " );  Out.Int( len.len, 10 );  
			IF len.asterix THEN Out.Char( "*" ) END;  
			Out.Ln;  len := len.next
		END;  
	END OutLengths;  

	PROCEDURE NamedColor*( str: ARRAY OF CHAR ): LONGINT;  
	VAR lowStr: ARRAY 16 OF CHAR;  
	BEGIN 
		Strings.Lower( str, lowStr );  
		IF lowStr = "black" THEN RETURN 0
		ELSIF lowStr = "silver" THEN RETURN 192*256*256 + 192*256 + 192
		ELSIF lowStr = "gray" THEN RETURN 128*256*256 + 128*256 + 128
		ELSIF lowStr = "white" THEN RETURN 255*256*256 + 255*256 + 255
		ELSIF lowStr = "maroon" THEN RETURN 128*256*256
		ELSIF lowStr = "red" THEN RETURN 255*256*256
		ELSIF lowStr = "purple" THEN RETURN 255*256*256 + 255
		ELSIF lowStr = "green" THEN RETURN 128*256
		ELSIF lowStr = "lime" THEN RETURN 255*256
		ELSIF lowStr = "olive" THEN RETURN 128*256*256 + 128*256
		ELSIF lowStr = "yellow" THEN RETURN 255*256*256 + 255*256
		ELSIF lowStr = "navy" THEN RETURN 128
		ELSIF lowStr = "blue" THEN RETURN 255
		ELSIF lowStr = "teal" THEN RETURN 128*256 + 128
		ELSIF lowStr = "aqua" THEN RETURN 255*256 + 255
		END;  
		RETURN -2
	END NamedColor;  

	PROCEDURE Color*( color: Pieces.Piece ): LONGINT;  
	VAR colorStr: ARRAY 16 OF CHAR;  
		colorValue: LONGINT;  j: SHORTINT;  
	
	BEGIN 
		IF color = NIL THEN RETURN -2 END;  
		Pieces.Convert( color, colorStr );  colorValue := -2;  
		IF (colorStr[0] = "#") & (Strings.Length( colorStr ) = 7) THEN 
			colorValue := 0;  j := 1;  
			WHILE j < 7 DO 
				IF (colorStr[j] >= "0") & (colorStr[j] <= "9") THEN 
					colorValue := colorValue*16 + ORD( colorStr[j] ) - ORD( "0" )
				ELSIF (colorStr[j] >= "A") & (colorStr[j] <= "F") THEN 
					colorValue := colorValue*16 + ORD( colorStr[j] ) - ORD( "A" ) + 10
				ELSIF (colorStr[j] >= "a") & (colorStr[j] <= "f") THEN 
					colorValue := colorValue*16 + ORD( colorStr[j] ) - ORD( "a" ) + 10
				ELSE j := 7;  colorValue := -2
				END;  
				INC( j )
			END;  
		END;  
		IF colorValue < 0 THEN RETURN NamedColor( colorStr ) ELSE RETURN colorValue END 
	END Color;  

BEGIN 
	HTML4SGML := SGML.Parse( "WebHTML4Loose.SGML", 0 )
END WebHTML4.