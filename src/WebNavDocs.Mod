MODULE WebNavDocs;  

IMPORT Display, Display3, Files, Objects, Gadgets, Panels, Documents, Desktops, Out, Oberon, Input, Attributes, 
	Effects, Strings, Format := WebCSS2Format, CSS2 := WebCSS2, CSS2P := WebCSS2P, CSS2B := WebCSS2B, 
	Pieces := WebPieces, HTML4 := WebHTML4, U := WebUtils, Texts, Network := WebNetwork;  

CONST 
	Menu = "WebNavDocs.Back[Back] WebNavDocs.Reload[Reload]";  
CONST 
	BarW = 17;  
	BorderWidth = 1;

TYPE 
	(* From ScrollViews.Mod *)
	Bar = RECORD 
			min, max, val: LONGINT;  
			backC, knoblen: INTEGER;  
			vertical: BOOLEAN
	END;  
	
	ustring = ARRAY 128 OF CHAR;  
	
	URL = POINTER TO URLDesc;  
	URLDesc = RECORD 
			next: URL;  
			url: ustring;  
	END;  
	
	HTMLDocument = POINTER TO HTMLDocumentDesc;  
	HTMLDocumentDesc = RECORD (Documents.DocumentDesc)
			url: ustring;  
			frChanged: BOOLEAN;
			history: URL
	END;  
	
	HTMLView* = POINTER TO HTMLViewDesc;  
	HTMLViewDesc* = RECORD (Gadgets.FrameDesc)
			links: CSS2B.Link;   (* HTML - Links *)
			anchors: CSS2B.Anchor;  
			body: HTML4.Element;  
			blocks: Format.Block;  
			boxes: CSS2B.Box;  
			vBar, hBar: Bar;  
			hasVBar, hasHBar: BOOLEAN;  
			border: INTEGER;  
			url: ustring; 
			name: ARRAY 64 OF CHAR;
			doc: HTMLDocument
	END;  

CONST 
	outofboundsmodify = 3;  

VAR 
	methods: Panels.Methods;  

	HTML4CSS: CSS2.StyleSheet;  

	W: Texts.Writer;  

	PROCEDURE Min( a, b: LONGINT ): LONGINT;  
	BEGIN 
		IF a < b THEN RETURN a ELSE RETURN b END 
	END Min;  

	PROCEDURE Max( a, b: LONGINT ): LONGINT;  
	BEGIN 
		IF a > b THEN RETURN a ELSE RETURN b END 
	END Max;  

	PROCEDURE ^DrawViewContent( v: HTMLView;  Q: Display3.Mask;  x, y, w, h: INTEGER );  

	PROCEDURE ^ConstructFrame( D: HTMLDocument; baseurl, dn, fn, size: ARRAY OF CHAR; bw: INTEGER ): Objects.Object;  
	
	PROCEDURE ^Solve( P: Panels.Panel;  W, H: INTEGER );
	
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

	PROCEDURE GetSource( url: ARRAY OF CHAR; VAR dtyp: ARRAY OF CHAR ): Files.File;  
	VAR f: Files.File;  R: Files.Rider;  key: LONGINT;  
		fname: ARRAY 128 OF CHAR;  
		i, j: INTEGER;  ch: CHAR;  
	BEGIN 
		COPY( "text", dtyp );
		IF pref( "file://", url ) THEN 
			i := 0;  j := 7;  
			REPEAT ch := url[i + 7];  fname[i] := ch;  INC( i ) UNTIL ch = 0X;  
			f := Files.Old( fname );  
		ELSE 
			f := Network.RequestDoc( url, dtyp );
		END;  
		IF f = NIL THEN 
			f := Files.Old( "WebNotFound.html" );  
			IF f = NIL THEN Out.String( "failed to read file 'WebNotFound.html'" );  Out.Ln  END 
		END;  
		RETURN f
	END GetSource;  

	PROCEDURE PushUrl( url: ARRAY OF CHAR;  D: HTMLDocument );  
	VAR e, sp, ep, sd, i, j: INTEGER;  docname: BOOLEAN;  u: URL;
	BEGIN 
		IF D.url # "" THEN 
			NEW( u );  u.next := D.history; 
			u.url := D.url; 
			D.frChanged := FALSE;
			D.history := u;  
		END;
		COPY( url, D.url )
	END PushUrl;  

	(* ----- HTMLView ----- *)
	
	PROCEDURE Value( VAR bar: Bar;  x, y, w, h, X, Y: INTEGER;  min, max: LONGINT ): LONGINT;  
	VAR res: LONGINT;  

		PROCEDURE CalcVal( x, w, bx, bw: INTEGER;  min, max: LONGINT ): LONGINT;  
		VAR r, d: LONGINT;  
		BEGIN 
			d := max - min;  
			IF (d = 0) OR (w = bw) THEN r := 0 
			ELSE 
				r := (bx - x - bw DIV 2)*d DIV (w - bw);  r := min + r;  
				IF min > max THEN d := max;  max := min;  min := d END;  
				IF r > max THEN r := max
				ELSIF r < min THEN r := min
				END 
			END;  
			RETURN r
		END CalcVal;  

	BEGIN 
		IF bar.vertical THEN res := CalcVal( y, h, Y, bar.knoblen, min, max ) 
		ELSE res := CalcVal( x, w, X, bar.knoblen, min, max )
		END;  
		RETURN res
	END Value;  

	PROCEDURE Pos( VAR bar: Bar;  x, y, w, h, bw: INTEGER;  min, max, val: LONGINT ): INTEGER;  
	VAR res: INTEGER;  

		PROCEDURE CalcPos( x, w, bw: INTEGER;  min, max, val: LONGINT ): INTEGER;  
		VAR d: LONGINT;  
		BEGIN 
			d := ABS( max - min );  
			IF d > 0 THEN 
				IF max > min THEN 
					IF val < min THEN val := min
					ELSIF val > max THEN val := max
					END 
				ELSE 
					IF val > min THEN val := min
					ELSIF val < max THEN val := max
					END 
				END;  
				val := ABS( val - min );  x := SHORT( x + val*(w - bw) DIV d )
			END;  
			RETURN x
		END CalcPos;  

	BEGIN 
		IF bar.vertical THEN res := CalcPos( y, h, bw, min, max, val ) ELSE res := CalcPos( x, w, bw, min, max, val ) END;  
		RETURN res
	END Pos;  

	PROCEDURE DrawKnob( Q: Display3.Mask;  x, y, w, h: INTEGER;  vertical: BOOLEAN );  
	BEGIN 
		Display3.FilledRect3D( Q, Display3.topC, Display3.bottomC, Display3.groupC, x, y, w, h, 1, Display3.replace );  
		IF vertical THEN 
			y := y + h DIV 2;  INC( x, 2 );  DEC( w, 4 );  
			Display3.ReplConst( Q, Display3.bottomC, x, y - 2, w, 1, Display.replace );  
			Display3.ReplConst( Q, Display3.topC, x, y - 1, w, 1, Display.replace );  
			Display3.ReplConst( Q, Display3.bottomC, x, y + 1, w, 1, Display.replace );  
			Display3.ReplConst( Q, Display3.topC, x, y + 2, w, 1, Display.replace )
		ELSE 
			x := x + w DIV 2;  INC( y, 2 );  DEC( h, 4 );  
			Display3.ReplConst( Q, Display3.topC, x - 2, y, 1, h, Display.replace );  
			Display3.ReplConst( Q, Display3.bottomC, x - 1, y, 1, h, Display.replace );  
			Display3.ReplConst( Q, Display3.topC, x + 1, y, 1, h, Display.replace );  
			Display3.ReplConst( Q, Display3.bottomC, x + 2, y, 1, h, Display.replace )
		END 
	END DrawKnob;  

	PROCEDURE DrawBar( Q: Display3.Mask;  VAR bar: Bar;  x, y, w, h: INTEGER );  
	BEGIN 
		Oberon.RemoveMarks( x, y, w, h );  
		Display3.FilledRect3D( Q, Display3.bottomC, Display3.topC, bar.backC, x, y, w, h, 1, Display.replace );  
		INC( x, 1 );  INC( y, 1 );  
		IF bar.vertical THEN  (* vertical *)
			DEC( w, 2 );  DEC( h, 2 );  y := Pos( bar, x, y, w, h, bar.knoblen, bar.min, bar.max, bar.val );  
			DrawKnob( Q, x, y, w, bar.knoblen, TRUE )
		ELSE  (* horizontal *)
			DEC( h, 2 );  DEC( w, 2 );  x := Pos( bar, x, y, w, h, bar.knoblen, bar.min, bar.max, bar.val );  
			DrawKnob( Q, x, y, bar.knoblen, h, FALSE )
		END 
	END DrawBar;  

	PROCEDURE TrackBar( v: HTMLView;  VAR M: Oberon.InputMsg;  VAR bar: Bar;  x, y, w, h: INTEGER );  
	VAR keysum: SET;  Q: Display3.Mask;  pos, npos, oldpos: LONGINT;  
	BEGIN 
		Gadgets.MakeMask( v, M.x + v.X, M.y + v.Y, M.dlink, Q );  Display3.Copy( Q, Q );  keysum := M.keys;  
		oldpos := bar.val;  pos := oldpos;  
		REPEAT 
			npos := Value( bar, x, y, w, h, M.X, M.Y, bar.min, bar.max );  
			IF npos # pos THEN  (* new position *)
				Oberon.FadeCursor( Oberon.Mouse );  bar.val := npos;  DrawBar( Q, bar, x, y, w, h );  
				DrawViewContent( v, Q, M.x + v.X, M.y + v.Y, v.W, v.H );  pos := npos
			END;  
			Input.Mouse( M.keys, M.X, M.Y );  keysum := keysum + M.keys;  
			Oberon.DrawCursor( Oberon.Mouse, Effects.FlatHand, M.X, M.Y )
		UNTIL M.keys = {};  
		IF keysum = {0, 1, 2} THEN 
			bar.val := oldpos;   (* AdjustChildToBar(F, bar) *)
		ELSE  (* UpdateBars(F); *) DrawBar( Q, bar, x, y, w, h )
		END;  
		M.res := 0
	END TrackBar;  

	PROCEDURE InitBar( VAR b: Bar;  min, max, val: LONGINT;  backC: INTEGER;  vertical: BOOLEAN;  width: LONGINT );  
	BEGIN 
		DEC( width, 2 );  b.min := min;  b.max := max;  b.val := val;  
		IF (val < min) & (val < max) THEN b.val := Min( min, max )
		ELSIF (val > max) & (val > min) THEN b.val := Max( min, max )
		END;  
		b.backC := backC;  b.vertical := vertical;  
		b.knoblen := SHORT( width - ABS( max - min ) );  
		IF b.knoblen < BarW THEN b.knoblen := BarW END 
	END InitBar;  

	PROCEDURE DrawViewContent( v: HTMLView;  Q: Display3.Mask;  x, y, w, h: INTEGER );  
	VAR Q2: Display3.Mask;  Y: INTEGER;  
	BEGIN 
		Y := y;  
		IF v.boxes # NIL THEN 
			NEW( Q2 );  Q2^ := Q^;  
			IF v.hasVBar THEN DEC( w, BarW ) END;  
			IF v.hasHBar THEN DEC( h, BarW );  INC( y, BarW ) END;  
			Display3.Intersect( Q2, x + v.border, y + v.border, w - 2*v.border, h - 2*v.border );  

			CSS2B.DrawBodyBackground( Q2, v.boxes, x + v.border, y + v.border, w - 2*v.border, h - 2*v.border );  
			CSS2B.Draw( Q2, v.boxes, -x - v.border + v.hBar.val, Y + v.H - 1 - v.border + v.vBar.val )
		END;  
	END DrawViewContent;  

	PROCEDURE RestoreView( v: HTMLView;  Q: Display3.Mask;  x, y, w, h: INTEGER;  changedSize: BOOLEAN );  
	VAR width, height: LONGINT;  
	BEGIN 
		Oberon.RemoveMarks( x, y, w, h );  
		IF changedSize THEN 
			width := v.W - 2*v.border - BarW;  
			v.boxes := CSS2B.Layout( v.blocks, width, height, v.links, v.anchors );  
			IF height <= v.H - 2*v.border THEN 
				v.hasVBar := FALSE;  width := v.W - 2*v.border;  
				v.boxes := CSS2B.Layout( v.blocks, width, height, v.links, v.anchors );  
				v.hasHBar := width > v.W - 2*v.border;  
				IF v.hasHBar THEN InitBar( v.hBar, 0, width - (v.W - 2*v.border), v.hBar.val, 13, FALSE, v.W - 2*v.border ) END 
			ELSE 
				v.hasVBar := TRUE;  v.hasHBar := width > v.W - 2*v.border - BarW;  
				IF v.hasHBar THEN 
					InitBar( v.hBar, 0, width - (v.W - 2*v.border - BarW), v.hBar.val, 13, FALSE, v.W - 2*v.border - BarW );  
					InitBar( v.vBar, height - (v.H - 2*v.border - BarW), 0, v.vBar.val, 13, TRUE, v.H - 2*v.border )
				ELSE 
					InitBar( v.vBar, height - (v.H - 2*v.border), 0, v.vBar.val, 13, TRUE, v.H - 2*v.border )
				END 
			END 
		END;  
		(* BG und Border *)
		Display3.ReplConst( Q, Display3.BG, x, y, w, h, Display.replace );  
		IF v.border > 0 THEN Display3.Rect3D( Q, Display3.topC, Display3.bottomC, x, y, w, h, v.border, Display.replace ) END;  
		(* ScrollBars *)
		IF v.hasVBar THEN DrawBar( Q, v.vBar, x + v.W - v.border - BarW, y + v.border, BarW, v.H - 2*v.border ) END;  
		IF v.hasHBar THEN 
			IF v.hasVBar THEN DrawBar( Q, v.hBar, x + v.border, y + v.border, v.W - 2*v.border - BarW, BarW );  
			ELSE DrawBar( Q, v.hBar, x + v.border, y + v.border, v.W - 2*v.border, BarW )
			END 
		END;  
		(* Inhalt *)
		DrawViewContent( v, Q, x, y, w, h );  
		(* Selected? *)
		IF Gadgets.selected IN v.state THEN 
			Display3.FillPattern( Q, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint )
		END 
	END RestoreView;  

	PROCEDURE OpenDoc( docname: ARRAY OF CHAR );  
	VAR text: Texts.Text;  res: INTEGER;  W: Texts.Writer;  
	BEGIN 
		Texts.OpenWriter( W );  NEW( text );  Texts.Open( text, "" );  Texts.Write( W, '"' );  
		Texts.WriteString( W, docname );  Texts.Write( W, '"' );  Texts.Append( text, W.buf );  
		Oberon.FadeCursor( Oberon.Pointer );  Oberon.Par.text := text;  Oberon.Par.pos := 0;  
		Oberon.Call( "Desktops.OpenDoc", Oberon.Par, FALSE, res )
	END OpenDoc;  

	PROCEDURE ReplaceChild( P: Panels.Panel; old, new: Display.Frame );
	VAR T, T0: Display.Frame; 
	BEGIN 
		T := P.dsc; T0 := NIL;
		WHILE (T # NIL) & (T # old) DO T0 := T; T := T.next END;
		new.next := T.next;
		IF T0 = NIL THEN P.dsc := new ELSE T0.next := new END;
	END ReplaceChild;
	
	PROCEDURE FindFrame( P: Panels.Panel; name: ARRAY OF CHAR; VAR F: Display.Frame ): BOOLEAN;
	BEGIN 
		F := P.dsc; 
		WHILE (F # NIL) & (F( HTMLView ).name # name) DO  F := F.next END;
		RETURN F # NIL
	END FindFrame;
	
	
	PROCEDURE ActivatedLink( M: Oberon.InputMsg;  F: HTMLView;  href, target: Pieces.Piece );  
	VAR 
		link: ustring;  docname, anchor: Pieces.Piece;  anchorPos: LONGINT;  obj: Objects.Object;  
		D: HTMLDocument;  u: URL;  fname, size: ARRAY 64 OF CHAR; TF: Display.Frame; P: Panels.Panel;
		d: Documents.Document;
	BEGIN 
		Pieces.SplitLink( href, docname, anchor );  Pieces.Convert( docname, link );  
		U.CleanURL( link );
		IF prefixed( link ) & ~pref( "file://", link ) & ~pref( "http://", link ) THEN OpenDoc( link );  RETURN END;  
		IF link # "" THEN 
			IF M.dlink IS Panels.Panel THEN 
				P := M.dlink( Panels.Panel );  Pieces.Convert( target, fname );
				IF (fname # "_top") & ((fname # "") & FindFrame( P, fname, TF ) OR ~prefixed( link )) THEN
					IF TF = NIL THEN TF := F END;
					Attributes.GetString( TF, "FrameSize", size );
					obj := ConstructFrame( F.doc, F.url, link, fname, size, 0 );
					IF obj # NIL THEN
						ReplaceChild( P, TF, obj( Display.Frame ) );
						Solve( P, P.W, P.H );
						F.doc.frChanged := TRUE;
						D := NIL
					END
				ELSE D := F.doc
				END
			ELSIF M.dlink IS HTMLDocument THEN D := M.dlink( HTMLDocument );  
			ELSE HALT( 100 )
			END;  
			IF D # NIL THEN
				obj := ConstructFrame( F.doc, F.url, link, "_top", "", BorderWidth );
				IF obj # NIL THEN
					Documents.Init( D, obj( Gadgets.Frame ) );
					IF obj IS Panels.Panel THEN  
						WITH obj: Panels.Panel DO Solve( obj, obj.W, obj.H ) END;
					END;
				ELSE D.history := D.history.next
				END
			END;
		ELSE obj := F
		END;  
		IF obj # NIL THEN 
			Gadgets.Update( obj ) ;
			IF obj IS HTMLView THEN 
				anchorPos := CSS2B.GetAnchorPos( obj( HTMLView ).anchors, anchor );  
				IF anchorPos > 0 THEN obj( HTMLView ).vBar.val := anchorPos;  Gadgets.Update( obj ) END 
			END 
		END
	END ActivatedLink;  

	PROCEDURE ViewHandler*( F: Objects.Object;  VAR M: Objects.ObjMsg );  
	VAR x, y, w, h, b: INTEGER;  Q: Display3.Mask;  keysum: SET;  target, href, endHref: Pieces.Piece;  
	BEGIN 
		WITH F: HTMLView DO 
			IF M IS Display.FrameMsg THEN 
				WITH M: Display.FrameMsg DO 
					IF (M.F = NIL ) OR (M.F = F) THEN  (* message addressed to this frame *)
						x := M.x + F.X;  y := M.y + F.Y;  w := F.W;  h := F.H;  
						IF M IS Display.DisplayMsg THEN 
							WITH M: Display.DisplayMsg DO 
								IF M.device = Display.screen THEN 
									IF (M.id = Display.full) OR (M.F = NIL ) THEN 
										Gadgets.MakeMask( F, x, y, M.dlink, Q );  RestoreView( F, Q, x, y, w, h, TRUE )
									ELSIF M.id = Display.area THEN 
										Gadgets.MakeMask( F, x, y, M.dlink, Q );  
										Display3.AdjustMask( Q, x + M.u, y + h - 1 + M.v, M.w, M.h );  
										RestoreView( F, Q, x, y, w, h, TRUE )
									END 
								END 
							END 
						ELSIF M IS Oberon.InputMsg THEN 
							WITH M: Oberon.InputMsg DO 
								IF ~(Gadgets.selected IN F.state) THEN 
									IF 1 IN M.keys THEN  (* middle *)
										b := F.border;  
										IF F.hasVBar & Effects.Inside( M.X, M.Y, x + F.W - b - BarW, y + b, BarW, F.H - 2*b ) THEN 
											TrackBar( F, M, F.vBar, x + F.W - b - BarW, y + b, BarW, F.H - 2*b )
										ELSIF F.hasHBar & Effects.Inside( M.X, M.Y, x + b, y + b, F.W - 2*b, BarW ) THEN 
											IF F.hasVBar THEN TrackBar( F, M, F.hBar, x + b, y + b, F.W - 2*b - BarW, BarW ) 
											ELSE TrackBar( F, M, F.hBar, x + b, y + b, F.W - 2*b, BarW )
											END 
										ELSIF Effects.Inside( M.X, M.Y, x + b, y + b, F.W - 2*b, F.H - 2*b ) THEN 
											CSS2B.OverLink( F.links, M.X - x + F.hBar.val, F.H - (M.Y - y) - 1 + F.vBar.val, href, target );  
											keysum := M.keys;  
											REPEAT 
												Effects.TrackMouse( M.keys, M.X, M.Y, Effects.FlatHand );  keysum := keysum + M.keys;  
											UNTIL M.keys = {};  
											CSS2B.OverLink( F.links, M.X - x + F.hBar.val, F.H - (M.Y - y) - 1 + F.vBar.val, endHref, 
																		target );  
											IF (keysum = {1}) & (href # NIL ) & (href = endHref) THEN 
												ActivatedLink( M, F, href, target )
											END;  
											Gadgets.framehandle( F, M )
										END 
									END 
								ELSE Gadgets.framehandle( F, M )
								END 
							END 
						ELSE Gadgets.framehandle( F, M )
						END 
					END 
				END 
			ELSIF M IS Objects.AttrMsg THEN 
				WITH M: Objects.AttrMsg DO 
					IF (M.id = Objects.get) & (M.name = "Gen") THEN 
						M.s := "WebNavDocs.NewHTMLView";  M.class := Objects.String;  M.res := 0
					ELSE Gadgets.framehandle( F, M )
					END 
				END 
			ELSIF M IS Objects.FileMsg THEN 
				(* no Load and Store for WebNavDocs *)
			ELSE Gadgets.framehandle( F, M )
			END 
		END 
	END ViewHandler;  

	PROCEDURE InitHTMLView( v: HTMLView );  
	BEGIN 
		v.handle := ViewHandler;  v.border := 0
	END InitHTMLView;  

	PROCEDURE NewHTMLView*;  
	VAR v: HTMLView;  
	BEGIN 
		NEW( v );  InitHTMLView( v );  Objects.NewObj := v
	END NewHTMLView;  
	
	
	(* -- Panels -- *)
	
	PROCEDURE Solve( P: Panels.Panel;  W, H: INTEGER );  
	VAR f: Display.Frame;  M: Display.ModifyMsg;  vertical: BOOLEAN;  
		size: ARRAY 10 OF CHAR;  
		val: INTEGER;  sum, asterixSum: INTEGER;  pos: INTEGER;  used, rest, total: INTEGER;  res: INTEGER;  
		border: LONGINT; bw: INTEGER; 

		PROCEDURE ConvertFrameSize;  
		BEGIN 
			Attributes.GetString( f, "FrameSize", size );  
			pos := 0;  val := 0;  
			WHILE (pos < Strings.Length( size )) & (size[pos] >= "0") & (size[pos] <= "9") & (val < MAX( INTEGER ) DIV 10) DO 
				val := val*10 + ORD( size[pos] ) - ORD( "0" );  INC( pos )
			END 
		END ConvertFrameSize;  

	BEGIN 
		Attributes.GetBool( P, "Vertical", vertical );  
		Attributes.GetInt( P, "Border", border ); bw := SHORT( border );
		DEC( H, 2*bw );  DEC( W, 2*bw );
		IF vertical THEN total := H  ELSE total := W  END;  
		rest := total; used := 0; 
		f := P.dsc;  
		WHILE f # NIL DO 
			ConvertFrameSize;  
			IF size[pos] = "*" THEN 
				IF val = 0 THEN INC( asterixSum ) ELSE asterixSum := asterixSum + val END 
			ELSIF size[pos] = "%" THEN sum := sum + SHORT( LONG( val )*LONG( total ) DIV 100 )
			ELSE sum := sum + val
			END;  
			f := f.next
		END;  
		f := P.dsc;  
		WHILE f # NIL DO 
			IF f.next = NIL THEN res := rest 
			ELSE 
				ConvertFrameSize;  
				IF sum > total THEN 
					IF size[pos] = "*" THEN res := 0;  
					ELSIF size[pos] = "%" THEN res := val*total DIV sum*total DIV 100
					ELSE res := SHORT( LONG( val )*LONG( total ) DIV sum )
					END;  
				ELSE 
					IF size[pos] = "*" THEN 
						IF val = 0 THEN val := 1 END;  
						res := (total - sum)*val DIV asterixSum
					ELSIF size[pos] = "%" THEN res := SHORT( LONG( total )*LONG( val ) DIV 100 )
					ELSE res := val
					END;  
				END;  
				DEC( rest, res );  
			END;  
			IF vertical THEN M.X := 0;  M.W := W;  M.Y := used - res + 1;  M.H := res;  used := used - res 
			ELSE M.X := used + bw;  M.W := res;  M.Y := -H  - bw + 1;  M.H := H;  used := used + res
			END;  
			IF (M.W > 0) & (M.H > 0) THEN  (* INC(M.X, dX); INC(M.Y, dY); *)
				M.id := outofboundsmodify;  M.F := f;  M.mode := Display.state; 
				M.dX := M.X - f.X;  M.dY := M.Y - f.Y;  
				M.dW := M.W - f.W;  M.dH := M.H - f.H;  
				Objects.Stamp( M );  M.res := -1;  M.dlink := NIL;  
				M.x := 0;  M.y := 0;  
				f.handle( f, M )
			END;  
			f := f.next
		END;  
	END Solve;  

	PROCEDURE PanelHandler*( F: Objects.Object;  VAR M: Objects.ObjMsg );  
	VAR f: Objects.Object;  
	BEGIN 
		WITH F: Panels.Panel DO 
			IF M IS Display.ModifyMsg THEN 
				WITH M: Display.ModifyMsg DO 
					IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN 
						Solve( F, M.W, M.H  );  Panels.PanelHandler( F, M )
					ELSIF Panels.IsChild( F, M.F ) & (M.id # outofboundsmodify) THEN  (* not send to self *)
						Solve( F, M.W, M.H );  Panels.PanelHandler( F, M )
					ELSE Panels.PanelHandler( F, M )
					END;  
				END 
			ELSIF M IS Gadgets.UpdateMsg THEN  (* when an attribute changes *)
				WITH M: Gadgets.UpdateMsg DO 
					Panels.PanelHandler( F, M );   (* forward *)
					f := M.obj;  
					IF (f IS Gadgets.Frame) & Panels.IsChild( F, f( Gadgets.Frame ) ) OR (f = F) THEN 
						WITH f: Gadgets.Frame DO Solve( F, F.W, F.H )
						END 
					END 
				END 
			ELSIF M IS Objects.AttrMsg THEN 
				WITH M: Objects.AttrMsg DO 
					IF (M.id = Objects.get) & (M.name = "Gen") THEN 
						M.s := "WebNavDocs.NewPanel";  M.class := Objects.String;  M.res := 0
					ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN 
						Panels.PanelHandler( F, M );  EXCL( F.state, Gadgets.lockedsize )
					ELSE Panels.PanelHandler( F, M )
					END 
				END 
			ELSE Panels.PanelHandler( F, M )
			END 
		END 
	END PanelHandler;  

	PROCEDURE InsertChild( F: Panels.Panel;  f: Display.Frame;  u, v: INTEGER );  
	VAR fs: ARRAY 16 OF CHAR;  
	BEGIN 
		Attributes.GetString( f, "FrameSize", fs );  
		IF fs = "" THEN Attributes.SetString( f, "FrameSize", "10%" ) END;  
		Panels.methods.InsertChild( F, f, u, v )
	END InsertChild;  

	PROCEDURE InitPanel*( F: Panels.Panel );  
	BEGIN 
		Panels.InitPanel( F );  
		F.handle := PanelHandler;  F.do := methods;  
		Attributes.SetBool( F, "Vertical", FALSE );  
		Attributes.SetBool( F, "Flat", FALSE );  
		Attributes.SetBool( F, "Locked", TRUE );  
	END InitPanel;  

	PROCEDURE NewPanel*;  
	VAR p: Panels.Panel;  
	BEGIN 
		NEW( p );  InitPanel( p );  Objects.NewObj := p
	END NewPanel;  
	
	(* -- Docs -- *)
	
	PROCEDURE ConstructFrame( D: HTMLDocument; baseurl, dn, fn, size: ARRAY OF CHAR; bw: INTEGER ): Objects.Object;  
	VAR url, burl, src: ustring;  html, head, base, body, frameSet: HTML4.Element;  obj: Objects.Object;  
		ppanel: Panels.Panel;  cols, rows, sizes: Pieces.Piece;  R: Files.Rider;  ch: CHAR;  pos: INTEGER;  
		frameSize, frameName: ARRAY 64 OF CHAR;  dtyp: ARRAY 16 OF CHAR;
		fr: HTML4.Object;  frame: HTMLView;  i, bpath: INTEGER;  p: Pieces.Piece;  
	BEGIN 
		U.NewUrl( baseurl, dn, url );
		IF fn = "_top" THEN PushUrl( url, D ) END; 
		
		html := HTML4.Read( GetSource( url, dtyp ) );
		
		IF dtyp # "text" THEN RETURN NIL END;
		
		head := HTML4.ThisChild( html, "HEAD" );  
		
		burl := url;
		IF head # NIL THEN 
			base := HTML4.ThisChild( head, "BASE" );  
			IF base # NIL THEN 
				p := HTML4.ThisAttribute( base, "href" );  
				IF p # NIL THEN Pieces.Convert( p, burl ) END 
			END 
		END;  
		
		body := HTML4.ThisChild( html, "BODY" );  frameSet := HTML4.ThisChild( html, "FRAMESET" );  
		IF frameSet # NIL THEN 
			obj := Gadgets.CreateObject( "WebNavDocs.NewPanel" );  
			ppanel := obj( Panels.Panel );  
			Attributes.SetInt( ppanel, "Border", bw );
			cols := HTML4.ThisAttribute( frameSet, "COLS" );  
			IF cols # NIL THEN 
				Attributes.SetBool( ppanel, "vertical", FALSE );  sizes := cols 
			ELSE 
				rows := HTML4.ThisAttribute( frameSet, "ROWS" );  
				IF rows # NIL THEN Attributes.SetBool( ppanel, "vertical", FALSE );  sizes := rows END 
			END;  
			IF sizes # NIL THEN 
				Files.Set( R, sizes.f, sizes.off );  Files.Read( R, ch );  fr := frameSet.objects;  
				WHILE fr # NIL DO 
					IF fr IS HTML4.Element THEN 
						WHILE ((ch < "0") OR (ch > "9")) & (ch # "*") DO Files.Read( R, ch ) END;  
						pos := 0;  
						WHILE (ch >= "0") & (ch <= "9") OR (ch = "%") OR (ch = "*") DO 
							frameSize[pos] := ch;  INC( pos );  Files.Read( R, ch )
						END;  
						frameSize[pos] := 0X;  
						Pieces.Convert( HTML4.ThisAttribute( fr( HTML4.Element ), "SRC" ), src );  
						Pieces.Convert( HTML4.ThisAttribute( fr( HTML4.Element ), "NAME" ), frameName ); 
						IF src # "" THEN 
							obj := ConstructFrame( D, burl, src, frameName, frameSize, 0 );  
							ppanel.do.InsertChild( ppanel, obj( Display.Frame ), 0, 0 )
						END;  
					END;  
					fr := fr.next;  
				END;  
				RETURN ppanel;  
			END 
		ELSIF body # NIL THEN 
			obj := Gadgets.CreateObject( "WebNavDocs.NewHTMLView" );  
			frame := obj( HTMLView );  
			
			Attributes.SetString( frame, "FrameSize", size ); 
			frame.body := body;  frame.border := bw;
			frame.url := burl;  COPY( fn, frame.name ); frame.doc := D;
			frame.blocks := Format.Traverse( body, HTML4CSS, burl );  
			RETURN frame;  
		END;  
		RETURN NIL 
	END ConstructFrame;  

	PROCEDURE DocLoad( D: Documents.Document );  
	VAR obj: Objects.Object;  u: URL;  
	BEGIN 
		IF D.name # "" THEN 
			obj := ConstructFrame( D(HTMLDocument), D.name, "", "_top", "", BorderWidth );  
			Documents.Init( D, obj( Gadgets.Frame ) );  
		ELSE  
			(* called by Desktops.Grow *)
		END;  
	END DocLoad;  

	PROCEDURE DocStore( D: Documents.Document );  
	BEGIN 
		Out.String( "Store not implemented for WebNavDocs" );  Out.Ln
	END DocStore;  

	PROCEDURE Back*;  
	VAR obj: Objects.Object;  D: Documents.Document;  
	BEGIN 
		D := Desktops.CurDoc( Gadgets.context );  
		IF D IS HTMLDocument THEN 
			WITH D: HTMLDocument DO 
				IF D.frChanged THEN  D.frChanged := FALSE
				ELSIF D.history # NIL THEN 
					D.url := D.history.url; D.history :=  D.history.next;  
				ELSE RETURN
				END;	
				obj := ConstructFrame( D, D.url, "", "", "", BorderWidth );
				Documents.Init( D, obj( Gadgets.Frame ) );  
				IF obj IS Panels.Panel THEN  
					WITH obj: Panels.Panel DO Solve( obj, obj.W, obj.H ) END
				END;
				Gadgets.Update( obj ); 
			END 
		END 
	END Back;  

	PROCEDURE Reload*;  
	VAR obj: Objects.Object;  
	BEGIN 
		Out.String( "Reload not yet implemented for WebNavDocs" );  Out.Ln
	END Reload;  

	PROCEDURE DocHandler( D: Objects.Object;  VAR M: Objects.ObjMsg );  
	BEGIN 
		WITH D: Documents.Document DO 
			IF M IS Objects.AttrMsg THEN 
				WITH M: Objects.AttrMsg DO 
					IF M.id = Objects.get THEN 
						IF M.name = "Gen" THEN M.class := Objects.String;  M.s := "WebNavDocs.NewDoc";  M.res := 0
						ELSIF M.name = "Adaptive" THEN M.class := Objects.Bool;  M.b := TRUE;  M.res := 0
						ELSIF M.name = "Icon" THEN M.class := Objects.String;  M.s := "Icons.Tool";  M.res := 0
						ELSE Documents.Handler( D, M )
						END 
					ELSE Documents.Handler( D, M )
					END 
				END 
			ELSIF M IS Objects.LinkMsg THEN 
				WITH M: Objects.LinkMsg DO 
					IF (M.id = Objects.get) & (M.name = "DeskMenu") THEN 
						M.obj := Gadgets.CopyPublicObject( "TestMenus.DeskMenu", TRUE );  
						IF M.obj = NIL THEN M.obj := Desktops.NewMenu( Menu ) END;  
						M.res := 0
					ELSIF (M.id = Objects.get) & (M.name = "SystemMenu") THEN 
						M.obj := Gadgets.CopyPublicObject( "TestMenus.DeskMenu", TRUE );  
						IF M.obj = NIL THEN M.obj := Desktops.NewMenu( Menu ) END;  
						M.res := 0
					ELSIF (M.id = Objects.get) & (M.name = "UserMenu") THEN 
						M.obj := Gadgets.CopyPublicObject( "TestMenus.DeskMenu", TRUE );  
						IF M.obj = NIL THEN M.obj := Desktops.NewMenu( Menu ) END;  
						M.res := 0
					ELSE Documents.Handler( D, M )
					END 
				END 
			ELSIF M IS Display.DisplayMsg THEN 
				WITH M: Display.DisplayMsg DO 
					IF (M.device = Display.printer) & (M.id = Display.contents) & (D.dsc # NIL ) THEN 
						(* print *)
					ELSE Documents.Handler( D, M )
					END 
				END 
			ELSE Documents.Handler( D, M )
			END 
		END 
	END DocHandler;  

	PROCEDURE NewDoc*;  
	VAR D: HTMLDocument;  
	BEGIN 
		NEW( D );  D.Load := DocLoad;  D.Store := DocStore;  D.handle := DocHandler;  D.W := 700;  D.H := 500;  
		D.history := NIL;  D.url := "";  Objects.NewObj := D;  
	END NewDoc;  

BEGIN 
	Texts.OpenWriter( W );  NEW( methods );  methods^ := Panels.methods^;  methods.InsertChild := InsertChild;  

	HTML4CSS := CSS2P.ReadStyleSheet( Files.Old( "WebHTML4.CSS" ), 0 );  

END WebNavDocs.	

Desktops.OpenDoc 	file://WebNavigatorAbout.html(WebNavDocs.NewDoc)
