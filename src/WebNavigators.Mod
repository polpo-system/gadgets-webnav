MODULE WebNavigators;  

IMPORT Display, Display3, Files, Objects, Gadgets, Panels, Out, Oberon, Attributes, Effects, Links, 
	CSS2F := WebCSS2Format, 
	CSS2 := WebCSS2, CSS2P := WebCSS2P, CSS2B := WebCSS2B, Pieces := WebPieces, HTML4 := WebHTML4, 
	Network := WebNetwork, Strings;  

(*
CONST
	yes = 0; no = 1; auto = 2 ; (* scrolling in Webframes *)
*)

CONST DefHomePage = "file://WebNavigatorAbout.html";

TYPE 
	Frame* = POINTER TO FrameDesc;  
	Panel = POINTER TO PanelDesc;  
	WebFrame = POINTER TO WebFrameDesc;  
	WebFrameSet = POINTER TO WebFrameSetDesc;  
	
	PanelDesc = RECORD (Panels.PanelDesc)
			webFrames: WebFrame;  
	END;  
	
	FrameDesc* = RECORD (Gadgets.FrameDesc)
			links: CSS2B.Link;  
			anchors: CSS2B.Anchor;  
			hBar, vBar: Gadgets.Frame;  
			hValue, vValue: Objects.Object;  
			(*href: Pieces.Piece;  *)
			body: HTML4.Element;  
			blocks: CSS2F.Block;  
			boxes: CSS2B.Box; 
			url: ARRAY 128 OF CHAR 
	END;  
	
	WebFrameDesc = RECORD 
			next: WebFrame;  
			name, href: Pieces.Piece;  
			(*border : BOOLEAN;*)
			(*noResize : BOOLEAN;*)
			(*scrolling : SHORTINT;*)
			(*marginWidth, marginHeight : INTEGER;*)
			frame: Frame;   	(* only if ~(WebFrame is WebFrameSet) *)
	END;  
	
	WebFrameSetDesc = RECORD (WebFrameDesc)
			lens: HTML4.Lengths;  
			vertical: BOOLEAN;  
			webFrames: WebFrame;  
	END;  

VAR 
	HTML4CSS: CSS2.StyleSheet;  f: Files.File;  

VAR 
	tmp: ARRAY 128 OF CHAR;
	homepage: Pieces.Piece; 

	PROCEDURE Max( a, b: LONGINT ): LONGINT;  
	BEGIN 
		IF a > b THEN RETURN a ELSE RETURN b END 
	END Max;  

	PROCEDURE ^NewWebFrameSet( frameSetElement: HTML4.Element;  name: Pieces.Piece ): WebFrame;  

	PROCEDURE ^Solve( P: Panel;  W, H: INTEGER;  mode: INTEGER );  

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

	PROCEDURE GetSource( url: ARRAY OF CHAR ): Files.File;  
	VAR f: Files.File;  R: Files.Rider;  key: LONGINT;  
		fname: ARRAY 128 OF CHAR;  
		i, j: INTEGER;  ch: CHAR;  
	BEGIN 
		IF pref( "file://", url ) THEN 
			i := 0;  j := 7;  
			REPEAT ch := url[i + 7];  fname[i] := ch;  INC( i ) UNTIL ch = 0X;  
			f := Files.Old( fname );  
		ELSE 
			f := Network.RequestDoc( url );
		END;  
		IF f = NIL THEN 
			f := Files.Old( "WebNotFound.html" );  
			IF f = NIL THEN Out.String( "failed to read file 'WebNotFound.html'" );  Out.Ln  END 
		END;  
		RETURN f
	END GetSource;  

	PROCEDURE NewWebFrame( src, name: Pieces.Piece ): WebFrame;  
	VAR 
		html, head, base, body, frameSet: HTML4.Element;  webFrame: WebFrame;  obj: Objects.Object;
		burl, dn, url: ARRAY 128 OF CHAR;
		i, bpath: INTEGER;  p: Pieces.Piece;
	BEGIN 
		Pieces.Convert( src, burl );  Pieces.Convert( name, dn ); 
		i := 0;  bpath := 0;  
		WHILE burl[i] # 0X DO 
			url[i] := burl[i];  
			IF (url[i] = '/') & (bpath = 0) & (url[i - 1] # ':') & (url[i - 1] # '/') THEN bpath := i END;  
			INC( i )
		END;  
		IF dn # "" THEN 
			IF dn[0] # '/' THEN 
				IF url[i - 1] # '/' THEN url[i] := '/';  INC( i ) END;  
				url[i] := 0X
			ELSE url[bpath] := 0X
			END;  
		END;  
		Strings.Append( url, dn );  
		
		html := HTML4.Read( GetSource( url ) );  
		body := HTML4.ThisChild( html, "BODY" );  
		frameSet := HTML4.ThisChild( html, "FRAMESET" );  
		head := HTML4.ThisChild( html, "HEAD" );  
		IF head # NIL THEN 
			base := HTML4.ThisChild( head, "BASE" );  
			IF base # NIL THEN 
				p := HTML4.ThisAttribute( base, "href" );  
				IF p # NIL THEN Pieces.Convert( p, burl ) END 
			END 
		END;  

		IF body # NIL THEN 
			NEW( webFrame );  
			webFrame.name := name;  
			obj := Gadgets.CreateObject( "WebNavigators.NewFrame" );  
			webFrame.frame := obj( Frame );  
			(*obj( Frame ).href := src;  *)	COPY( burl, obj( Frame ).url );
			obj( Frame ).body := body;  
			obj( Frame ).blocks := CSS2F.Traverse( body, HTML4CSS, burl );  
			IF obj( Frame ).blocks # NIL THEN Out.String( " blocks gefunden " ) END;  
			Out.Ln;  
			RETURN webFrame
		ELSIF frameSet # NIL THEN RETURN NewWebFrameSet( frameSet, name )
		ELSE RETURN NIL 
		END 
	END NewWebFrame;  

	PROCEDURE NewWebFrameSet( frameSetElement: HTML4.Element;  name: Pieces.Piece ): WebFrame;  
	VAR webFrameSet: WebFrameSet;  division: Pieces.Piece;  frame: HTML4.Object;  vertical: BOOLEAN;  
		webFrame, lastWebFrame: WebFrame;  
	BEGIN 
		division := HTML4.ThisAttribute( frameSetElement, "ROWS" );  vertical := TRUE;  
		IF division = NIL THEN division := HTML4.ThisAttribute( frameSetElement, "COLS" );  vertical := FALSE END;  
		IF division # NIL THEN 
			NEW( webFrameSet );  webFrameSet.name := name;  webFrameSet.vertical := vertical;  
			HTML4.DeleteLengths( webFrameSet.lens );  HTML4.AddMultiLength( division, webFrameSet.lens );  

			frame := frameSetElement.objects;  
			WHILE frame # NIL DO 
				webFrame := NIL;  
				IF (frame IS HTML4.Element) & (frame( HTML4.Element ).type.name = "FRAME") THEN 
					webFrame := NewWebFrame( HTML4.ThisAttribute( frame( HTML4.Element ), "SRC" ), 
																	  HTML4.ThisAttribute( frame( HTML4.Element ), "NAME" ) )
				ELSIF (frame IS HTML4.Element) & (frame( HTML4.Element ).type.name = "FRAMESET") THEN 
					webFrame := NewWebFrameSet( frame( HTML4.Element ), HTML4.ThisAttribute( frame( HTML4.Element ), 
																		   "NAME" ) );  
				END;  
				IF webFrame # NIL THEN 
					IF lastWebFrame = NIL THEN webFrameSet.webFrames := webFrame ELSE lastWebFrame.next := webFrame END;  
					lastWebFrame := webFrame
				END;  
				frame := frame.next
			END;  
			RETURN webFrameSet;  
		END;  
		RETURN NIL  (* ... ??? Framset - element without rows/cols-attribute .. *)
	END NewWebFrameSet;  

	PROCEDURE RestoreFrame( F: Frame;  Q: Display3.Mask;  x, y, w, h: INTEGER );  
	VAR vScroll, hScroll: LONGINT;  Q2: Display3.Mask;  
	BEGIN 
		Display3.Rect3D( Q, Display3.bottomC, Display3.topC, x, y, w, h, 1, Display.replace );  NEW( Q2 );  
		Q2^ := Q^;  Display3.Intersect( Q2, x + 1, y + 1, w - 2, h - 2 );  
		IF F.boxes # NIL THEN 
			CSS2B.DrawBodyBackground( Q2, F.boxes, x + 1, y + 1, w - 2, h - 2 );  
			Attributes.GetInt( F.vValue, "Value", vScroll );  Attributes.GetInt( F.hValue, "Value", hScroll );  
			CSS2B.Draw( Q2, F.boxes, -x - 1 + hScroll, y + F.H - 2 - vScroll )
		END;  
		
		IF Gadgets.selected IN F.state THEN 
			Display3.FillPattern( Q, Display3.white, Display3.selectpat, x, y, x, y, w, h, Display.paint )
		END 
	END RestoreFrame;  

	PROCEDURE DeleteWebFrame( P: Panel;  wf: WebFrame );  
	VAR subWebFrame: WebFrame;  
	BEGIN 
		IF wf IS WebFrameSet THEN 
			subWebFrame := wf( WebFrameSet ).webFrames;  
			WHILE subWebFrame # NIL DO DeleteWebFrame( P, subWebFrame );  subWebFrame := subWebFrame.next END 
		ELSE 
			IF Panels.IsChild( P, wf.frame.vBar ) THEN P.do.RemoveChild( P, wf.frame.vBar ) END;  
			IF Panels.IsChild( P, wf.frame.hBar ) THEN P.do.RemoveChild( P, wf.frame.hBar ) END;  
			IF Panels.IsChild( P, wf.frame ) THEN P.do.RemoveChild( P, wf.frame ) END;  
		END 
	END DeleteWebFrame;  

	PROCEDURE ReplaceWebFrame( P: Panel;  F: Frame;  name: Pieces.Piece;  newWebFrame: WebFrame );  
	VAR replaced: BOOLEAN;  

		PROCEDURE replaceWebFrame( webFrameSet: WebFrameSet );  
		VAR w: WebFrame;  
		BEGIN 
			IF webFrameSet.webFrames = NIL THEN RETURN END;  
			IF Pieces.CAPPieceCompare( name, webFrameSet.webFrames.name ) OR 
			    (name = NIL ) & (F = webFrameSet.webFrames.frame) THEN 
				newWebFrame.name := webFrameSet.webFrames.name;  
				DeleteWebFrame( P, webFrameSet.webFrames );  newWebFrame.next := webFrameSet.webFrames.next;  
				webFrameSet.webFrames := newWebFrame;  replaced := TRUE
			ELSE 
				w := webFrameSet.webFrames;  
				WHILE w.next # NIL DO 
					IF Pieces.CAPPieceCompare( name, w.next.name ) OR (name = NIL ) & (F = w.next.frame) THEN 
						newWebFrame.name := w.next.name;  DeleteWebFrame( P, w.next );  
						newWebFrame.next := w.next.next;  w.next := newWebFrame;  replaced := TRUE;  RETURN 
					END;  
					w := w.next
				END 
			END 
		END replaceWebFrame;  

	BEGIN 
		replaced := FALSE;  
		IF ~(P.webFrames IS WebFrameSet) OR 
		    (name # NIL ) & Pieces.CAPPieceCompare( name, P.webFrames.name ) OR (F = P.webFrames.frame) THEN 
			newWebFrame.name := P.webFrames.name;  DeleteWebFrame( P, P.webFrames );  
			P.webFrames := newWebFrame
		ELSE 
			replaceWebFrame( P.webFrames( WebFrameSet ) );  
			IF ~replaced THEN 
				newWebFrame.name := P.webFrames.name;  DeleteWebFrame( P, P.webFrames );  
				P.webFrames := newWebFrame
			END 
		END 
	END ReplaceWebFrame;  

	PROCEDURE ActivatedLink( F: Frame;  P: Panel;  url: Objects.Object;  href, target: Pieces.Piece );  
	VAR fileNameStr: ARRAY 64 OF CHAR;  
		targetStr: ARRAY 64 OF CHAR;  
		hrefStr: ARRAY 128 OF CHAR;  
		docname, anchor: Pieces.Piece;  anchorPos: LONGINT;  vBarMin: LONGINT;  webFrame: WebFrame;  
	BEGIN 
		Out.String( "ActivatedLink" );  
		Pieces.SplitLink( href, docname, anchor );  Pieces.Convert( docname, fileNameStr );  
		IF fileNameStr # "" THEN 
			webFrame := NewWebFrame( docname, NIL );  
			webFrame.href := href;  
			IF target # NIL THEN Pieces.Convert( target, targetStr ) END;  
			IF (targetStr = "_top") OR (F = NIL ) THEN 
				IF P.webFrames # NIL THEN webFrame.name := P.webFrames.name;  DeleteWebFrame( P, P.webFrames ) END;  
				P.webFrames := webFrame;  
			ELSE ReplaceWebFrame( P, F, target, webFrame );  
			END;  
			Solve( P, P.W, P.H, 0 );   (* mode ??? *)
			IF P.webFrames.frame.boxes = NIL THEN Out.String( " no boxes " ) END;  
			IF ~(webFrame IS WebFrameSet) THEN F := webFrame.frame END;  
		END;  
		Pieces.Convert( P.webFrames.href, hrefStr );  
		IF url # NIL THEN Attributes.SetString( url, "Value", hrefStr );  Gadgets.Update( url ) END;  
		IF F # NIL THEN 
			anchorPos := CSS2B.GetAnchorPos( F.anchors, anchor );  
			IF anchorPos > 0 THEN 
				Attributes.GetInt( F.vBar, "Min", vBarMin );  
				Attributes.SetInt( F.vBar, "Value", Max( -anchorPos, vBarMin ) );  
			END 
		END;  
		Gadgets.Update( P );  
		Out.String( "--" );  Out.Ln
	END ActivatedLink;  

	PROCEDURE FrameHandler*( F: Objects.Object;  VAR M: Objects.ObjMsg );  
	VAR x, y, w, h: INTEGER;  Q: Display3.Mask;  keysum: SET;  
		linkStr, oldLinkStr, fileName: ARRAY 64 OF CHAR;  
		vScroll, hScroll: LONGINT;  target, href, endHref: Pieces.Piece;  panel, organizer, status, url: Objects.Object;  
		f: Files.File;  W, H: LONGINT;  
	BEGIN 
		WITH F: Frame DO 
			IF M IS Display.FrameMsg THEN 
				WITH M: Display.FrameMsg DO 
					IF (M.F = NIL ) OR (M.F = F) THEN  (* message addressed to this frame *)
						x := M.x + F.X;  y := M.y + F.Y;  w := F.W;  h := F.H;  
						IF M IS Display.DisplayMsg THEN 
							WITH M: Display.DisplayMsg DO 
								IF M.device = Display.screen THEN 
									IF (M.id = Display.full) OR (M.F = NIL ) THEN 
										Gadgets.MakeMask( F, x, y, M.dlink, Q );  RestoreFrame( F, Q, x, y, w, h )
									ELSIF M.id = Display.area THEN 
										Gadgets.MakeMask( F, x, y, M.dlink, Q );  
										Display3.AdjustMask( Q, x + M.u, y + h - 1 + M.v, M.w, M.h );  
										RestoreFrame( F, Q, x, y, w, h )
									END 
								END 
							END 
						ELSIF M IS Oberon.InputMsg THEN 
							WITH M: Oberon.InputMsg DO 
								Attributes.GetInt( F.vValue, "Value", vScroll );  Attributes.GetInt( F.hValue, "Value", hScroll );  
								CSS2B.OverLink( F.links, M.X - x + hScroll, F.H - (M.Y - y) - 1 - vScroll, href, target );  
								IF href # NIL THEN Pieces.Convert( href, linkStr ) ELSE linkStr := "" END;  
								
								panel := M.dlink;  
								IF (panel # NIL ) & (panel.dlink # NIL ) THEN 
									organizer := panel.dlink;  status := Gadgets.FindObj( organizer, "status" );  
									url := Gadgets.FindObj( organizer, "url" );  Attributes.GetString( status, "Value", oldLinkStr );  
									IF oldLinkStr # linkStr THEN 
										Attributes.SetString( status, "Value", linkStr );  (* Gadgets.Update( status )   avoid trap! fld *)
									END;  
									
									IF (1 IN M.keys) & (href # NIL ) THEN 
										keysum := M.keys;  
										REPEAT Effects.TrackMouse( M.keys, M.X, M.Y, Effects.FlatHand );  keysum := keysum + M.keys;  
										UNTIL M.keys = {};  
										CSS2B.OverLink( F.links, M.X - x + hScroll, F.H - (M.Y - y) - 1 - vScroll, endHref, target );  
										IF (keysum = {1}) & (href = endHref) THEN ActivatedLink( F, panel( Panel ), url, href, target ) END 
									END 
								END 
							END;  
							Gadgets.framehandle( F, M )
						ELSIF M IS Gadgets.UpdateMsg THEN 
							WITH M: Gadgets.UpdateMsg DO 
								IF (M.obj = F.vValue) OR (M.obj = F.hValue) THEN 
									Gadgets.MakeMask( F, x, y, M.dlink, Q );  RestoreFrame( F, Q, x, y, w, h )
								END;  
							END;  
							Gadgets.framehandle( F, M )
						ELSE Gadgets.framehandle( F, M )
						END 
					END 
				END 
			ELSIF M IS Objects.AttrMsg THEN 
				WITH M: Objects.AttrMsg DO 
					IF (M.id = Objects.get) & (M.name = "Gen") THEN 
						M.s := "WebNavigators.NewFrame";  M.class := Objects.String;  M.res := 0
					ELSE Gadgets.framehandle( F, M )
					END 
				END 
(*		ELSIF M IS Objects.CopyMsg THEN 
				WITH M: Objects.CopyMsg DO 
					IF M.stamp = F.stamp THEN 
						M.obj := F.dlink (*non-first arrival*)
					ELSE  (*first arrival*)
						NEW( F1 );  F.stamp := M.stamp;  F.dlink := F1;  Copy( M, F, F1 );  M.obj := F1
					END 
				END *)
			ELSIF M IS Objects.FileMsg THEN 
(*			Gadgets.framehandle( F, M );  
				WITH M: Objects.FileMsg DO 
					IF M.id = Objects.store THEN Pieces.Write( M.R, F.href )
					ELSIF M.id = Objects.load THEN 
						Pieces.Read( M.R, F.href );  Pieces.Convert( F.href, fileName );  
						Out.String( "WebNavigators.FrameHandler: FileMsg (load)" ); Out.Ln;
						f := GetSource( fileName );
						F.body := HTML4.ThisChild( HTML4.Read( f ), "BODY" );  
						F.blocks := CSS2F.Traverse( F.body, HTML4CSS );  W := F.W;  H := F.H;  
						F.boxes := CSS2B.Layout( F.blocks, W, H, F.links, F.anchors );  
					END 
				END *)
			ELSE Gadgets.framehandle( F, M )
			END 
		END 
	END FrameHandler;  

	PROCEDURE Solve( P: Panel;  W, H: INTEGER;  mode: INTEGER );  

		PROCEDURE SolveWebFrame( webFrame: WebFrame;  x, y, w, h: INTEGER );  
		VAR child: WebFrame;  webFrameSet: WebFrameSet;  len: HTML4.Length;  l: INTEGER;  
			vScroll, hScroll: BOOLEAN;  width, height: LONGINT;  
		BEGIN 
			IF ~(webFrame IS WebFrameSet) THEN 
				width := w - 20;  
				webFrame.frame.boxes := 
					CSS2B.Layout( webFrame.frame.blocks, width, height,  webFrame.frame.links, webFrame.frame.anchors );  
				IF height <= h THEN 
					vScroll := FALSE;  width := w;  
					webFrame.frame.boxes := 
						CSS2B.Layout( webFrame.frame.blocks, width, height, webFrame.frame.links, webFrame.frame.anchors );  
					hScroll := width > w
				ELSE vScroll := TRUE;  hScroll := width > w - 20
				END;  
				IF vScroll THEN 
					webFrame.frame.vBar.X := x + w - 18;  webFrame.frame.vBar.Y := y;  webFrame.frame.vBar.W := 18;  
					webFrame.frame.vBar.H := h;  
					IF ~Panels.IsChild( P, webFrame.frame.vBar ) THEN 
						P.do.InsertChild( P, webFrame.frame.vBar, webFrame.frame.vBar.X, y )
					END;  
					IF hScroll THEN Attributes.SetInt( webFrame.frame.vBar, "Min", h - height - 18 )
					ELSE Attributes.SetInt( webFrame.frame.vBar, "Min", h - height )
					END;  
					Attributes.SetInt( webFrame.frame.vBar, "Max", 0 );  
					Attributes.SetInt( webFrame.frame.vBar, "StepSize", 8 (* h DIV 2 *) );  
					Attributes.SetBool( webFrame.frame.vBar, "HeavyDrag", TRUE );  
					webFrame.frame.hBar.W := w - 18;  webFrame.frame.W := w - 18;  
				ELSE 
					IF Panels.IsChild( P, webFrame.frame.vBar ) THEN P.do.RemoveChild( P, webFrame.frame.vBar ) END;  
					webFrame.frame.hBar.W := w;  webFrame.frame.W := w;  
				END;  
				IF hScroll THEN 
					webFrame.frame.hBar.X := x;  webFrame.frame.hBar.Y := y;  webFrame.frame.hBar.H := 18;  
					IF ~Panels.IsChild( P, webFrame.frame.hBar ) THEN 
						P.do.InsertChild( P, webFrame.frame.hBar, webFrame.frame.hBar.X, y )
					END;  
					IF vScroll THEN Attributes.SetInt( webFrame.frame.hBar, "Max", width - w + 18 );  
					ELSE Attributes.SetInt( webFrame.frame.hBar, "Max", width - w );  
					END;  
					Attributes.SetInt( webFrame.frame.hBar, "StepSize", 8 (* w DIV 2 *) );  
					Attributes.SetBool( webFrame.frame.hBar, "HeavyDrag", TRUE );  
					webFrame.frame.Y := y + 18;  webFrame.frame.H := h - 18;  
				ELSE 
					IF Panels.IsChild( P, webFrame.frame.hBar ) THEN P.do.RemoveChild( P, webFrame.frame.hBar ) END;  
					webFrame.frame.Y := y;  webFrame.frame.H := h;  
				END;  
				webFrame.frame.X := x;  
				IF ~Panels.IsChild( P, webFrame.frame ) THEN 
					Out.String( "insert Child" );  Out.Ln;  
					P.do.InsertChild( P, webFrame.frame, x, webFrame.frame.Y )
				END;  
				Attributes.SetInt( webFrame.frame.vValue, "Value", 0 );  
				Attributes.SetInt( webFrame.frame.hValue, "Value", 0 );  
			ELSE 
				webFrameSet := webFrame( WebFrameSet );  
				IF webFrameSet.vertical THEN 
					HTML4.CalcLengths( webFrameSet.lens, h );  child := webFrameSet.webFrames;  
					len := webFrameSet.lens.first;  l := h;  
					WHILE (child # NIL ) & (len # NIL ) DO 
						DEC( l, SHORT( len.len ) );  SolveWebFrame( child, x, y + l, w, SHORT( len.len ) );  child := child.next;  
						len := len.next
					END 
				ELSE 
					HTML4.CalcLengths( webFrameSet.lens, w );  child := webFrameSet.webFrames;  
					len := webFrameSet.lens.first;  l := 0;  
					WHILE (child # NIL ) & (len # NIL ) DO 
						SolveWebFrame( child, x + l, y, SHORT( len.len ), h );  INC( l, SHORT( len.len ) );  child := child.next;  
						len := len.next
					END 
				
				END 
			END;  
		END SolveWebFrame;  

	BEGIN 
		SolveWebFrame( P.webFrames, 0, -H + 1, W, H );  
	END Solve;  

	PROCEDURE PanelHandler*( F: Objects.Object;  VAR M: Objects.ObjMsg );  
	VAR mode: LONGINT;  f, url, urlModel: Objects.Object;  
		fileNameStr: ARRAY 64 OF CHAR;  
		fileNamePiece: Pieces.Piece;  
	BEGIN 
		WITH F: Panel DO 
			IF M IS Display.ModifyMsg THEN 
				WITH M: Display.ModifyMsg DO 
					IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN 
						IF ((M.dH = 0) OR (M.Y + M.H = F.Y + F.H)) & ((M.dW = 0) OR (M.X = F.X)) THEN 
							Solve( F, M.W, M.H, M.mode );  Panels.PanelHandler( F, M )
						ELSE 
							mode := M.mode;  M.mode := Display.state;  Panels.PanelHandler( F, M );  
							Solve( F, M.W, M.H, M.mode );  
							IF mode = Display.display THEN Gadgets.Update( F ) END 
						END 
					ELSE Panels.PanelHandler( F, M )
					END;  
				END 
			ELSIF M IS Gadgets.UpdateMsg THEN  (* when an attribute changes *)
				WITH M: Gadgets.UpdateMsg DO 
					Panels.PanelHandler( F, M );   (* forward *)
					f := M.obj;  url := Gadgets.FindObj( M.dlink, "url" );  Links.GetLink( url, "Model", urlModel );  
					IF f = urlModel THEN 
						Attributes.GetString( url, "Value", fileNameStr );  
						Pieces.ConvertToPiece( fileNamePiece, fileNameStr );  
						IF ~Pieces.CAPCompare( F.webFrames.href, fileNameStr ) THEN 
							ActivatedLink( NIL , F, url, fileNamePiece, NIL );  
						END 
					END 
				END 
			ELSIF M IS Objects.AttrMsg THEN 
				WITH M: Objects.AttrMsg DO 
					IF (M.id = Objects.get) & (M.name = "Gen") THEN 
						M.s := "WebNavigators.NewPanel";  M.class := Objects.String;  M.res := 0
					ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN 
						Panels.PanelHandler( F, M );  EXCL( F.state, Gadgets.lockedsize )
					ELSE Panels.PanelHandler( F, M )
					END 
				END 
			ELSE Panels.PanelHandler( F, M )
			END 
		END 
	END PanelHandler;  

	PROCEDURE Init*( F: Frame );  
	VAR obj: Objects.Object;  
	BEGIN 
		F.handle := FrameHandler;  

		F.hValue := Gadgets.CreateObject( "BasicGadgets.NewInteger" );  
		obj := Gadgets.CreateObject( "Scrollbars.New" );  F.hBar := obj( Gadgets.Frame );  
		Links.SetLink( F.hBar, "Model", F.hValue );  Attributes.SetBool( F.hBar, "Vertical", FALSE );  

		F.vValue := Gadgets.CreateObject( "BasicGadgets.NewInteger" );  
		obj := Gadgets.CreateObject( "Scrollbars.New" );  F.vBar := obj( Gadgets.Frame );  
		Links.SetLink( F.vBar, "Model", F.vValue );  
	END Init;  

	PROCEDURE NewFrame*;  
	VAR f: Frame;  
	BEGIN 
		NEW( f );  Init( f );  Objects.NewObj := f
	END NewFrame;  

	PROCEDURE InitPanel*( F: Panel );  
	BEGIN 
		Panels.InitPanel( F );  F.handle := PanelHandler;  
		ActivatedLink( NIL , F, NIL , homepage, NIL );  Solve( F, F.W, F.H, 0 )
	END InitPanel;  

	PROCEDURE NewPanel*;  
	VAR p: Panel;  
	BEGIN 
		NEW( p );  InitPanel( p );  Objects.NewObj := p
	END NewPanel;  

BEGIN 
	f := Files.Old( "WebHTML4.CSS" );  HTML4CSS := CSS2P.ReadStyleSheet( f, 0 );  
	tmp := DefHomePage;
	Pieces.ConvertToPiece( homepage, tmp ); 
END WebNavigators.