(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE WebNetwork;  

(* 
		most of the  code is borrowed form HTTPDocs.Mod
		2000.11.20	g.f.
*)

IMPORT Kernel, Input, NetSystem, NetTools, Strings, HyperDocs, Texts, Oberon, Attributes, HTTPDocs0, 
	Streams,   MIME, Files, Objects, Out, http, httpsPure, strTypes, U := WebUtils;  


CONST 
	IdentifyUser = FALSE;  

TYPE 
	Authorization = POINTER TO AuthorizationDesc;  
	AuthorizationDesc = RECORD 
			host: ARRAY NetTools.ServerStrLen OF CHAR;  
			path: ARRAY NetTools.PathStrLen OF CHAR;  
			coded: ARRAY 64 OF CHAR;  
			port: INTEGER;  
			next: Authorization
	END;  
	Cookie = POINTER TO CookieDesc;  
	CookieDesc = RECORD 
			name, domain: ARRAY 64 OF CHAR;  
			val, path: ARRAY 256 OF CHAR;  
			d, t: LONGINT;  
			next: Cookie
	END;  

VAR 
	W: Texts.Writer;  
	buf: ARRAY NetTools.BufLen OF CHAR;  
	noWorkers: INTEGER;  
	encTable: ARRAY 64 OF CHAR;  
	authorizations: Authorization;  cookies: Cookie;  
	EMail: ARRAY NetTools.ServerStrLen OF CHAR;  
	client: ARRAY 64 OF CHAR;  
	
	PROCEDURE *TCPAvailable( S: Streams.Stream ): LONGINT;  
	BEGIN 
		HTTPDocs0.Wait();  RETURN NetTools.TCPAvailable( S )
	END TCPAvailable;  

	PROCEDURE OpenStream( C: NetSystem.Connection ): Streams.Stream;  
	VAR S: Streams.Stream;  
	BEGIN 
		S := NetTools.OpenStream( C );  S.Available := TCPAvailable;  RETURN S
	END OpenStream;  

	PROCEDURE EncBase64( VAR src, dest: ARRAY OF CHAR );  
	VAR s, d, i, j, c, c0, c1, c2: LONGINT;  
		chars: ARRAY 3 OF CHAR;  
		
		PROCEDURE OutCode( );  
		BEGIN 
			c0 := ORD( chars[0] );  c := ASH( c0, -2 );  dest[d] := encTable[c];  INC( d );  c0 := c0 - ASH( c, 2 );  
			c1 := ORD( chars[1] );  c := ASH( c0, 4 ) + ASH( c1, -4 );  dest[d] := encTable[c];  INC( d );  
			c1 := c1 MOD ASH( 1, 4 );  c2 := ORD( chars[2] );  c := ASH( c1, 2 ) + ASH( c2, -6 );  dest[d] := encTable[c];  
			INC( d );  c2 := c2 MOD ASH( 1, 6 );  dest[d] := encTable[c2];  INC( d )
		END OutCode;  

	BEGIN 
		s := 1;  d := 0;  chars[0] := src[0];  i := 1;  
		WHILE src[s] # 0X DO 
			IF i >= 3 THEN OutCode();  i := 0 END;  
			chars[i] := src[s];  INC( i );  INC( s )
		END;  
		IF i > 0 THEN 
			j := i;  
			WHILE i < 3 DO chars[i] := 0X;  INC( i ) END;  
			OutCode();  
			IF j < 3 THEN 
				j := 3 - j;  d := d - j;  
				FOR i := 1 TO j DO dest[d] := "=";  INC( d ) END 
			END 
		END;  
		dest[d] := 0X
	END EncBase64;  

	PROCEDURE GetAuthorization( VAR host, path: ARRAY OF CHAR;  port: INTEGER ): Authorization;  
	VAR aut: Authorization;  
	BEGIN 
		aut := authorizations;  
		WHILE (aut # NIL ) & (aut.port # port) & (aut.host # host) & (aut.path # path) DO aut := aut.next END;  
		RETURN aut
	END GetAuthorization;  

	PROCEDURE FindCookie( root: Cookie;  VAR host, path: ARRAY OF CHAR ): Cookie;  
	VAR c: Cookie;  
	BEGIN 
		c := root;  
		WHILE (c # NIL ) & ~Strings.Prefix( c.path, path ) DO c := c.next END;  
		(* check domain & date *)
		RETURN c
	END FindCookie;  

	PROCEDURE AddCookie( VAR host, path, value: ARRAY OF CHAR );  
	(* value = name = val ";" [ "path" = path ";" ] [ "expires" = date ";" ] [ "domain" = domain ";" ] . *)
	VAR i: LONGINT;  
		name: ARRAY 64 OF CHAR;  
		C, c: Cookie;  p, e, d: BOOLEAN;  

		PROCEDURE Skip( );  
		BEGIN 
			WHILE (value[i] <= " ") & (value[i] # 0X) DO INC( i ) END 
		END Skip;  

		PROCEDURE GetName( );  
		VAR j: LONGINT;  
		BEGIN 
			Skip();  j := 0;  
			WHILE (value[i] > " ") & (value[i] # "=") & (value[i] # 0X) DO 
				name[j] := Strings.UpperCh( value[i] );  INC( j );  INC( i )
			END;  
			name[j] := 0X;  Skip();  
			IF value[i] = "=" THEN INC( i ) END;  
			Skip()
		END GetName;  

		PROCEDURE GetValue( VAR val: ARRAY OF CHAR );  
		VAR j: LONGINT;  
		BEGIN 
			Skip();  j := 0;  
			WHILE (value[i] # ";") & (value[i] # 0X) DO val[j] := value[i];  INC( j );  INC( i ) END;  
			val[j] := 0X;  Skip();  
			IF value[i] = ";" THEN INC( i ) END;  
			Skip()
		END GetValue;  

	BEGIN 
		i := 0;  
		WHILE (value[i] # ":") & (value[i] # 0X) DO INC( i ) END;  
		IF value[i] = ":" THEN 
			p := FALSE;  e := FALSE;  d := FALSE;  C := NIL;  INC( i );  
			WHILE value[i] # 0X DO 
				GetName();  
				IF value[i] # 0X THEN 
					IF C = NIL THEN NEW( C );  C.name := "" END;  
					IF name = "PATH" THEN GetValue( C.path );  p := TRUE
					ELSIF name = "EXPIRES" THEN GetValue( name );  

						e := TRUE
					ELSIF name = "DOMAIN" THEN GetValue( C.domain );  d := TRUE
					ELSE COPY( name, C.name );  GetValue( C.val )
					END 
				END 
			END;  
			IF (C # NIL ) & (C.name # "") THEN 
				IF ~p THEN COPY( path, C.path ) END;  
				IF ~d THEN COPY( host, C.domain ) END;  
				IF ~e THEN 
				END;  
				c := cookies;  
				WHILE (c # NIL ) & ((c.name # C.name) OR (c.path # C.path)) DO c := c.next END;  
				IF c # NIL THEN 
					COPY( C.name, c.name );  COPY( C.domain, c.domain );  COPY( C.val, c.val );  c.d := C.d;  c.t := C.t
				ELSE C.next := cookies;  cookies := C
				END 
			END 
		END 
	END AddCookie;  
	
	PROCEDURE NetLen( T: Texts.Text ): LONGINT;  
	VAR R: Texts.Reader;  len: LONGINT;  ch: CHAR;  
	BEGIN 
		len := 0;  Texts.OpenReader( R, T, 0 );  Texts.Read( R, ch );  
		WHILE ~R.eot DO 
			IF ch = Strings.CR THEN INC( len ) END;  
			INC( len );  Texts.Read( R, ch )
		END;  
		RETURN len
	END NetLen;  

	PROCEDURE Request*( C: NetSystem.Connection;  method: ARRAY OF CHAR;  VAR key: LONGINT;  proxy: BOOLEAN;  
									    VAR query: Texts.Text;  log: BOOLEAN );  
	VAR str: ARRAY 12 OF CHAR;  
		R: Texts.Reader;  
		host: ARRAY NetTools.ServerStrLen OF CHAR;  
		path: ARRAY NetTools.PathStrLen OF CHAR;  
		label: ARRAY 64 OF CHAR;  
		i, j: LONGINT;  aut: Authorization;  cookie: Cookie;  port: INTEGER;  ch: CHAR;  
	BEGIN 
		aut := NIL;  
		IF log & (method # "GET") THEN Texts.WriteString( W, method );  Texts.Write( W, " " ) END;  
		NetTools.SendString( C, method );  NetSystem.Write( C, " " );  HyperDocs.RetrieveLink( key, buf );  
		IF ~proxy OR Strings.CAPPrefix( "http:", buf ) THEN 
			key := HTTPDocs0.SplitHTTPAdr( buf, host, path, label, port );  
			IF log THEN Texts.Append( Oberon.Log, W.buf ) END;  
			j := -1;  i := 0;  
			WHILE (path[i] # 0X) & (j < 0) DO 
				IF path[i] = "?" THEN 
					j := i
					(*ELSIF path[i] = "/" THEN
					j := -1*)
				END;  
				INC( i )
			END;  
			IF j > 0 THEN 
				path[j] := 0X;  
				IF query = NIL THEN 
					INC( j );  
					WHILE path[j] # 0X DO Texts.Write( W, path[j] );  INC( j ) END;  
					NEW( query );  Texts.Open( query, "" );  Texts.Append( query, W.buf )
				END 
			END;  
			IF proxy THEN 
				buf := "http://";  Strings.Append( buf, host );  Strings.AppendCh( buf, ":" );  Strings.IntToStr( port, str );  
				Strings.Append( buf, str );  
				IF log THEN Texts.WriteString( W, host ) END;  
				NetTools.SendString( C, buf )
			END;  
			aut := GetAuthorization( host, path, port );  
			IF (aut = NIL ) & (HyperDocs.context # NIL ) & (HyperDocs.context IS HTTPDocs0.Context) & 
			    (HyperDocs.context( HTTPDocs0.Context ).user # "") THEN 
				NEW( aut );  COPY( host, aut.host );  aut.port := port;  COPY( path, aut.path );  
				COPY( HyperDocs.context( HTTPDocs0.Context ).user, label );  Strings.AppendCh( label, ":" );  
				Strings.Append( label, HyperDocs.context( HTTPDocs0.Context ).passwd );  EncBase64( label, aut.coded );  
				HyperDocs.context( HTTPDocs0.Context ).user := "";  aut.next := authorizations;  authorizations := aut
			END;  
			COPY( path, buf );  HyperDocs.ESC( buf, 0X );  
			IF log THEN Texts.WriteString( W, buf ) END;  
			NetTools.SendString( C, buf );  
			IF (query # NIL ) & (method = "GET") THEN 
				Strings.AppendCh( path, "?" );  i := 0;  
				WHILE path[i] # 0X DO INC( i ) END;  
				Texts.OpenReader( R, query, 0 );  Texts.Read( R, ch );  
				WHILE ~R.eot DO path[i] := ch;  INC( i );  Texts.Read( R, ch ) END;  
				path[i] := 0X;  key := HTTPDocs0.RegisterHTTPAdr( host, path, label, port )
			END 
		ELSE  (* gopher or ftp with proxy *)
			IF log THEN Texts.WriteString( W, buf ) END;  
			NetTools.SendString( C, buf )
		END;  
		IF (method = "GET") & (query # NIL ) THEN 
			NetSystem.Write( C, "?" );  Texts.OpenReader( R, query, 0 );  Texts.Read( R, ch );  
			WHILE ~R.eot DO NetSystem.Write( C, ch );  Texts.Read( R, ch ) END 
		END;  
		IF log THEN Texts.Append( Oberon.Log, W.buf ) END;  
		NetSystem.WriteString( C, " HTTP/1.0" );  NetSystem.WriteString( C, "Accept: *.*" );  
		NetTools.SendString( C, "Host: " );  NetSystem.WriteString( C, host );  
		IF IdentifyUser & NetTools.QueryString( "EMail", EMail ) THEN 
			NetTools.SendString( C, "From: " );  NetSystem.WriteString( C, EMail )
		END;  
		IF (HyperDocs.context # NIL ) & (HyperDocs.context.old # NIL ) THEN 
			NetTools.SendString( C, "Referer: " );  HyperDocs.RetrieveLink( HyperDocs.context.old.key, buf );  
			NetSystem.WriteString( C, buf )
		END;  
		IF aut # NIL THEN NetTools.SendString( C, "Authorization: Basic " );  NetSystem.WriteString( C, aut.coded ) END;  
		NetTools.SendString( C, "User-Agent: " );  NetSystem.WriteString( C, client );  
		cookie := FindCookie( cookies, host, path );  
		WHILE cookie # NIL DO 
			NetTools.SendString( C, "Cookie: " );  NetTools.SendString( C, cookie.name );  NetSystem.Write( C, "=" );  
			NetSystem.WriteString( C, cookie.val );  cookie := cookie.next;  cookie := FindCookie( cookie, host, path )
		END;  
		IF (method = "POST") & (query # NIL ) & (query.len > 0) THEN 
			NetSystem.WriteString( C, "Content-Type: application/x-www-form-urlencoded" );  
			NetTools.SendString( C, "Content-Length: " );  Strings.IntToStr( NetLen( query ), str );  
			NetSystem.WriteString( C, str );  NetTools.SendString( C, Strings.CRLF );  
			MIME.WriteText( query, 0, query.len, OpenStream( C ), MIME.textCont, FALSE, FALSE )
		END;  
		NetTools.SendString( C, Strings.CRLF );  NetTools.SendString( C, Strings.CRLF )
	END Request;  

	PROCEDURE Response*( VAR C: NetSystem.Connection;  key: LONGINT;  main: BOOLEAN;  VAR cont: MIME.Content;  
										  VAR location: ARRAY OF CHAR;  log: BOOLEAN ): LONGINT;  
	VAR pos, len, time, status: LONGINT;  base: HyperDocs.DefURL;  h: MIME.Header;  i: INTEGER;  
	BEGIN 
		NEW( base );  HyperDocs.RetrieveLink( key, buf );  
		key := HTTPDocs0.SplitHTTPAdr( buf, base.host, base.path, base.label, base.port );  status := 0;  
		COPY( "", location );  NEW( cont );  cont.typ := MIME.GetContentType( "text/plain" );  
		cont.encoding := MIME.EncBin;  cont.len := 0;  time := Input.Time() + NetTools.TimeOut;  
		REPEAT 
			IF log THEN HTTPDocs0.Wait() END;  
			len := NetSystem.Available( C )
		UNTIL (len > 0) OR ~NetTools.Connected( C, NetSystem.in ) OR NetTools.UserBreak() OR (Input.Time() - time > 0);  
		IF len <= 0 THEN 
			IF log THEN Texts.WriteString( W, " no response" );  Texts.WriteLn( W );  Texts.Append( Oberon.Log, W.buf ) END;  
			NetTools.Disconnect( C );  C := NIL;  RETURN status
		END;  
		NetSystem.ReadString( C, buf );  
		IF buf = "" THEN RETURN status
		ELSIF Strings.CAPPrefix( "HTTP", buf ) THEN 
			i := 0;  
			WHILE (buf[i] # 0X) & (buf[i] > " ") DO INC( i ) END;  
			Strings.StrToIntPos( buf, status, i );  
			IF ~main & ((status < 200) OR (status >= 400)) THEN 
				IF log THEN 
					Texts.WriteLn( W );  Texts.WriteString( W, buf );  Texts.WriteLn( W );  Texts.Append( Oberon.Log, W.buf )
				END;  
				NetTools.Disconnect( C );  C := NIL;  RETURN status
			ELSIF status = 204 THEN RETURN status
			END 
		ELSIF buf[0] = "<" THEN cont.typ := MIME.GetContentType( "text/html" );  buf := ""
		ELSE buf := ""
		END;  
		IF buf # "" THEN 
			MIME.ReadHeader( NetTools.OpenStream( C ), NIL , h, len );  pos := MIME.FindField( h, "Content-Type" );  
			IF pos > 0 THEN 
				MIME.ExtractContentType( h, pos, cont );  
				IF log THEN 
					Texts.Write( W, " " );  Texts.WriteString( W, cont.typ.typ );  Texts.Write( W, "/" );  
					Texts.WriteString( W, cont.typ.subTyp )
				END;  
				IF ~cont.typ.support THEN 
					IF ~log THEN 
						Texts.Write( W, " " );  Texts.WriteString( W, cont.typ.typ );  Texts.Write( W, "/" );  
						Texts.WriteString( W, cont.typ.subTyp )
					END;  
					Texts.WriteString( W, " not supported" );  
					(*Texts.WriteLn(W);*) Texts.Append( Oberon.Log, W.buf )
				END;  
				IF cont.typ.typ = "text" THEN 
					pos := MIME.FindField( h, "Content-Transfer-Encoding" );  MIME.TextEncoding( h, pos, cont )
				END 
			END;  
			pos := MIME.FindField( h, "Content-Length" );  
			IF pos > 0 THEN MIME.ExtractValue( h, pos, buf );  Strings.StrToInt( buf, cont.len ) END;  
			pos := MIME.FindField( h, "Location" );  
			IF (pos > 0) & (status >= 300) THEN 
				MIME.ExtractValue( h, pos, location );  
				IF Strings.Prefix( "http://http", location ) THEN 
					pos := 7;  
					WHILE location[pos] # 0X DO location[pos - 7] := location[pos];  INC( pos ) END 
				END 
			END;  
			pos := MIME.FindField( h, "Set-Cookie" );  
			IF pos > 0 THEN MIME.ExtractValue( h, pos, buf );  AddCookie( base.host, base.path, buf ) END 
		END;  
		IF log THEN Texts.WriteLn( W );  Texts.Append( Oberon.Log, W.buf ) END;  
		RETURN status
	END Response;  

	PROCEDURE Connect*( VAR C: NetSystem.Connection;  proxy: HTTPDocs0.Proxy;  main, waitR, reloc, block: BOOLEAN;  
									 method: ARRAY OF CHAR;  VAR key: LONGINT;  VAR cont: MIME.Content;  query: Texts.Text;  
									 log: BOOLEAN;  VAR useProxy: BOOLEAN ): LONGINT;  
	VAR status, key2: LONGINT;  
		location: ARRAY NetTools.MaxLine OF CHAR;  
		host: ARRAY NetTools.ServerStrLen OF CHAR;  
		base: HyperDocs.DefURL;  port: INTEGER;  
	BEGIN 
		status := 0;  HyperDocs.RetrieveLink( key, location );  NetTools.SplitHostPort( location, host, port );  
		useProxy := NetTools.UseProxy( host ) & (proxy # NIL );  
		IF ~useProxy THEN 
			IF port <= 0 THEN port := HTTPDocs0.DefPort END;  
			IF block THEN 
				IF ~NetTools.Connect( C, port, host, log ) THEN C := NIL END 
			ELSE 
				IF ~NetTools.AsyncConnect( C, port, host, log ) THEN C := NIL END 
			END 
		ELSE 
			IF block THEN 
				IF ~NetTools.Connect( C, proxy.port, proxy.host, FALSE ) THEN C := NIL END 
			ELSE 
				IF ~NetTools.AsyncConnect( C, proxy.port, proxy.host, FALSE ) THEN C := NIL END 
			END 
		END;  
		IF C # NIL THEN 
			IF log THEN Texts.Write( W, " " );  Texts.Append( Oberon.Log, W.buf ) END;  
			IF waitR THEN 
				Request( C, method, key, useProxy, query, log );  status := Response( C, key, main, cont, location, log );  
				IF C = NIL THEN RETURN status END;  
				IF reloc & (location # "") THEN 
					NEW( base );  base.key := key;  base.prefix := "http";  HyperDocs.RetrieveLink( base.key, buf );  
					key2 := HTTPDocs0.SplitHTTPAdr( buf, base.host, base.path, host, base.port );  
					key2 := HyperDocs.BuildKey( base, location );  
					IF key # key2 THEN 
						IF log THEN Texts.WriteString( W, "relocating " );  Texts.Append( Oberon.Log, W.buf ) END;  
						NetTools.Disconnect( C );  key := key2;  query := NIL;  COPY( "GET", method );  
						status := Connect( C, proxy, main, waitR, FALSE, block, method, key, cont, query, log, useProxy )
					END 
				END 
			END 
		END;  
		IF log THEN Texts.Append( Oberon.Log, W.buf ) END;  
		RETURN status
	END Connect;  

	(* polpo: http and https through the modules http and httpsPure (TLS 1.3 in Oberon), redirects
		followed; HTTPDocs0 and NetTools only for a proxy (HTTPProxy in Oberon.Text) *)

	PROCEDURE SplitURL( VAR url: ARRAY OF CHAR;  VAR secure: BOOLEAN;  VAR host, port, path: ARRAY OF CHAR ): BOOLEAN;  
	VAR i, j: LONGINT;  
	BEGIN 
		i := 0;  secure := FALSE;  
		WHILE (url[i] # 0X) & (url[i] # ":") DO INC( i ) END;  
		IF (url[i] # ":") OR (url[i + 1] # "/") OR (url[i + 2] # "/") THEN RETURN FALSE END;  
		IF (i = 5) & (CAP( url[4] ) = "S") THEN secure := TRUE ELSIF i # 4 THEN RETURN FALSE END;  
		INC( i, 3 );  j := 0;  
		IF url[i] = "[" THEN  (* [IPv6 address] *)
			INC( i );  
			WHILE (url[i] # 0X) & (url[i] # "]") & (j < LEN( host ) - 1) DO host[j] := url[i];  INC( i );  INC( j ) END;  
			IF url[i] = "]" THEN INC( i ) END 
		ELSE 
			WHILE (url[i] # 0X) & (url[i] # ":") & (url[i] # "/") & (j < LEN( host ) - 1) DO host[j] := url[i];  INC( i );  INC( j ) END 
		END;  
		host[j] := 0X;  j := 0;  
		IF url[i] = ":" THEN 
			INC( i );  
			WHILE (url[i] >= "0") & (url[i] <= "9") & (j < LEN( port ) - 1) DO port[j] := url[i];  INC( i );  INC( j ) END 
		END;  
		port[j] := 0X;  
		IF port[0] = 0X THEN 
			IF secure THEN COPY( "443", port ) ELSE COPY( "80", port ) END 
		END;  
		j := 0;  
		IF url[i] # "/" THEN path[0] := "/";  j := 1 END;  
		WHILE (url[i] # 0X) & (url[i] # "#") & (j < LEN( path ) - 1) DO path[j] := url[i];  INC( i );  INC( j ) END;  
		path[j] := 0X;  
		RETURN host[0] # 0X
	END SplitURL;  

	(* does s contain t, letters of any case *)
	PROCEDURE Has( VAR s: ARRAY OF CHAR;  t: ARRAY OF CHAR ): BOOLEAN;  
	VAR i, j: LONGINT;  
	BEGIN 
		i := 0;  
		WHILE s[i] # 0X DO 
			j := 0;  WHILE (t[j] # 0X) & (CAP( s[i + j] ) = CAP( t[j] )) DO INC( j ) END;  
			IF t[j] = 0X THEN RETURN TRUE END;  
			INC( i )
		END;  
		RETURN FALSE
	END Has;  

	(* the length of the UTF-8 sequence at b[i] (0: not one) and its code point *)
	PROCEDURE UTF8( VAR b: ARRAY OF CHAR;  i, len: LONGINT;  VAR code: LONGINT ): LONGINT;  
	VAR c, n, k: LONGINT;  
	BEGIN 
		c := ORD( b[i] );  
		IF c < 80H THEN code := c;  RETURN 1
		ELSIF c DIV 20H = 6 THEN code := c MOD 20H;  n := 2
		ELSIF c DIV 10H = 0EH THEN code := c MOD 10H;  n := 3
		ELSIF c DIV 8 = 1EH THEN code := c MOD 8;  n := 4
		ELSE RETURN 0
		END;  
		IF i + n > len THEN RETURN 0 END;  
		k := 1;  
		WHILE k < n DO 
			c := ORD( b[i + k] );  
			IF c DIV 40H # 2 THEN RETURN 0 END;  
			code := code * 40H + c MOD 40H;  INC( k )
		END;  
		RETURN n
	END UTF8;  

	PROCEDURE ValidUTF8( VAR b: ARRAY OF CHAR;  len: LONGINT ): BOOLEAN;  
	VAR i, n, code: LONGINT;  multi: BOOLEAN;  
	BEGIN 
		i := 0;  multi := FALSE;  
		WHILE i < len DO 
			n := UTF8( b, i, len, code );  
			IF n = 0 THEN RETURN FALSE END;  
			IF n > 1 THEN multi := TRUE END;  
			INC( i, n )
		END;  
		RETURN multi
	END ValidUTF8;  

	(* a character of the Oberon fonts for a code point: the accented letters they have, others
		without their accents, typographic punctuation as ASCII, else "?" *)
	PROCEDURE OberonChar( code: LONGINT ): CHAR;  
	VAR latin: ARRAY 65 OF CHAR;  ch: CHAR;  
	BEGIN 
		IF code < 80H THEN RETURN CHR( code )
		ELSIF (code >= 2002H) & (code <= 200AH) THEN RETURN " "
		ELSIF (code >= 201CH) & (code <= 201FH) THEN RETURN 22X
		ELSIF (code >= 2018H) & (code <= 201BH) OR (code = 2032H) THEN RETURN "'"
		ELSIF (code >= 2010H) & (code <= 2015H) OR (code = 2212H) THEN RETURN "-"
		ELSIF code = 2022H THEN RETURN "*"
		ELSIF code = 2026H THEN RETURN "."
		ELSIF code > 0FFH THEN RETURN "?"
		END;  
		CASE code OF 
		  0C4H: RETURN 80X
		| 0D6H: RETURN 81X
		| 0DCH: RETURN 82X
		| 0E4H: RETURN 83X
		| 0F6H: RETURN 84X
		| 0FCH: RETURN 85X
		| 0E2H: RETURN 86X
		| 0EAH: RETURN 87X
		| 0EEH: RETURN 88X
		| 0F4H: RETURN 89X
		| 0FBH: RETURN 8AX
		| 0E0H: RETURN 8BX
		| 0E8H: RETURN 8CX
		| 0ECH: RETURN 8DX
		| 0F2H: RETURN 8EX
		| 0F9H: RETURN 8FX
		| 0E9H: RETURN 90X
		| 0EBH: RETURN 91X
		| 0EFH: RETURN 92X
		| 0E7H: RETURN 93X
		| 0E1H: RETURN 94X
		| 0F1H: RETURN 95X
		| 0DFH: RETURN 96X
		| 0A0H: RETURN " "
		| 0ABH, 0BBH: RETURN 22X
		| 0B7H: RETURN "*"
		| 0A9H: RETURN "c"
		| 0AEH: RETURN "r"
		| 0D7H: RETURN "x"
		| 0C0H .. 0C3H, 0C5H .. 0D5H, 0D8H .. 0DBH, 0DDH, 0DEH, 0E3H, 0E5H, 0E6H, 0EDH, 0F0H, 0F3H, 0F5H, 0F8H, 0FAH, 0FDH .. 0FFH: 
			latin := "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYPsaaaaaaaceeeeiiiidnooooo/ouuuuypy";  
			ch := latin[code - 0C0H];  RETURN ch
		ELSE RETURN "?"
		END
	END OberonChar;  

	(* GET url (http or https), redirects followed; the body in a file without a name, doctype "text"
		(HTML) or "image"; NIL if there is no page *)
	PROCEDURE Fetch( url: ARRAY OF CHAR;  VAR doctype: ARRAY OF CHAR ): Files.File;  
	VAR h: http.Client;  body: strTypes.pstring;  F: Files.File;  R: Files.Rider;  
		host: ARRAY 256 OF CHAR;  port: ARRAY 8 OF CHAR;  path, u, v: ARRAY 1024 OF CHAR;  
		secure, utf8: BOOLEAN;  n, i, len, code: LONGINT;  
	BEGIN 
		COPY( "text", doctype );  COPY( url, u );  n := 0;  
		LOOP 
			IF ~SplitURL( u, secure, host, port, path ) THEN RETURN NIL END;  
			IF secure THEN h := httpsPure.Create( host, port, path ) ELSE h := http.Create( host, port, path ) END;  
			body := h.Get( h );  
			IF (body = NIL) OR (h.rspnCode < 300) OR (h.rspnCode >= 400) OR (h.rspnLocation = NIL) OR (n = 5) THEN EXIT END;  
			U.NewUrl( u, h.rspnLocation^, v );  COPY( v, u );  INC( n )
		END;  
		len := h.rspnContentLength;  utf8 := FALSE;  
		IF (body = NIL) OR (h.rspnCode < 200) OR (len <= 0) THEN RETURN NIL END;  (* the page of an error is shown too *)

		IF (h.rspnContentType # NIL) & Has( h.rspnContentType^, "image/" ) THEN COPY( "image", doctype )
		ELSIF (h.rspnContentType # NIL) & ~Has( h.rspnContentType^, "html" ) THEN RETURN Files.Old( "WebNotSupported.html" )
		ELSIF (h.rspnContentType # NIL) & Has( h.rspnContentType^, "charset" ) THEN utf8 := Has( h.rspnContentType^, "utf-8" )
		ELSE utf8 := ValidUTF8( body^, len )
		END;  
		F := Files.New( "" );  Files.Set( R, F, 0 );  i := 0;  
		WHILE i < len DO 
			IF utf8 THEN 
				n := UTF8( body^, i, len, code );  
				IF n = 0 THEN Files.Write( R, "?" );  INC( i ) ELSE Files.Write( R, OberonChar( code ) );  INC( i, n ) END 
			ELSE Files.Write( R, body[i] );  INC( i )
			END 
		END;  
		RETURN F
	END Fetch;  

	PROCEDURE RequestDoc*( url: ARRAY OF CHAR; VAR doctype: ARRAY OF CHAR ): Files.File;  
	VAR C: NetSystem.Connection;  cont: MIME.Content;  status: LONGINT;  T: Texts.Text;  F: Files.File;  R: Files.Rider;  
		i: LONGINT;  M: Objects.CopyMsg;  useProxy: BOOLEAN;  ch: CHAR;  
		key: LONGINT; t: ARRAY 16 OF CHAR;
	BEGIN 
		IF (HTTPDocs0.httpProxy = NIL) OR Strings.Prefix( "https:", url ) THEN RETURN Fetch( url, doctype ) END;  
		key := HyperDocs.BuildKey( NIL , url );  
		IF key = HyperDocs.UndefKey THEN RETURN NIL END;
		
		HyperDocs.Remember( key, NIL , HTTPDocs0.curNode ); 
		useProxy := TRUE;  
		status := 
			Connect( C, HTTPDocs0.httpProxy, TRUE, TRUE, TRUE, TRUE, "GET", key, cont, NIL , TRUE, useProxy );  
		IF C # NIL THEN 
			t := "text";
			IF status = 204 THEN RETURN NIL 
			ELSIF status = 401 THEN 
				IF F = NIL THEN 
					F := Files.Old( "Authorization.html" );  
					IF F = NIL THEN Out.String( "failed to read file 'Authorization.html'" );  HALT( 99 ) END 
				END;  
				RETURN F
			ELSIF cont.typ.support THEN 
				IF cont.typ.typ = "text" THEN 
					IF cont.typ.subTyp = "html" THEN 
						F := Files.New( "" );  Files.Set( R, F, 0 );  NetTools.ReadData( C, R, MAX( LONGINT ) );  
					ELSE F := Files.Old( "WebNotSupported.html" );  
					END 
				ELSIF cont.typ.typ = "file" THEN 
					(* don't request plain text files over network *) HALT( 55 )
				ELSIF cont.typ.typ = "image" THEN
					t := "image";
					F := Files.New( "" );  Files.Set( R, F, 0 );  NetTools.ReadData( C, R, MAX( LONGINT ) );  
				ELSE 
					F := Files.Old( "WebNotSupported.html" );
				END 
			ELSE 
				(* unsupported MIME type *)
				F := Files.Old( "WebNotSupported.html" );  
			END;  
			NetTools.Disconnect( C );  
			COPY( t, doctype ); RETURN F
		ELSE HALT( 57 )
		END 
	END RequestDoc;  

	PROCEDURE InitTables( );  
	VAR i, max: INTEGER;  
	BEGIN 
		max := ORD( "Z" ) - ORD( "A" );  
		FOR i := 0 TO max DO encTable[i] := CHR( i + ORD( "A" ) ) END;  
		INC( max );  
		FOR i := max TO max + ORD( "z" ) - ORD( "a" ) DO encTable[i] := CHR( i - max + ORD( "a" ) ) END;  
		max := max + ORD( "z" ) - ORD( "a" ) + 1;  
		FOR i := max TO max + ORD( "9" ) - ORD( "0" ) DO encTable[i] := CHR( i - max + ORD( "0" ) ) END;  
		encTable[62] := "+";  encTable[63] := "/"
	END InitTables;  

BEGIN 
	client := "Oberon WebNavDocs  on ";  Strings.Append( client, Kernel.version );  
	InitTables();  
	Texts.OpenWriter( W );  NEW( HTTPDocs0.httpProxy ); 
	NetTools.GetHostPort( "HTTPProxy", HTTPDocs0.httpProxy.host, HTTPDocs0.httpProxy.port, HTTPDocs0.DefPort );  
	IF HTTPDocs0.httpProxy.host = "" THEN HTTPDocs0.httpProxy := NIL END;  
	authorizations := NIL;  cookies := NIL 
END WebNetwork.