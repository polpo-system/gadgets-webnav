MODULE WebPieces;  

IMPORT Files, Strings, Out;  

TYPE 
	Piece* = POINTER TO PieceDesc;  
	PieceDesc* = RECORD  		(* Die Textteilchen erben die Eigenschaften und besitzen keinen eigenen *)
			f-: Files.File;  
			off-: LONGINT;  
			len-: LONGINT;  
	END;  
	
	PROCEDURE New*( VAR obj: Piece );  
	BEGIN 
		NEW( obj );  obj.f := Files.New( "" );  obj.off := 0;  obj.len := 0;  
	END New;  

	PROCEDURE From*( f: Files.File;  offset: LONGINT ): Piece;  
	VAR obj: Piece;  
	BEGIN 
		NEW( obj );  obj.f := f;  obj.off := offset;  obj.len := 0;  RETURN obj
	END From;  

	PROCEDURE Lengthen*( p: Piece;  len: LONGINT );  
	BEGIN 
		INC( p.len, len )
	END Lengthen;  

	PROCEDURE Display*( p: Piece );  
	VAR R: Files.Rider;  pos: LONGINT;  ch: CHAR;
	BEGIN 
		IF p # NIL THEN 
			Files.Set( R, p.f, p.off );  pos := 0;  
			WHILE (pos < p.len) & ~R.eof  DO 
				Files.Read( R, ch );  INC( pos );
				Out.Char( ch )
			END;  
		ELSE Out.Ln
		END 
	END Display;  

	PROCEDURE Convert*( p: Piece;  VAR str: ARRAY OF CHAR );  
	VAR R: Files.Rider;  pos: LONGINT;  
	BEGIN 
		IF p # NIL THEN 
			Files.Set( R, p.f, p.off );  pos := 0;  
			WHILE (pos < p.len) & ~R.eof & (pos < LEN( str )) DO Files.Read( R, str[pos] );  INC( pos ) END;  
			IF pos < LEN( str ) THEN str[pos] := 0X ELSE str[pos - 1] := 0X END 
		ELSE str[0] := 0X
		END 
	END Convert;  

	PROCEDURE ConvertToPiece*( VAR p: Piece;  VAR  (** in *) str: ARRAY OF CHAR );  
	VAR R: Files.Rider;  
	BEGIN 
		NEW( p );  p.f := Files.New( "" );  p.off := 0;  p.len := -1;  Files.Set( R, p.f, 0 );  
		REPEAT INC( p.len );  Files.Write( R, str[p.len] ) UNTIL str[p.len] = 0X
	END ConvertToPiece;  

	PROCEDURE ConvertToInteger*( p: Piece ): LONGINT;  
	VAR R: Files.Rider;  i: LONGINT;  pos: LONGINT;  ch: CHAR;  neg: LONGINT;  
	BEGIN 
		IF (p = NIL ) OR (p.len = 0) THEN RETURN 0 END;  
		i := 0;  Files.Set( R, p.f, p.off );  Files.Read( R, ch );  
		IF ch = "-" THEN neg := -1;  Files.Read( R, ch );  pos := 2
		ELSIF ch = "+" THEN neg := 1;  Files.Read( R, ch );  pos := 2
		ELSE neg := 1
		END;  
		pos := 1;  
		WHILE (pos <= p.len) & ~R.eof & (ABS( i ) < MAX( LONGINT ) DIV 10) DO 
			IF (ch < "0") OR (ch > "9") THEN RETURN i*neg END;  
			i := i*10 + ORD( ch ) - ORD( "0" );  Files.Read( R, ch );  INC( pos );  
		END;  
		RETURN i*neg;  
	END ConvertToInteger;  

	PROCEDURE IsWhiteSpace*( piece: Piece ): BOOLEAN;  
	VAR i: LONGINT;  R: Files.Rider;  ch: CHAR;  
	BEGIN 
		IF piece = NIL THEN RETURN TRUE END;  
		Files.Set( R, piece.f, piece.off );  i := 0;  
		WHILE i < piece.len DO 
			Files.Read( R, ch );  
			IF ch > " " THEN RETURN FALSE END;  
			INC( i )
		END;  
		RETURN TRUE
	END IsWhiteSpace;  

	PROCEDURE DeleteLeadingWhiteSpaces*( piece: Piece );  
	VAR R: Files.Rider;  ch: CHAR;  
	BEGIN 
		IF piece = NIL THEN RETURN END;  
		Files.Set( R, piece.f, piece.off );  Files.Read( R, ch );  
		WHILE (ch <= " ") & (piece.len > 0) DO INC( piece.off );  DEC( piece.len );  Files.Read( R, ch ) END 
	END DeleteLeadingWhiteSpaces;  

	PROCEDURE CAPCompare*( piece: Piece;  str: ARRAY OF CHAR ): BOOLEAN;  
	VAR R: Files.Rider;  pos: LONGINT;  ch: CHAR;  strLen: LONGINT;  
	
	BEGIN 
		strLen := Strings.Length( str );  
		IF (piece = NIL ) OR (piece.len # strLen) THEN RETURN FALSE END;  
		Files.Set( R, piece.f, piece.off );  pos := 0;  
		WHILE (pos < piece.len) & ~R.eof & (pos < strLen) DO 
			Files.Read( R, ch );  
			IF CAP( ch ) # CAP( str[pos] ) THEN RETURN FALSE END;  
			INC( pos )
		END;  
		RETURN pos = strLen
	END CAPCompare;  

	PROCEDURE CAPPieceCompare*( piece1, piece2: Piece ): BOOLEAN;  
	VAR R1, R2: Files.Rider;  pos: LONGINT;  ch1, ch2: CHAR;  
	BEGIN 
		IF piece1 = NIL THEN RETURN (piece2 = NIL ) END;  
		IF (piece2 = NIL ) OR (piece1.len # piece2.len) THEN RETURN FALSE END;  
		Files.Set( R1, piece1.f, piece1.off );  Files.Set( R2, piece2.f, piece2.off );  pos := 0;  
		WHILE (pos < piece1.len) & ~R1.eof & ~R2.eof DO 
			Files.Read( R1, ch1 );  Files.Read( R2, ch2 );  
			IF CAP( ch1 ) # CAP( ch2 ) THEN RETURN FALSE END;  
			INC( pos )
		END;  
		RETURN pos = piece1.len
	END CAPPieceCompare;  

	PROCEDURE SplitLink*( link: Piece;  VAR docname, anchor: Piece );  
	VAR R: Files.Rider;  pos: LONGINT;  ch: CHAR;  
	BEGIN 
		Files.Set( R, link.f, link.off );  pos := 0;  ch := 0X;  
		WHILE (pos < link.len) & ~R.eof & (ch # "#") DO Files.Read( R, ch );  INC( pos ) END;  
		IF (pos = link.len) & (ch # "#") THEN docname := link;  anchor := NIL 
		ELSE 
			NEW( docname );  docname.f := link.f;  docname.off := link.off;  docname.len := pos - 1;  
			NEW( anchor );  anchor.f := link.f;  anchor.off := link.off + pos;  anchor.len := link.len - pos;  
		END 
	END SplitLink;  

	PROCEDURE Write*( VAR r: Files.Rider;  piece: Piece );  
	VAR R: Files.Rider;  pos: LONGINT;  ch: CHAR;  
	
	BEGIN 
		Files.Set( R, piece.f, piece.off );  pos := 0;  Files.WriteLInt( r, piece.len );  
		WHILE (pos < piece.len) & ~R.eof DO Files.Read( R, ch );  Files.Write( r, ch );  INC( pos ) END;  
	END Write;  

	PROCEDURE Read*( VAR r: Files.Rider;  VAR piece: Piece );  
	VAR i: LONGINT;  ch: CHAR;  
	BEGIN 
		NEW( piece );  Files.ReadLInt( r, piece.len );  Out.Int( piece.len, 4 );  piece.f := Files.Base( r );  
		piece.off := Files.Pos( r );  
		FOR i := 1 TO piece.len DO Files.Read( r, ch );  Out.Char( ch );  END;  
		Out.Ln
	END Read;  

	PROCEDURE OutPiece*( piece: Piece );  
	VAR pos: LONGINT;  ch: CHAR;  R: Files.Rider;  
	BEGIN 
		Files.Set( R, piece.f, piece.off );  pos := 0;  
		WHILE (pos < piece.len) & ~R.eof DO Files.Read( R, ch );  Out.Char( ch );  INC( pos ) END;  
	END OutPiece;  

END WebPieces.