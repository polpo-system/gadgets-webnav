MODULE WebCSS2B;

IMPORT Fonts, Files, Display3, Display, Pictures, Objects, Strings, Out, 
		Format := WebCSS2Format, CSS2 := WebCSS2, Pieces := WebPieces ;

TYPE
	Box* = POINTER TO BoxDesc ;
	PictureBox = POINTER TO PictureBoxDesc ;
	(*InputBox = POINTER TO InputBoxDesc ;*)
	TextBox = POINTER TO TextBoxDesc ;
	ItemMarkerBox = POINTER TO ItemMarkerBoxDesc ;

	BoxDesc* = RECORD
		next : Box ;
		left, top, width, height : LONGINT;
		fixed : BOOLEAN;
		color : INTEGER;
		borderColor : ARRAY 4 OF INTEGER;
		borderStyle : ARRAY 4 OF SHORTINT;
		borderWidth : ARRAY 4 OF LONGINT;
		padding : ARRAY 4 OF LONGINT;
		font : Fonts.Font;
		
		backgroundFixed : BOOLEAN ;
		backgroundColor : INTEGER;
		backgroundImage : Pictures.Picture;
		backgroundPositionH, backgroundPositionV : LONGINT;
		backgroundRepeatH, backgroundRepeatV : BOOLEAN; 
 	END;
	
	PictureBoxDesc = RECORD (BoxDesc)
		picture : Pictures.Picture;
	END;
	
	(*InputBoxDesc = RECORD (BoxDesc)
		formElement : Objects.Object;
	END;*)
	
	TextBoxDesc = RECORD (BoxDesc)
		piece: Pieces.Piece ;
		textDecoration : SET;
		textDecorationColor : INTEGER;
		offset, len : LONGINT ;
	END;
	
	ItemMarkerBoxDesc = RECORD (BoxDesc)
		type : SHORTINT;
		counter : LONGINT;
		(*picture : Pictures.Picture;*)
	END;
	
TYPE
	Float = POINTER TO FloatDesc ;
	FloatDesc = RECORD ;
		next : Float ;
		top, bottom, left, right : LONGINT ;
	END;
	
TYPE
	Link* = POINTER TO LinkDesc;
	LinkDesc = RECORD
		next : Link;
		href, target : Pieces.Piece;
	END;
	
	LinkBox = POINTER TO LinkBoxDesc;
	LinkBoxDesc = RECORD (LinkDesc)
		box : Box
	END;
	
	Anchor* = POINTER TO AnchorDesc;
	AnchorDesc = RECORD
		next : Anchor;
		name : Pieces.Piece;
		top : LONGINT;
	END;
	
	
(*
CONST
	NaN = MAX(LONGINT);
	auto = MAX(LONGINT);
*)
	
PROCEDURE Max(a,b : LONGINT) : LONGINT;
BEGIN IF a>b THEN RETURN a ELSE RETURN b END END Max;

PROCEDURE Min(a,b : LONGINT) : LONGINT;
BEGIN IF a<b THEN RETURN a ELSE RETURN b END END Min;


PROCEDURE FindBest(color : LONGINT) : INTEGER;
(* Aus HTMLDocs.Mod, ginge wohl aber besser :) *)
VAR
	r, g, b, rr, gg, bb, i, bestC: INTEGER;
	diff, mdiff: REAL;
BEGIN
	IF color < 0 THEN RETURN -1 END;
	r := SHORT (color DIV (256 * 256)); g := SHORT((color MOD (256*256)) DIV 256); b := SHORT(color MOD 256);
	mdiff := MAX(REAL); bestC := 0;
	i := 0; WHILE (i < 256) & (mdiff > 0.0) DO
		Display.GetColor(i, rr, gg, bb);
		diff := LONG(rr-r)*LONG(rr-r)+LONG(gg-g)*LONG(gg-g)+LONG(bb-b)*LONG(bb-b);
		IF diff < mdiff THEN bestC := i; mdiff := diff END;
		INC(i)
	END; RETURN bestC
END FindBest;
		
(** --- Drawing --- *)

PROCEDURE HorizontalLine(M: Display3.Mask; left, right, y : INTEGER; color : INTEGER);
BEGIN Display3.ReplConst(M, color, left, y, right-left+1, 1, Display.replace)
END HorizontalLine;

PROCEDURE VerticalLine(M: Display3.Mask; x, top, bottom : INTEGER; color : INTEGER);
BEGIN Display3.ReplConst(M, color, x, bottom, 1, top-bottom+1, Display.replace)
END VerticalLine;

PROCEDURE HorizontalStyleLine(M: Display3.Mask; left, right, top, bottom : INTEGER; style : INTEGER; color : INTEGER);
VAR
	i, j : INTEGER;
	height : INTEGER;
	filled, nonfilled : INTEGER;

BEGIN
	height := top - bottom + 1;
	IF style = CSS2.solid THEN
		IF height > 0 THEN Display3.ReplConst(M, color, left, bottom, right-left+1, height, Display.replace) END;
	ELSIF style = CSS2.double THEN
		Display3.ReplConst(M, color, left, bottom, right-left+1, (height+1) DIV 3 -1, Display.replace);
		Display3.ReplConst(M, color, left, top - (height+1) DIV 3 -1, right-left+1, (height+1) DIV 3 -1, Display.replace);
	ELSIF (style = CSS2.dotted) OR (style = CSS2.dashed) THEN
		IF style = CSS2.dotted THEN
			filled := height; nonfilled := 2 * height
		ELSIF style = CSS2.dashed THEN
			filled := 4*height; nonfilled := 3*height
		END;
		IF height > 1 THEN
			i := left; LOOP
				j := 0; LOOP
					IF (j = filled) OR (i > right) THEN EXIT END;
					VerticalLine(M, i, top, bottom, color);
					INC(j); INC(i)
				END;
				j := 0; LOOP
					IF (j = nonfilled) OR (i > right) THEN EXIT END;
					INC(j); INC(i)
				END;
				IF i > right THEN EXIT END
			END
		ELSE
			i := left; LOOP
				j := 0; LOOP
					IF (j = filled) OR (i > right) THEN EXIT END;
					Display3.Dot(M, i, top, color, Display.replace);
					INC(j); INC(i);
				END;
				j := 0; LOOP
					IF (j = nonfilled) OR (i > right) THEN EXIT END;
					INC(j); INC(i)
				END;
				IF i > right THEN EXIT END
			END
		END
	END;
END HorizontalStyleLine;
		
PROCEDURE VerticalStyleLine(M: Display3.Mask; left, right, top, bottom : INTEGER; style : INTEGER; color : INTEGER);
VAR
	i, j : INTEGER;
	width : INTEGER;
	filled, nonfilled : INTEGER;

BEGIN
	width := right - left + 1;
	IF style = CSS2.solid THEN
		FOR i := 0 TO width-1 DO
			VerticalLine(M, left+i, top, bottom, color)
		END
	ELSIF style = CSS2.double THEN
		FOR i :=  0 TO (width+1) DIV 3 -1 DO
			VerticalLine(M, left+i, top, bottom + i, color)
		END;
		FOR i := width - (width+1) DIV 3 TO width-1 DO
			VerticalLine(M, left+i, top, bottom + i, color)
		END;
	ELSIF (style = CSS2.dotted) OR (style = CSS2.dashed) THEN
		IF style = CSS2.dotted THEN
			filled := width; nonfilled := 2 * width
		ELSIF style = CSS2.dashed THEN
			filled := 4*width; nonfilled := 3*width
		END;
		IF width > 1 THEN
			i := bottom; LOOP
				j := 0; LOOP
					IF (j = filled) OR (i > top) THEN EXIT END;
					HorizontalLine(M, left, right, i, color);
					INC(j); INC(i)
				END;
				j := 0; LOOP
					IF (j = nonfilled) OR (i > top) THEN EXIT END;
					INC(j); INC(i)
				END;
				IF i > top THEN EXIT END
			END
		ELSE
			i := bottom; LOOP
				j := 0; LOOP
					IF (j = filled) OR (i > top) THEN EXIT END;
					Display3.Dot(M, left, i, color, Display.replace);
					INC(j); INC(i);
				END;
				j := 0; LOOP
					IF (j = nonfilled) OR (i > top) THEN EXIT END;
					INC(j); INC(i)
				END;
				IF i > top THEN EXIT END
			END
		END
	END;
END VerticalStyleLine;

PROCEDURE DrawBorder(M: Display3.Mask; b : Box; xoffset, yoffset : LONGINT) ;
VAR top, right, bottom, left : LONGINT; 

	PROCEDURE TopLine(M: Display3.Mask; left, right, top, height : INTEGER; style : INTEGER; color : INTEGER);
	VAR i : INTEGER;
	BEGIN
		(* Dreiecke links und rechts *)
		i := 1; WHILE (i <= height) & (i <= b.borderWidth[CSS2.left]) DO
			HorizontalLine(M, left-i, left-1, top + i, color); INC(i)
		END;
		i := 1; WHILE (i <= height) & (i <= b.borderWidth[CSS2.right]) DO
			HorizontalLine(M, right + 1, right + i, top + i, color); INC(i)
		END;
		HorizontalStyleLine(M, left, right, top + height, top+1, style, color) ;
	END TopLine;
	
	PROCEDURE BottomLine(M: Display3.Mask; left, right, bottom, height : INTEGER; style : INTEGER; color : INTEGER);
	VAR i : INTEGER;
	BEGIN
		i := 1; WHILE (i <= height) & (i <= b.borderWidth[CSS2.left]) DO
			HorizontalLine(M, left-i, left-1, bottom  - i, color); INC(i)
		END;
		i := 1; WHILE (i <= height) & (i <= b.borderWidth[CSS2.right]) DO
			HorizontalLine(M, right + 1, right + i, bottom - i, color); INC(i)
		END;
		HorizontalStyleLine(M, left, right, bottom-1, bottom-height, style, color) ;
	END BottomLine;
	
	PROCEDURE LeftLine(M: Display3.Mask; left, top, bottom, width : INTEGER; style : INTEGER; color : INTEGER);
	VAR i : INTEGER;
	BEGIN
		i := 1; WHILE (i <= width) & (i <= b.borderWidth[CSS2.top]) DO
			VerticalLine(M, left-i, top+i, top+1, color); INC(i)
		END;
		i := 1; WHILE (i <= width) & (i <= b.borderWidth[CSS2.bottom]) DO
			VerticalLine(M, left-i, bottom-1, bottom- i, color); INC(i)
		END;
		VerticalStyleLine(M, left-width, left-1, top, bottom, style, color) ;
	END LeftLine;
	
	PROCEDURE RightLine(M: Display3.Mask; right, top, bottom, width : INTEGER; style : INTEGER; color : INTEGER);
	VAR i : INTEGER;
	BEGIN
		i := 1; WHILE (i <= width) & (i <= b.borderWidth[CSS2.top]) DO
			VerticalLine(M, right+i , top+i, top+1, color); INC(i)
		END;
		i := 1; WHILE (i <= width) & (i <= b.borderWidth[CSS2.bottom]) DO
			VerticalLine(M, right+i, bottom-1, bottom- i, color); INC(i)
		END;
		VerticalStyleLine(M, right+1, right+width, top, bottom, style, color) ;
	END RightLine;

BEGIN
	left := (b.left - b.padding[CSS2.left]) - xoffset; 
	right := ((b.left + b.width - 1) + b.padding[CSS2.right]) - xoffset;
	top := yoffset - (b.top - b.padding[CSS2.top]);
	bottom := yoffset - (b.top + b.height - 1 + b.padding[CSS2.bottom]);

	IF (left > MIN(INTEGER)) & (right < MAX(INTEGER)) THEN
		IF b.borderWidth[CSS2.top] > 0 THEN
			IF (top+b.borderWidth[CSS2.top] > MIN(INTEGER)) & (top < MAX(INTEGER)) THEN
				TopLine(M, SHORT(left), SHORT(right), SHORT(top), SHORT(b.borderWidth[CSS2.top]),
								b.borderStyle[CSS2.top], b.borderColor[CSS2.top])
			END
		END;
		IF b.borderWidth[CSS2.bottom] > 0 THEN
			IF (bottom > MIN(INTEGER)) & (bottom < MAX(INTEGER)) THEN
				BottomLine(M, SHORT(left), SHORT(right), SHORT(bottom), SHORT(b.borderWidth[CSS2.bottom]),
								b.borderStyle[CSS2.bottom], b.borderColor[CSS2.bottom])
			END
		END
	END;
	
	IF (bottom > MIN(INTEGER)) & (top < MAX(INTEGER)) THEN
		IF (b.borderWidth[CSS2.left] > 0) & (b.borderStyle[CSS2.left] # CSS2.none) THEN
			IF (left > MIN(INTEGER)) & (left < MAX(INTEGER)) THEN
				LeftLine(M, SHORT(left), SHORT(top), SHORT(bottom), SHORT(b.borderWidth[CSS2.left]),
					b.borderStyle[CSS2.left], b.borderColor[CSS2.left])
			END
		END;
		IF (b.borderWidth[CSS2.right] > 0) & (b.borderStyle[CSS2.right] # CSS2.none) THEN
			IF (right > MIN(INTEGER)) & (right < MAX(INTEGER)) THEN
				RightLine(M, SHORT(right), SHORT(top), SHORT(bottom), SHORT(b.borderWidth[CSS2.right]),
					b.borderStyle[CSS2.right], b.borderColor[CSS2.right])
			END
		END
	END
END DrawBorder;

PROCEDURE DrawBackground(M: Display3.Mask; b : Box; xoffset, yoffset : LONGINT) ;
VAR
	height : LONGINT; 
	topLine, bottomLine, i : LONGINT;
	L, B, W, H : LONGINT;
	mask : Display3.Mask;

	PROCEDURE DrawLeftToRight(top : LONGINT);
	VAR 
	leftPic, rightPic, i, width : LONGINT;
	
		PROCEDURE DrawPict(left, top : LONGINT); 
		VAR X, Y : LONGINT;
		BEGIN
			X := (b.left-b.padding[CSS2.left]) + left - xoffset;  Y := yoffset - ((b.top - b.padding[CSS2.top]) + b.backgroundImage.height -1) - top;
				
			IF (X > MIN(INTEGER)) & (X+b.backgroundImage.width < MAX(INTEGER)) &
				(Y > MIN(INTEGER)) & (Y+b.backgroundImage.height < MAX(INTEGER)) THEN
				
				Display3.Pict(mask, b.backgroundImage, 0, 0,  b.backgroundImage.width, b.backgroundImage.height, SHORT(X), SHORT(Y),  Display.replace)
			END
		END DrawPict;
		 

	BEGIN
		width := b.width + b.padding[CSS2.right]  + b.padding[CSS2.left] ;
		
		IF ~b.backgroundRepeatH THEN
			DrawPict(b.backgroundPositionH, top)
		 ELSE
			leftPic := b.backgroundPositionH - (b.backgroundPositionH DIV b.backgroundImage.width + 1) * b.backgroundImage.width;
			rightPic := leftPic + ((b.width + b.padding[CSS2.left]+b.padding[CSS2.right] ) DIV b.backgroundImage.width + 1) * b.backgroundImage.width ;
			
			i := leftPic ; WHILE i<= rightPic DO
				DrawPict(i, top);
				i := i + b.backgroundImage.width
			END
		END
	END DrawLeftToRight;
	

BEGIN	
	IF (b.backgroundImage # NIL) & (M # NIL) THEN

		height := b.height + b.padding[CSS2.bottom] +b.padding[CSS2.top];
		
		NEW(mask); mask^ := M^;
		Display3.Intersect(mask, SHORT(b.left - b.padding[CSS2.left] - xoffset), SHORT(yoffset - (b.top + b.height - 1 + b.padding[CSS2.bottom])),
							SHORT(b.width + b.padding[CSS2.left]+b.padding[CSS2.right]), SHORT(height));
			
		IF ~b.backgroundRepeatV THEN
			DrawLeftToRight(b.backgroundPositionV-b.padding[CSS2.top])
		 ELSE
			topLine :=  b.backgroundPositionV - (b.backgroundPositionV DIV b.backgroundImage.height + 1) * b.backgroundImage.height;
			bottomLine := topLine + ((b.top + b.height - 1 +b.padding[CSS2.bottom] - topLine + 1) DIV b.backgroundImage.height + 1) * b.backgroundImage.height ;
				
			i := topLine ; WHILE i<= bottomLine DO
				DrawLeftToRight(i);
				i := i + b.backgroundImage.height
			END
		END
	ELSE
		
		IF b.backgroundColor >= 0 THEN
			L := (b.left-b.padding[CSS2.left]) - xoffset; W := b.width + b.padding[CSS2.left] + b.padding[CSS2.right];
			B := yoffset - ((b.top + b.height -1) + b.padding[CSS2.bottom]); H := b.height + b.padding[CSS2.top] + b.padding[CSS2.bottom];
			IF (L > MIN(INTEGER)) & (L+W < MAX(INTEGER)) & (B > MIN(INTEGER)) & (B+H < MAX(INTEGER)) THEN
				Display3.ReplConst(M, b.backgroundColor, SHORT(L), SHORT(B), SHORT(W), SHORT(H), Display.replace)
			END
		END
		
	END
END DrawBackground;

PROCEDURE DrawBodyBackground*(M: Display3.Mask; bodyBox : Box; x, y, w, h : INTEGER);
BEGIN
	IF bodyBox.backgroundColor >= 0  THEN
		Display3.ReplConst(M, bodyBox.backgroundColor, x, y, w, h, Display.replace)
	ELSE
		Display3.ReplConst(M, 0, x, y, w, h, Display.replace)
	END
END DrawBodyBackground;

		

PROCEDURE DrawText(M: Display3.Mask; textBox : TextBox; mode: INTEGER; xoffset, yoffset : LONGINT); 
VAR
	R : Files.Rider ;
	r: Objects.Object;
	i: INTEGER;
	ch, prevch : CHAR ;
	x, y, base : INTEGER ;
	X,Y : LONGINT;
	
BEGIN
	X := textBox.left - xoffset ; Y := yoffset - textBox.top ;
	IF (X > MIN(INTEGER)) & (X+textBox.width < MAX(INTEGER)) & (Y-textBox.height > MIN(INTEGER)) & (Y < MAX(INTEGER))  THEN
		
		x := SHORT(X); y := SHORT(Y);

		IF textBox.piece # NIL THEN
			base := SHORT(Y - textBox.font.maxY); i := 0;
			Files.Set(R, textBox.piece.f, textBox.piece.off+textBox.offset); Files.Read(R, ch);
			IF (ch < " ") & (ch # CHR(29)) & (ch # CHR(28)) THEN ch := " " END; prevch := ch; (* 28 und 29 sind die Zeichen bei Listen *)
			WHILE (i < textBox.len) & ~R.eof DO
				textBox.font.GetObj(textBox.font,ORD(ch),r);
				WITH r: Fonts.Char DO
					Display3.CopyPattern(M, textBox.color , r.pat, x + r.x, base + r.y, mode ); INC(x, r.dx);
		   		(* IF isWhiteSpace(ch) THEN INC(x, textBox.wordSpacing) ELSE INC(x, textBox.letterSpacing) END ; *)
				END;
				INC(i);
				prevch := ch;
				Files.Read(R, ch);
				IF prevch = " " THEN WHILE ~R.eof & (ch <= " ") DO Files.Read(R, ch); INC(i) END END;
				IF ch < " " THEN ch := " " END
			END;
			
			IF CSS2.underline IN textBox.textDecoration THEN
				Display3.Line(M, textBox.textDecorationColor, Display.solid, SHORT(X), base-2, SHORT(X) + SHORT(textBox.width-1), base-2, 1, Display.replace)
			END;
			
			IF CSS2.overline IN textBox.textDecoration THEN
				Display3.Line(M, textBox.textDecorationColor, Display.solid, SHORT(X), SHORT(Y),
										SHORT(X) + SHORT(textBox.width-1), SHORT(Y), 1, Display.replace)
			END;
			
			IF CSS2.lineThrough IN textBox.textDecoration THEN
				Display3.Line(M, textBox.textDecorationColor, Display.solid, SHORT(X), base+textBox.font.maxY DIV 3,
										SHORT(X) + SHORT(textBox.width-1), base+textBox.font.maxY DIV 3, 1, Display.replace) (* .. Linienh„he sollte mit ex berechnet werden *)
			END
		END

	END
END DrawText;



PROCEDURE DrawPicture(M : Display3.Mask; p : PictureBox; xoffset, yoffset : LONGINT);
VAR X,Y : LONGINT;
BEGIN
	IF p.picture # NIL THEN
		X := p.left - xoffset ; Y := yoffset - (p.top + p.height -1) ;	
		IF (X > MIN(INTEGER)) & (X+p.picture.width < MAX(INTEGER)) & (Y > MIN(INTEGER)) & (Y+p.picture.height < MAX(INTEGER))  THEN
			Display3.Pict(M, p.picture, 0, 0,  p.picture.width, p.picture.height, SHORT(X), SHORT(Y),  Display.replace)
		END
	END
END DrawPicture;

PROCEDURE DrawItemMarker(M : Display3.Mask; m : ItemMarkerBox; xoffset, yoffset : LONGINT);
VAR
	X,Y : LONGINT;
	r : INTEGER;
	str : ARRAY 16 OF CHAR;
BEGIN
	r := SHORT(m.height DIV 2);
	X := m.left - xoffset ; Y := yoffset - m.top ;	
	IF (X > MIN(INTEGER)) & (X+m.width < MAX(INTEGER)) &
		(Y > MIN(INTEGER)) & (Y+m.width < MAX(INTEGER))  THEN
		
		CASE m.type OF
			   (* CSS2.disc : *)
			| CSS2.circle : 
				Display3.Circle(M, m.color, Display.solid, SHORT(X+r+(m.width - m.height) DIV 2), SHORT(Y+r), r, 1, {}, Display.replace);
			| CSS2.decimal :
				Strings.IntToStr(m.counter, str);
				Strings.Append(str, ".");
				Display3.String(M, m.color, SHORT(X+m.width DIV 3), SHORT(Y), m.font, str, Display.replace)
			ELSE (* sqaure *)
					Display3.Rect(M, m.color, Display.solid, SHORT(X+(m.width - m.height) DIV 2), SHORT(Y), 
						SHORT(m.height DIV 2), SHORT(m.height DIV 2), 1,  Display.replace) 
		END (* CASE *)
		
	END
END DrawItemMarker;



PROCEDURE Draw*(M : Display3.Mask; bl : Box; xoffset, yoffset : LONGINT); 
BEGIN
	WHILE bl # NIL DO
		DrawBorder(M, bl, xoffset, yoffset); 
		DrawBackground(M, bl, xoffset, yoffset);
		IF  bl IS TextBox THEN DrawText(M, bl(TextBox), Display.paint, xoffset, yoffset)
		ELSIF bl IS ItemMarkerBox THEN DrawItemMarker(M, bl(ItemMarkerBox), xoffset, yoffset)
		ELSIF bl IS PictureBox THEN DrawPicture(M, bl(PictureBox), xoffset, yoffset)
		END;
		bl := bl.next
	END; 
END Draw; 

(** --- Constructing --- *)
PROCEDURE Layout*(root : Format.Block; VAR width, height : LONGINT; VAR links : Link; VAR anchors : Anchor) : Box;

VAR
	leftFloats, rightFloats : Float;

VAR
	boxList, lastBox : Box;
	block : Format.Block;
	canvas : Box;
	margin : LONGINT;
	marginZeroArray : ARRAY 4 OF LONGINT;
	maxH, maxV : LONGINT;


	PROCEDURE CopyProperties(object : Format.Object; box : Box);
	VAR edge : SHORTINT;
	BEGIN
		box.backgroundFixed := object.backgroundFixed;
		box.backgroundColor := FindBest(object.backgroundColor);
		(* .. box.backgroundImage := object.backgroundImage;
		box.backgroundPositionH := object.backgroundPositionH;
		box.backgroundPositionV := object.backgroundPositionV; *)
		box.backgroundRepeatH := object.backgroundRepeatH;
		box.backgroundRepeatV := object.backgroundRepeatV;
		box.font := object.font;
		FOR edge := CSS2.top TO CSS2.left DO
			box.borderColor[edge] := FindBest(object.borderColor[edge]);
			box.borderStyle[edge] := object.borderStyle[edge];
		END;
		IF box IS TextBox THEN
			box(TextBox).textDecoration := object.textDecoration;
			box(TextBox).textDecorationColor := FindBest(object.textDecorationColor)
		END;
		IF box IS PictureBox THEN
			IF object IS Format.FloatImage THEN
				box(PictureBox).picture := object(Format.FloatImage).image
			END
		END
	END CopyProperties;
	
	PROCEDURE LeftAt(cB : Box; y : LONGINT) : LONGINT ; 
	VAR
		f : Float ;
		res : LONGINT ;
	BEGIN
		res := cB.left; f := leftFloats ; WHILE f # NIL DO
			IF (y <= f.bottom ) & (y >= f.top) & (f.right > res) THEN res := f.right END;
			f := f.next
		END; RETURN res
	END LeftAt;
	
	PROCEDURE RightAt(cB : Box; y : LONGINT) : LONGINT ; 
	VAR
		f : Float ;
		res : LONGINT;
	BEGIN
		res := cB.left + cB.width;  f := rightFloats; WHILE f # NIL DO
			IF (y <= f.bottom ) & (y >= f.top) & (f.left < res) THEN res := f.left END;
			f := f.next
		END; RETURN res
	END RightAt;
	
	PROCEDURE WidthAt(cB : Box; y : LONGINT) : LONGINT;
	BEGIN
		RETURN Min(cB.left + cB.width, RightAt(cB, y)) - Max(cB.left, LeftAt(cB, y))
	END WidthAt;
	
	PROCEDURE InsertFloat(top, bottom, edge : LONGINT; right : BOOLEAN);
	VAR f : Float;
	BEGIN
		NEW(f); f.top := top; f.bottom := bottom;
		IF right THEN
			f.left := edge;
			f.next := rightFloats; rightFloats := f
		ELSE
			f.right := edge;
			f.next := leftFloats; leftFloats := f
		END
	END InsertFloat;
	

	PROCEDURE AddBox(box : Box; href, target, aName : Pieces.Piece);
	VAR
		link : LinkBox;
		anchor : Anchor;
	BEGIN
		IF lastBox = NIL THEN boxList := box
		ELSE lastBox.next := box
		END; lastBox := box;
		IF href # NIL THEN
			NEW(link);
			link.href := href; link.target := target; link.box := box;
			link.next := links; links := link
		END;
		IF aName # NIL THEN
			NEW(anchor); anchor.top := box.top; anchor.name := aName;
			anchor.next := anchors; anchors := anchor
		END;
		maxH := Max(maxH, box.left+box.width-1+box.padding[CSS2.right]+box.borderWidth[CSS2.right]);
		maxV := Max(maxV, box.top+box.height-1+box.padding[CSS2.bottom]+box.borderWidth[CSS2.bottom])
	END AddBox;
	
	PROCEDURE FloatWidth(block : Format.Block; cB : Box; cBMargin : ARRAY OF LONGINT) : LONGINT;
	VAR width : LONGINT;
	BEGIN
		IF CSS2.Equal(block.width, "auto") THEN width := 0
		ELSE width := CSS2.CalcWidth(block.width, cB.width, block.font, cB.width);
		END;
		IF ~CSS2.Equal(block.margin[CSS2.left], "auto") THEN
			INC(width, CSS2.CalcWidth(block.margin[CSS2.left], cB.width, block.font, cBMargin[CSS2.left]))
		END;
		IF ~CSS2.Equal(block.margin[CSS2.right], "auto") THEN
			INC(width, CSS2.CalcWidth(block.margin[CSS2.right], cB.width, block.font, cBMargin[CSS2.right]))
		END;
		INC(width, CSS2.CalcBorderWidth(block.borderWidth[CSS2.left], block.font, cB.borderWidth[CSS2.left]));
		INC(width, CSS2.CalcBorderWidth(block.borderWidth[CSS2.right], block.font, cB.borderWidth[CSS2.right]));
		INC(width, CSS2.CalcWidth(block.padding[CSS2.left], cB.width, block.font, cB.padding[CSS2.left]));
		INC(width, CSS2.CalcWidth(block.padding[CSS2.right], cB.width, block.font, cB.padding[CSS2.right]));
		RETURN width
	END FloatWidth;
	
	PROCEDURE ^ HandleBlock(block : Format.Block; cB : Box; VAR full : LONGINT;
		VAR marginFromAbove : LONGINT; cBMargin : ARRAY OF LONGINT);
		
	PROCEDURE ^ HandleLines(linesBlock : Format.Block; cB : Box; cBMargin : ARRAY OF LONGINT) : LONGINT;
	
	PROCEDURE HandleTable(table : Format.Table; cB : Box; cBMargin : ARRAY OF LONGINT) : LONGINT ;

	VAR
		numberOfCols, numberOfAutoCols : LONGINT;
		col, c : Format.Col;
		row : Format.Row;
		cell : Format.Cell;
		cellBox : Box;
		dsc : Format.Block;
		tableFull, rowFull, rowHeight, dscMargin, boxFull : LONGINT;
		i, edge : LONGINT;
		minWidth : LONGINT;
		cellMinWidth, cellMaxWidth : LONGINT;
		cellsWidth : LONGINT; (* die Breite aller Zellen ( = Tabellenbreite - cellspacing ) *)
		actualMinWidth, actualMaxWidth : LONGINT;
		additionalMinWidth : LONGINT;
		additionalWidth : LONGINT;
		add, rest : LONGINT;
		colsMinWidth : LONGINT;
		tableWidth : LONGINT;
		lastAutoCol : Format.Col;
		borderSpacingX, borderSpacingY : LONGINT;
		widthWithBorders, heightWithBorders : LONGINT;
	
	BEGIN
		col := table.cols; numberOfCols := 0; minWidth := 0;
		WHILE col # NIL DO 
			INC(numberOfCols);
			col.auto := TRUE;
			IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
		END;
		borderSpacingX := CSS2.CalcWidth(table.borderSpacingX, cB.width, cB.font, 2);
		borderSpacingY := CSS2.CalcWidth(table.borderSpacingY, cB.width, cB.font, 2);
		cellsWidth := cB.width - (numberOfCols - 1) * borderSpacingX;

		row := table.rows;
		IF row = NIL THEN RETURN 0 END; (* .. *)
		WHILE row # NIL DO
			cell := row.cells;
			col := table.cols;
			
			WHILE cell # NIL DO
				cellMinWidth := cell.MinCW + 
					CSS2.CalcBorderWidth(cell.borderWidth[CSS2.left], cB.font, cB.borderWidth[CSS2.left]) +
					CSS2.CalcBorderWidth(cell.borderWidth[CSS2.right], cB.font, cB.borderWidth[CSS2.right]) +
					CSS2.CalcWidth(table.cellPadding, cB.width, cB.font, 0);
				IF (cell.minWidth # NIL) & ~CSS2.Equal(cell.minWidth, "auto") & ~CSS2.Equal(cell.minWidth, "inherit") THEN
					cellMinWidth := Max(cellMinWidth, CSS2.CalcWidth(cell.minWidth, cellsWidth, cB.font, 0))
				END;
				IF (cell.width # NIL) & ~CSS2.Equal(cell.width, "auto") & ~CSS2.Equal(cell.width, "inherit") THEN
					cellMinWidth := Max(cellMinWidth, CSS2.CalcWidth(cell.width, cellsWidth, cB.font, 0));
					IF cell.colspan = 1 THEN col.auto := FALSE END;
				END;
				
				cellMaxWidth := cell.MaxCW + 
					CSS2.CalcBorderWidth(cell.borderWidth[CSS2.left], cB.font, cB.borderWidth[CSS2.left]) +
					CSS2.CalcBorderWidth(cell.borderWidth[CSS2.right], cB.font, cB.borderWidth[CSS2.right]) +
					CSS2.CalcWidth(table.cellPadding, cB.width, cB.font, 0);
				IF (cell.width # NIL) & ~CSS2.Equal(cell.width, "auto") & ~CSS2.Equal(cell.width, "inherit") THEN
					cellMaxWidth := Max(cellMaxWidth, CSS2.CalcWidth(cell.width, cellsWidth, cB.font, 0))
				END;
				IF (cell.maxWidth # NIL) & ~CSS2.Equal(cell.maxWidth, "auto") & ~CSS2.Equal(cell.maxWidth, "inherit") THEN
					cellMaxWidth := Max(cellMaxWidth, CSS2.CalcWidth(cell.maxWidth, cellsWidth, cB.font, 0))
				END;

				actualMinWidth := 0; actualMaxWidth := 0; c := col;
				FOR i := 1 TO cell.colspan DO
					INC(actualMinWidth, c.minColWidth); INC(actualMaxWidth, c.maxColWidth);
					IF c.next # NIL THEN c := c.next(Format.Col) ELSE c := NIL END
				END;
				INC(actualMinWidth, (cell.colspan-1) * borderSpacingX);
				INC(actualMaxWidth, (cell.colspan-1) * borderSpacingX);
				
				IF actualMinWidth < cellMinWidth THEN
					c := col;
					additionalMinWidth := (cellMinWidth - actualMinWidth);
					rest := additionalMinWidth;
					FOR i := 1 TO cell.colspan DO
						IF c = NIL THEN HALT(100) END;
						IF i < cell.colspan THEN
							INC(c.minColWidth, additionalMinWidth DIV cell.colspan);
							DEC(rest, additionalMinWidth DIV cell.colspan);
						ELSE
							INC(c.minColWidth, rest);
						END;
						IF c.next # NIL THEN c := c.next(Format.Col) ELSE c := NIL END
					END
				END;
	
				IF cell.colspan = 1 THEN col.maxColWidth := Max(col.maxColWidth, cellMaxWidth) END;

				FOR i := 1 TO cell.colspan DO IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END END;
				
				IF cell.next # NIL THEN cell := cell.next(Format.Cell) ELSE cell := NIL END;
			END;
			
			IF row.next # NIL THEN row := row.next(Format.Row) ELSE row := NIL END
		END;

		colsMinWidth := 0; numberOfAutoCols := 0;
		col := table.cols; WHILE col # NIL DO
			INC(colsMinWidth, col.minColWidth);
			IF col.auto THEN INC(numberOfAutoCols); lastAutoCol := col END;
			IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
		END;
	
		INC(colsMinWidth, (numberOfCols+1) * borderSpacingX);
		
		IF colsMinWidth > cB.width THEN
			col := table.cols; WHILE col # NIL DO
				col.colWidth := col.minColWidth;
				IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
			END;
			
		ELSE
			IF numberOfAutoCols > 0 THEN
				additionalWidth := cB.width - colsMinWidth;
				rest := additionalWidth;
				col := table.cols; WHILE col # NIL DO
					IF col.auto THEN
						IF col # lastAutoCol THEN
							IF col.maxColWidth < col.minColWidth + (additionalWidth DIV numberOfAutoCols) THEN
								add := col.maxColWidth - col.minColWidth;
							ELSE
								add := additionalWidth DIV numberOfAutoCols
							END;
							col.colWidth := col.minColWidth + add;
							DEC(rest, add);
						ELSE
							IF col.maxColWidth < col.minColWidth + rest THEN
								add := col.maxColWidth - col.minColWidth;
							ELSE
								add := rest
							END;
							col.colWidth := col.minColWidth + add;
						END
					END;
					IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
				END
			END
		END;
		
		tableWidth := 0;
		col := table.cols; WHILE col # NIL DO
			col.remainingFromAbove := 0;
			INC(tableWidth, col.colWidth);
			IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
		END;
		INC(tableWidth, borderSpacingX * (numberOfCols + 1));
		cB.width := tableWidth;

		row := table.rows; tableFull := borderSpacingY;
		WHILE row # NIL DO
			cell := row.cells; rowHeight := 0; rowFull := 0; col := table.cols;
			
			WHILE cell # NIL DO
				WHILE col.remainingFromAbove > 0 DO
					INC(rowFull, col.colWidth + borderSpacingX);
					DEC(col.remainingFromAbove);
					IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := table.cols; rowFull := 0 END
				END;
				
				NEW(cellBox);
				CopyProperties(cell, cellBox);
				FOR edge := CSS2.top TO CSS2.left DO
					cellBox.borderWidth[edge] := CSS2.CalcBorderWidth(cell.borderWidth[edge], cB.font, cB.borderWidth[edge]);
					IF table.cellPadding # NIL THEN
						cellBox.padding[edge] := CSS2.CalcWidth(table.cellPadding, cB.width, cB.font, 0)
					END
				END; 
				
				INC(rowFull, borderSpacingX);
											
				IF cell.colspan < 1 THEN Out.String("TD : colspan < 1 !"); Out.Ln END;
				FOR i := 1 TO cell.colspan DO
					INC(cellBox.width, col.colWidth) ;
					IF i > 1 THEN INC(cellBox.width, borderSpacingX) END;
					col.remainingFromAbove := cell.rowspan - 1;
					IF col.next # NIL THEN col := col.next(Format.Col) ELSE col := NIL END
				END;
				cellBox.top := cB.top + tableFull + cellBox.borderWidth[CSS2.top] + cellBox.padding[CSS2.top];
				cellBox.left := cB.left + rowFull + cellBox.borderWidth[CSS2.left] + cellBox.padding[CSS2.left];
				widthWithBorders := cellBox.width;
				DEC(cellBox.width, 
					cellBox.borderWidth[CSS2.left] + cellBox.padding[CSS2.left] + cellBox.borderWidth[CSS2.right] + cellBox.padding[CSS2.right]);
				AddBox(cellBox, NIL, NIL, NIL);
				
				IF (cell.dsc # NIL) & (cell.dsc IS Format.Principal) THEN
					dscMargin := 0; boxFull := 0;
					dsc := cell.dsc(Format.Principal).dsc; WHILE dsc # NIL DO
						HandleBlock(dsc, cellBox, boxFull, dscMargin, cBMargin);
						IF dsc.next # NIL THEN dsc := dsc.next(Format.Block)
						ELSE dsc := NIL
						END
					END; cellBox.height := boxFull;
				ELSIF (cell.dsc # NIL) & (cell.dsc IS Format.Lines) THEN
					cellBox.height := HandleLines(cell, cellBox, cBMargin)
				END;
				
				INC(rowFull, widthWithBorders);
				
				heightWithBorders := cellBox.height + cellBox.borderWidth[CSS2.top] + cellBox.padding[CSS2.top] +
					cellBox.borderWidth[CSS2.bottom] + cellBox.padding[CSS2.bottom] ;
	
				IF heightWithBorders > rowHeight THEN rowHeight := heightWithBorders END;
		
				IF cell.next # NIL THEN cell := cell.next(Format.Cell) ELSE cell := NIL END;
			END;
			
			INC(tableFull, rowHeight + borderSpacingY);
			IF row.next # NIL THEN row := row.next(Format.Row) ELSE row := NIL END
		END;
		RETURN tableFull
	END HandleTable;
	
	PROCEDURE Marker(cB : Box; type : SHORTINT; overlength, margin : LONGINT; counter : LONGINT);
	VAR itemMarkerBox : ItemMarkerBox;
	BEGIN
		NEW(itemMarkerBox);
		itemMarkerBox.type := type; itemMarkerBox.counter := counter;
		itemMarkerBox.font := cB.font; itemMarkerBox.color := cB.color;
		itemMarkerBox.height := overlength;
		itemMarkerBox.width := margin;
		itemMarkerBox.top := cB.top + overlength;
		itemMarkerBox.left := cB.left - margin;
		AddBox(itemMarkerBox, NIL, NIL, NIL)
	END Marker;

			
	PROCEDURE HandleBlock(block : Format.Block; cB : Box; VAR full : LONGINT;
			VAR marginFromAbove : LONGINT; cBMargin : ARRAY OF LONGINT);
	
	VAR
		dsc : Format.Block;
		margin : ARRAY 4 OF LONGINT;
		edge : SHORTINT;
		pictureBox : PictureBox;
		box : Box;
		boxFull : LONGINT;
		dscMargin : LONGINT;


	BEGIN
		IF block IS Format.FloatImage THEN
			NEW(pictureBox);
			CopyProperties(block(Format.FloatImage), pictureBox);
			box := pictureBox
		ELSE
			NEW(box);
			CopyProperties(block, box)
		END;
		AddBox(box, block.href, block.target, block.anchor);
		
		FOR edge := CSS2.top TO CSS2.left DO
			box.borderWidth[edge] := CSS2.CalcBorderWidth(block.borderWidth[edge], block.font, cB.borderWidth[edge]);
			box.padding[edge] := CSS2.CalcWidth(block.padding[edge], cB.width, block.font, cB.padding[edge])
		END;
		margin[CSS2.top] := CSS2.CalcWidth(block.margin[CSS2.top], cB.width, block.font, cBMargin[CSS2.top]);
		margin[CSS2.bottom] := CSS2.CalcWidth(block.margin[CSS2.bottom], cB.width, block.font, cBMargin[CSS2.bottom]);
		(* cB.Width ist richtig. Siehe CSS2, 85 *)
		
		box.top := cB.top + full + Max(margin[CSS2.top]-marginFromAbove, 0) + box.borderWidth[CSS2.top] + box.padding[CSS2.top];
	
		IF ~(block IS Format.Float) THEN
			IF CSS2.Equal(block.width, "auto") THEN
				IF CSS2.Equal(block.margin[CSS2.left], "auto") THEN margin[CSS2.left] := 0
				ELSE margin[CSS2.left] := CSS2.CalcWidth(block.margin[CSS2.left], cB.width, block.font, cBMargin[CSS2.left])
				END;
				IF CSS2.Equal(block.margin[CSS2.right], "auto") THEN margin[CSS2.right] := 0
				ELSE margin[CSS2.right] := CSS2.CalcWidth(block.margin[CSS2.right], cB.width, block.font, cBMargin[CSS2.right])
				END;
				box.width := cB.width - margin[CSS2.left] - box.borderWidth[CSS2.left] - box.padding[CSS2.left] 
													- box.padding[CSS2.right] - box.borderWidth[CSS2.right] - margin[CSS2.right];
			ELSE
				box.width := CSS2.CalcWidth(block.width, cB.width, block.font, cB.width);
				IF CSS2.Equal(block.margin[CSS2.left], "auto") & CSS2.Equal(block.margin[CSS2.right], "auto") THEN
					margin[CSS2.left] := (cB.width - box.borderWidth[CSS2.left] - box.padding[CSS2.left] - box.width
																- box.padding[CSS2.right] - box.borderWidth[CSS2.right]) DIV 2;
					margin[CSS2.right] := (cB.width - box.borderWidth[CSS2.left] - box.padding[CSS2.left] - box.width
																- box.padding[CSS2.right] - box.borderWidth[CSS2.right]) - margin[CSS2.left]
				ELSIF CSS2.Equal(block.margin[CSS2.left], "auto") OR (~CSS2.Equal(block.margin[CSS2.right], "auto") & ~block.directionLTR) THEN
					margin[CSS2.right] := CSS2.CalcWidth(block.margin[CSS2.right], cB.width, block.font, cBMargin[CSS2.right]);
					margin[CSS2.left] := cB.width - box.borderWidth[CSS2.left] - box.padding[CSS2.left] - box.width
																- box.padding[CSS2.right] - box.borderWidth[CSS2.right] - margin[CSS2.right]
				ELSE
					margin[CSS2.left] := CSS2.CalcWidth(block.margin[CSS2.left], cB.width, block.font, cBMargin[CSS2.left]);
					margin[CSS2.right] := cB.width - margin[CSS2.left] - box.borderWidth[CSS2.left] - box.padding[CSS2.left] - box.width
																- box.padding[CSS2.right] - box.borderWidth[CSS2.right]
				END;					
			END;
			box.left := cB.left + margin[CSS2.left] + box.borderWidth[CSS2.left] + box.padding[CSS2.left];
		ELSE
			IF CSS2.Equal(block.width, "auto") THEN box.width := 0
			ELSE box.width := CSS2.CalcWidth(block.width, cB.width, block.font, cB.width);
			END;
			IF CSS2.Equal(block.margin[CSS2.left], "auto") THEN margin[CSS2.left] := 0;
			ELSE margin[CSS2.left] := CSS2.CalcWidth(block.margin[CSS2.left], cB.width, block.font, cBMargin[CSS2.left])
			END;
			IF CSS2.Equal(block.margin[CSS2.right], "auto") THEN margin[CSS2.right] := 0
			ELSE margin[CSS2.right] := CSS2.CalcWidth(block.margin[CSS2.right], cB.width, block.font, cBMargin[CSS2.right])
			END;

			IF ~CSS2.Equal(block.height, "auto") THEN
				(* .. Prozente sind ein wenig speziell. Siehe CSS2, 138, .. inherit auch *)
				box.height := CSS2.CalcWidth(block.height, 0, block.font, cB.height);
			ELSE
				box.height := 0; (* .. Das stimmt so nicht. Siehe CSS2, 10.6.3 *)
			END;
			
			IF block(Format.Float).floatRight THEN
				box.left := RightAt(cB, box.top) -
					margin[CSS2.right] - box.borderWidth[CSS2.right] - box.padding[CSS2.right] - box.width -
					box.padding[CSS2.left] - box.borderWidth[CSS2.left] - margin[CSS2.left]
			ELSE
				box.left := LeftAt(cB, box.top)
			END;
		END;
		
		box.font := block.font; box.color := FindBest(block.color);
	
		boxFull := 0;
		IF block IS Format.Table THEN
			box.height := HandleTable(block(Format.Table), box, margin)
		ELSIF (block.dsc # NIL) & (block.dsc IS Format.Principal) THEN
			dscMargin := 0;
			dsc := block.dsc(Format.Principal).dsc; WHILE dsc # NIL DO
				HandleBlock(dsc, box, boxFull, dscMargin, margin);
				IF dsc.next # NIL THEN dsc := dsc.next(Format.Block)
				ELSE dsc := NIL
				END
			END; box.height := boxFull;
		ELSIF (block.dsc # NIL) & (block.dsc IS Format.Lines) THEN box.height := HandleLines(block, box, margin)
		END;
					
		IF ~CSS2.Equal(block.height, "auto") THEN
			box.height := CSS2.CalcWidth(block.height, cB.height, block.font, cB.height)
		END;
		
		IF ~(block IS Format.Float) THEN
			INC(full, Max(margin[CSS2.top]-marginFromAbove, 0) + box.borderWidth[CSS2.top] + box.padding[CSS2.top] +
								box.height + margin[CSS2.bottom] + box.borderWidth[CSS2.bottom] + box.padding[CSS2.bottom]);
			marginFromAbove := margin[CSS2.bottom]
		ELSE
			IF block(Format.Float).floatRight THEN
				InsertFloat(box.top - box.padding[CSS2.top] - box.borderWidth[CSS2.top] - margin[CSS2.top],
					box.top + box.height - 1 + box.padding[CSS2.bottom] + box.borderWidth[CSS2.bottom] +
					margin[CSS2.bottom], box.left, TRUE)
			ELSE
				InsertFloat(box.top - box.padding[CSS2.top] - box.borderWidth[CSS2.top] - margin[CSS2.top],
					box.top + box.height - 1 + box.padding[CSS2.bottom] + box.borderWidth[CSS2.bottom] +
					margin[CSS2.bottom], box.left+box.width-1, FALSE)
			END
		END
	END HandleBlock;
	
	
	PROCEDURE HandleLines(linesBlock : Format.Block; cB : Box; cBMargin : ARRAY OF LONGINT) : LONGINT;
	
	TYPE
		BoxListNode = POINTER TO BoxListNodeDesc;
		BoxListNodeDesc = RECORD
			next : BoxListNode;
			box : Box;
			verticalAlignType : SET;
			overLength, underLength : LONGINT;
		END;
		
		FloatListNode = POINTER TO FloatListNodeDesc;
		FloatListNodeDesc = RECORD
			next : FloatListNode;
			float : Format.Block;
		END;
	
		
	VAR
		beforeOverlength, beforeUnderlength : LONGINT; (* the max before the Whitespace *)
		afterOverlength, afterUnderlength : LONGINT; (* the max after the Whitespace *)
		lineFilled, beforeLength, beforeLengthInInline, newStart, breakLen : LONGINT;
		breakPoint : BOOLEAN; (* Ist auf dieser Linie schon ein Break m„glich? *)
		breakOffset : LONGINT; (* an welchem Offset befindet sich die letzte Breakm„glichkeit? *)
		breakBox : BoxListNode; (* in welcher Box? *)
		breakBoxHref, breakBoxTarget : Pieces.Piece; (* Welcher Link war bei der m„glichen Bruchstelle aktiv? *)
		inline : Format.Inline;
		temp, overLength, underLength : LONGINT;
		textBox : TextBox;
		thisLinesBoxes, lastBoxOfThisLine : BoxListNode;
		height : LONGINT;
		off : LONGINT;
		ch, prevch : CHAR;
		dx : LONGINT;
		R : Files.Rider ;
		r : Objects.Object;
		margin, borderWidth, padding : ARRAY 4 OF LONGINT;
		edge : SHORTINT;
		float : Format.Float;
		heightCopy, dummy : LONGINT;
		firstLine : BOOLEAN;
		
		floatListNode : FloatListNode;
		floatList, lastOfFloatList : FloatListNode; 
		
		pictureBox : PictureBox;
		
		PROCEDURE AddBoxToThisLine(box : Box; verticalAlignType : SET; overLength, underLength : LONGINT);
		VAR
			boxListNode : BoxListNode;
		BEGIN
			NEW(boxListNode);
			boxListNode.box := box;
			boxListNode.verticalAlignType := verticalAlignType;
			boxListNode.overLength := overLength; boxListNode.underLength := underLength;
			IF thisLinesBoxes = NIL THEN
				thisLinesBoxes := boxListNode
			ELSE
				lastBoxOfThisLine.next := boxListNode
			END;
			lastBoxOfThisLine := boxListNode
		END AddBoxToThisLine;
		
		
		PROCEDURE MakeAlign;
		VAR
			boxListEntry : BoxListNode;
			hOffset : LONGINT;
		BEGIN
			IF CSS2.Equal(linesBlock.dsc(Format.Lines).textAlign, "right") THEN
				hOffset := cB.width - beforeLength
			ELSIF CSS2.Equal(linesBlock.dsc(Format.Lines).textAlign, "center") THEN
				hOffset := (cB.width - beforeLength) DIV 2
			ELSE
				hOffset := 0
			END; 
			
			boxListEntry := thisLinesBoxes;
			WHILE boxListEntry # NIL DO
				IF CSS2.normal IN boxListEntry.verticalAlignType THEN
					INC(boxListEntry.box.top, beforeOverlength-boxListEntry.overLength);
				ELSIF CSS2.top IN boxListEntry.verticalAlignType THEN
				ELSIF CSS2.bottom IN boxListEntry.verticalAlignType THEN
					INC(boxListEntry.box.top, beforeOverlength+beforeUnderlength-boxListEntry.overLength)
				ELSIF CSS2.middle IN boxListEntry.verticalAlignType THEN
					INC(boxListEntry.box.top,
							(beforeOverlength+beforeUnderlength-(boxListEntry.overLength+boxListEntry.underLength)) DIV 2)
				END;
				INC(boxListEntry.box.left, hOffset);
				boxListEntry := boxListEntry.next
			END;
		END MakeAlign;
		
		PROCEDURE InsertItemMarker;
		BEGIN
			IF ~(linesBlock IS Format.ListItem) THEN RETURN END;
			Marker(cB, linesBlock(Format.ListItem).listStyleType, beforeOverlength, 40, linesBlock(Format.ListItem).counter);
		END InsertItemMarker;
	
		PROCEDURE InsertRemainingFloats(height : LONGINT);
		BEGIN
			WHILE floatList # NIL DO
				HandleBlock(floatList.float, cB, height, dummy, margin);
				floatList := floatList.next
			END (* floatList := NIL *)
		END InsertRemainingFloats;
		
		PROCEDURE Break;
		VAR
			newLineBoxListEntry : BoxListNode;
			boxListEntry : BoxListNode;
			newLineTextBox : TextBox;
			lineHeight : LONGINT;
			
		BEGIN
			IF breakBox.box IS TextBox THEN
				(* split the box in which occurs the space *)
				NEW(newLineTextBox);
				newLineTextBox^ := breakBox.box(TextBox)^;
				DEC(newLineTextBox.len, breakOffset - newLineTextBox.offset + 1);
				newLineTextBox.offset := breakOffset + 1;
				DEC(newLineTextBox.width, beforeLengthInInline + breakLen);
				newLineTextBox.left := LeftAt(cB, cB.top + height)+newStart;
				newLineTextBox.borderWidth[CSS2.left] := 0;
				newLineTextBox.borderStyle[CSS2.left] := CSS2.none;
				
				AddBox(newLineTextBox, breakBoxHref, breakBoxTarget, NIL);
				textBox := newLineTextBox;
	
				NEW(newLineBoxListEntry);
				newLineBoxListEntry.box := newLineTextBox;
				newLineBoxListEntry.verticalAlignType := breakBox.verticalAlignType;
				newLineBoxListEntry.overLength := breakBox.overLength;
				newLineBoxListEntry.underLength := breakBox.underLength;
				newLineBoxListEntry.next := breakBox.next;
				
				breakBox.box(TextBox).len := breakOffset - breakBox.box(TextBox).offset;
				breakBox.box.width := beforeLengthInInline ;
				breakBox.box.borderWidth[CSS2.right] := 0;
				breakBox.box.borderStyle[CSS2.right] := CSS2.none;
				breakBox.next := NIL;
				
				boxListEntry := newLineBoxListEntry;
			ELSIF breakBox.box IS PictureBox THEN
				newLineBoxListEntry := breakBox;
				boxListEntry := newLineBoxListEntry.next;
				breakBox.next := NIL
			END;

			(* Set old line *)
			MakeAlign;
			IF firstLine THEN InsertItemMarker; firstLine := FALSE END;
		
			InsertRemainingFloats(height + lineHeight);
		
			(* Move the rest *)
			lineHeight := beforeOverlength + beforeUnderlength;
			WHILE boxListEntry # NIL DO
				DEC(boxListEntry.box.left, newStart+LeftAt(cB, cB.top+height)-LeftAt(cB, cB.top+height+lineHeight));
				INC(boxListEntry.box.top, lineHeight);
				boxListEntry := boxListEntry.next
			END;
			
			thisLinesBoxes := newLineBoxListEntry;
			lastBoxOfThisLine := newLineBoxListEntry;
			IF thisLinesBoxes # NIL THEN
				WHILE lastBoxOfThisLine.next # NIL DO lastBoxOfThisLine := lastBoxOfThisLine.next END
			END;
			
			INC(height, lineHeight);
			DEC(lineFilled, beforeLength + breakLen);
			breakPoint := FALSE;
			beforeOverlength := afterOverlength; beforeUnderlength := afterUnderlength;
			afterOverlength := 0; afterUnderlength := 0;
		END Break;
		
		PROCEDURE ForcedBreak;
		BEGIN
			beforeOverlength := Max(beforeOverlength, afterOverlength);
			beforeUnderlength := Max(beforeUnderlength, afterUnderlength);
			beforeLength := Max(beforeLength, lineFilled);
			MakeAlign;
			IF firstLine THEN InsertItemMarker END;
			thisLinesBoxes := NIL; lastBoxOfThisLine := NIL;
			INC(height, beforeOverlength + beforeUnderlength);
			lineFilled := 0; beforeLength := 0; breakPoint := FALSE;
			beforeOverlength := 0; beforeUnderlength := 0;
			afterOverlength := 0; afterUnderlength := 0;
			InsertRemainingFloats(height)
		END ForcedBreak;
	
	BEGIN
		breakPoint := FALSE; firstLine := TRUE;
		inline := linesBlock.dsc(Format.Lines).inlines;
		WHILE inline # NIL DO
			FOR edge := CSS2.top TO CSS2.left DO
				borderWidth[edge] := CSS2.CalcBorderWidth(inline.borderWidth[edge], inline.font, cB.borderWidth[edge]);
				padding[edge] := CSS2.CalcWidth(inline.padding[edge], cB.width, inline.font, cB.padding[edge]);
				margin[edge] := CSS2.CalcWidth(inline.margin[edge], cB.width, inline.font, cBMargin[edge]) ;
			END;

			(* Vergr„ssere wenn n„tig die zur Verf…gung stehende Ober- und Unterlƒnge *)
			IF inline IS Format.Image THEN
				overLength := CSS2.CalcWidth(inline.height, cB.width, inline.font, 0) ;
				underLength := 0
			ELSIF ~(inline IS Format.Break) & ~(inline.piece = NIL) & ~Pieces.IsWhiteSpace(inline.piece) THEN
				overLength := inline.font.maxY+padding[CSS2.top]+borderWidth[CSS2.top]+margin[CSS2.top];
				underLength := -inline.font.minY+1+padding[CSS2.bottom]+borderWidth[CSS2.bottom]+margin[CSS2.bottom]
			ELSE
				overLength := 0; underLength := 0
			END;
			
			IF ~(CSS2.normal IN inline.verticalAlignType) THEN
				IF breakPoint THEN
					temp := overLength + underLength - afterOverlength - afterUnderlength;
					IF temp > 0 THEN
						INC(afterOverlength, temp DIV 2);
						INC(afterUnderlength, (temp + 1) DIV 2);
					END
				ELSE
					temp := overLength + underLength - beforeOverlength - beforeUnderlength;
					IF temp > 0 THEN
						INC(beforeOverlength, temp DIV 2);
						INC(beforeUnderlength, (temp + 1) DIV 2);
					END
				END
			ELSE
				IF breakPoint THEN
					afterOverlength := Max(afterOverlength, overLength - inline.verticalAlign);
					afterUnderlength := Max(afterUnderlength, underLength + inline.verticalAlign);
				ELSE
					beforeOverlength := Max(beforeOverlength, overLength - inline.verticalAlign);
					beforeUnderlength := Max(beforeUnderlength, underLength + inline.verticalAlign);
				END
			END;
			
			(* Einf…gen der einzelnen Zeichen *)
			IF inline IS Format.Break THEN
				ForcedBreak
			ELSIF inline IS Format.Image THEN
				NEW(pictureBox); CopyProperties(inline, pictureBox);
				
				pictureBox.picture := inline(Format.Image).image;
				
				FOR edge := CSS2.top TO CSS2.left DO
					pictureBox.borderWidth[edge] := borderWidth[edge];
					pictureBox.padding[edge] := padding[edge];
				END;
				
				INC(lineFilled, margin[CSS2.left]);
				INC(lineFilled, borderWidth[CSS2.left]);
				INC(lineFilled, padding[CSS2.left]);
				
				pictureBox.left := LeftAt(cB, cB.top+height) + lineFilled;
				pictureBox.top := cB.top + margin[CSS2.top]+ borderWidth[CSS2.top] + padding[CSS2.top] + height - inline.verticalAlign;
				pictureBox.width := CSS2.CalcWidth(inline.width, cB.width, inline.font, 0);
				pictureBox.height := CSS2.CalcWidth(inline.height, cB.width, inline.font, 0);
				
				INC(lineFilled, pictureBox.width);
				INC(lineFilled, padding[CSS2.right]);
				INC(lineFilled, borderWidth[CSS2.right]);
				INC(lineFilled, margin[CSS2.right]);
					
				AddBox(pictureBox, inline.href, inline.target, inline.anchor);
				AddBoxToThisLine(pictureBox, inline.verticalAlignType, overLength, underLength);
				
				IF (WidthAt(cB, cB.top + height) < lineFilled)  & breakPoint & ~linesBlock.dsc(Format.Lines).whiteSpacePre
						OR linesBlock.dsc(Format.Lines).whiteSpacePre & (ORD(ch) = 10) THEN Break END;

				breakPoint := TRUE;
				breakOffset := 0;
				breakBox := lastBoxOfThisLine ;
				newStart := lineFilled;
				breakLen := 0;
				breakBoxHref := inline.href; breakBoxTarget := inline.target;
				beforeOverlength := Max(beforeOverlength, afterOverlength);
				beforeUnderlength := Max(beforeUnderlength, afterUnderlength);
				afterOverlength := 0; afterUnderlength := 0

			ELSIF inline.piece # NIL THEN
				NEW(textBox); CopyProperties(inline, textBox);
				
				textBox.fixed := FALSE; textBox.color := FindBest(inline.color);
				FOR edge := CSS2.top TO CSS2.left DO
					textBox.borderWidth[edge] := borderWidth[edge];
					textBox.padding[edge] := padding[edge];
				END;
				
				INC(lineFilled, margin[CSS2.left]);
				INC(lineFilled, borderWidth[CSS2.left]);
				INC(lineFilled, padding[CSS2.left]);
				
				textBox.left := LeftAt(cB, cB.top+height) + lineFilled;
				textBox.top := cB.top + margin[CSS2.top]+ borderWidth[CSS2.top] + padding[CSS2.top] + height - inline.verticalAlign;
				textBox.height := inline.font.maxY - inline.font.minY + 1;
				
				AddBox(textBox, inline.href, inline.target, inline.anchor);
				
				textBox.piece := inline.piece; textBox.offset := 0; textBox.len := inline.piece.len;
				
				off := 0;
				IF (thisLinesBoxes = NIL) & (inline.piece.len > 0) THEN
					Files.Set(R, inline.piece.f, inline.piece.off); Files.Read(R, ch);
					WHILE ~R.eof & (ch <= " ") DO
						INC(textBox.offset); DEC(textBox.len); INC(off);
						Files.Read(R, ch)
					END
				END;
	
				AddBoxToThisLine(textBox, inline.verticalAlignType, overLength, underLength);
					
				Files.Set(R, inline.piece.f, inline.piece.off+textBox.offset);
				ch := 0X;
	
				WHILE (off < inline.piece.len) & ~R.eof DO
					prevch := ch; Files.Read(R, ch);
					
					IF ~linesBlock.dsc(Format.Lines).whiteSpacePre THEN
						IF prevch = " " THEN WHILE ~R.eof & (ch <= " ") DO Files.Read(R, ch); INC(off) END END;
						IF ch < " " THEN ch := " " END;
					END;
					
					IF ch = " " THEN beforeLength := lineFilled; beforeLengthInInline := textBox.width END;
					
					inline.font.GetObj(inline.font, ORD(ch),r);
					dx := r(Fonts.Char).dx;

					lineFilled := lineFilled + dx;
					INC(textBox.width, dx);
						
					IF off = textBox.len-1 THEN
						INC(lineFilled, padding[CSS2.right]);
						INC(lineFilled, borderWidth[CSS2.right]);
						INC(lineFilled, margin[CSS2.right])
					END;
					
					IF (ch = " ") OR linesBlock.dsc(Format.Lines).whiteSpacePre & (ORD(ch) = 10) THEN
						breakPoint := TRUE;
						breakOffset := off;
						breakBox := lastBoxOfThisLine ;
						newStart := lineFilled; 
						breakLen := dx;
						breakBoxHref := inline.href; breakBoxTarget := inline.target; 
						
						beforeOverlength := Max(beforeOverlength, afterOverlength);
						beforeUnderlength := Max(beforeUnderlength, afterUnderlength);
						afterOverlength := overLength; afterUnderlength := underLength
					END;
					
					IF (WidthAt(cB, cB.top + height) < lineFilled)  & breakPoint & ~linesBlock.dsc(Format.Lines).whiteSpacePre
						OR linesBlock.dsc(Format.Lines).whiteSpacePre & (ORD(ch) = 10) THEN Break END;
	
					INC(off)
				END (* WHILE ch in piece *)
			
			END; (* if inline.piece # NIL *)

			float := inline.floats;
			WHILE float # NIL DO
				IF (FloatWidth(float, cB, margin) + lineFilled <= WidthAt(cB, cB.top + height)) & ~float.floatLeft THEN
					heightCopy := height;
					HandleBlock(float, cB, heightCopy, dummy, margin);
				ELSE
					NEW(floatListNode);
					floatListNode.float := float;
					IF floatList = NIL THEN
						floatList := floatListNode
					ELSE
						lastOfFloatList.next := floatListNode
					END;
					lastOfFloatList := floatListNode
				END;
				IF float.next # NIL THEN float := float.next(Format.Float) ELSE float := NIL END
			END;
			
			IF inline.next # NIL THEN inline := inline.next(Format.Inline) ELSE inline := NIL END;
		END; 
		ForcedBreak;
		RETURN height
	END HandleLines;
	
BEGIN
	boxList := NIL; links := NIL; anchors := NIL;
	NEW(canvas);
	canvas.left := 0; canvas.top := 0; canvas.width := width; canvas.height := 0; 
	block := root; WHILE block # NIL DO
		HandleBlock(block, canvas, canvas.height, margin, marginZeroArray);
		IF block.next # NIL THEN block := block.next(Format.Block)
		ELSE block := NIL
		END;
	END;
	height := maxV; width := maxH;
	canvas.width := maxH; canvas.height := maxV;
	RETURN boxList;
END Layout;

PROCEDURE OverLink*(links : Link; x, y : LONGINT; VAR href, target : Pieces.Piece);
BEGIN
	href := NIL; target := NIL;
	WHILE links # NIL DO
		IF links IS LinkBox THEN
			WITH links : LinkBox DO
				IF (links.box.top <= y) & (links.box.top + links.box.height - 1 >= y) &
					(links.box.left <= x) & (links.box.left + links.box.width - 1 >= x) THEN
				
					href := links.href; target := links.target; RETURN
				END
			END
		END;
		links := links.next
	END
END OverLink;

PROCEDURE GetAnchorPos*(anchors : Anchor; name : Pieces.Piece) : LONGINT;
BEGIN
	WHILE anchors # NIL DO
		IF Pieces.CAPPieceCompare(anchors.name, name) THEN RETURN anchors.top END;
		anchors := anchors.next
	END; RETURN MIN(LONGINT)
END GetAnchorPos;

END WebCSS2B.

