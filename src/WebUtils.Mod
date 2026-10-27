MODULE WebUtils;  

IMPORT Strings;

TYPE 
	ustring* = ARRAY 128 OF CHAR; 
	
	PROCEDURE pref( pat, name: ARRAY OF CHAR ): BOOLEAN;  
	VAR i: INTEGER;  
	BEGIN 
		i := 0;  
		WHILE CAP( pat[i] ) = CAP( name[i] ) DO INC( i ) END;  
		RETURN (i > 0) & (pat[i] = 0X)
	END pref;  

	PROCEDURE prefixed( name: ARRAY OF CHAR ): BOOLEAN;  
	VAR i: INTEGER;  
	BEGIN 
		i := 0;  
		WHILE (name[i] # ':') & (name[i] # 0X) DO INC( i ) END;  
		RETURN name[i] = ':'
	END prefixed;  

	(* convrt strings line ''http%3A//..." to  "http://..."	*)
	PROCEDURE CleanURL*( VAR url: ARRAY OF CHAR );  
	VAR i, j: INTEGER;  tmp: ustring;

		PROCEDURE schar( ix: INTEGER ): CHAR;  
		VAR i, s, v: INTEGER;  c: CHAR;  
		BEGIN 
			s := 0; FOR i := 1 TO 2 DO 
				c := url[ix + i];  
				IF ('0' <= c) & (c <= '9') THEN v := ORD( c ) - 48 ELSE v := ORD( CAP( c ) ) - 55 END;  
				s := s*16 + v
			END;  
			RETURN CHR( s )
		END schar;  

	BEGIN 

		i := 0;  
		WHILE url[i] # 0X DO 
			IF url[i] = '%' THEN 
				url[i] := schar( i );  j := i + 1;  
				REPEAT url[j] := url[j + 2];  INC( j ) UNTIL url[j - 1] = 0X
			END;  
			INC( i )
		END;
		IF (url[0] = '/') & (url[1] = '/') THEN tmp := "http:";  Strings.Append( tmp, url ); COPY( tmp, url ) END;
	END CleanURL;  
	
	PROCEDURE MakeTempName*( url: ARRAY OF CHAR;  VAR fname: ARRAY OF CHAR );  
	VAR s, d, i, j: INTEGER;  l: LONGINT;  ch: CHAR;  
		name: ARRAY 32 OF CHAR;  
	BEGIN 
		name := "TempWeb.";  i := 7;  s := 7;
		WHILE url[i] # 0X DO 
			IF url[i] = '/' THEN s := i END;  
			INC( i )
		END;  
		l := 0;  
		FOR j := 7 TO s - 1 DO 
			l := l*2 + (ORD( url[j] ) - 32);  
			IF l > 997 THEN l := l MOD 997 END;  
		END;  
		j := 8;  
		name[j] := CHR( 48 + l DIV 100 );  l := l MOD 100;  INC( j );  
		name[j] := CHR( 48 + l DIV 10 );  l := l MOD 10;  INC( j );  
		name[j] := CHR( 48 + l );  INC( j );  
		name[j] := '.';  INC( j );  
		WHILE i - s > 19 DO INC( s ) END;  
		REPEAT 
			INC( s );  ch := url[s];  
			IF (ch # 0X) & ~(('0' <= ch) & (ch <= '9')) & ~(('A' <= CAP( ch )) & (CAP( ch ) <= 'Z')) THEN ch := '.' END; 
			name[j] := ch;  INC( j ) 
		UNTIL ch = 0X;  
		COPY( name, fname );  
	END MakeTempName;  
	
	PROCEDURE NewUrl*( oldurl, link: ARRAY OF CHAR;  VAR url: ARRAY OF CHAR );
	VAR i, bpath, d: INTEGER; dnf: BOOLEAN;
	BEGIN 
		IF prefixed( link ) THEN COPY( link, url )
		ELSE 
			i := 0;  bpath := 0;  
			WHILE oldurl[i] # 0X DO 
				url[i] := oldurl[i];  
				IF (url[i] = '/') & (bpath = 0) & (url[i - 1] # ':') & (url[i - 1] # '/') THEN bpath := i END;  
				INC( i )
			END;  
			url[i] := 0X;
			IF (bpath = 0) & (link # "") & (i > 7) & (url[0] = 'f') & (url[1] = 'i') & (url[2] = 'l') & (url[3] = 'e') & (url[4] = ':') & (url[5] = '/') & (url[6] = '/') THEN
				(* polpo: file://name is a file of the current directory, not a host: links go after file:// *)
				i := 7;  url[7] := 0X;  bpath := 7
			ELSIF bpath = 0 THEN bpath := i 
			ELSE 
				d := i; dnf := FALSE;
				REPEAT 
					DEC( d );
					IF url[d] = '.' THEN dnf := TRUE END;
				UNTIL (d <= bpath) OR (url[d] = '/');
				IF dnf THEN i := d + 1 END;
			END;
			IF link # "" THEN 
				IF (link[0] # '/') & (link[0] # '~') THEN 
					IF url[i - 1] # '/' THEN url[i] := '/';  INC( i ) END;  
					url[i] := 0X
				ELSE url[bpath] := 0X
				END;  
				Strings.Append( url, link ); 
			END
		END  
	END NewUrl;

END WebUtils.