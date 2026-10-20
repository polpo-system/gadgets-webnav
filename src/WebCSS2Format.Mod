MODULE WebCSS2Format;  

IMPORT Files, Objects, Pictures, Fonts, Gadgets, 
	Pieces := WebPieces, CSS2 := WebCSS2, CSS2P := WebCSS2P, HTML4 := WebHTML4, 
	Network := WebNetwork, Strings, U := WebUtils, Out;  

TYPE 
	Object* = POINTER TO ObjectDesc;  
	Block* = POINTER TO BlockDesc;  
	Dsc* = POINTER TO DscDesc;  
	Principal* = POINTER TO PrincipalDesc;  
	Float* = POINTER TO FloatDesc;  
	Lines* = POINTER TO LinesDesc;  
	Inline* = POINTER TO InlineDesc;  
	Table* = POINTER TO TableDesc;  
	ColGroup* = POINTER TO ColGroupDesc;  
	Col* = POINTER TO ColDesc;  
	RowGroup* = POINTER TO RowGroupDesc;  
	Row* = POINTER TO RowDesc;  
	Cell* = POINTER TO CellDesc;  
	Caption* = POINTER TO CaptionDesc;  
	ListItem* = POINTER TO ListItemDesc;  
	Image* = POINTER TO ImageDesc;  
	FloatImage* = POINTER TO FloatImageDesc;  
	Break* = POINTER TO BreakDesc;  
	
	ObjectDesc* = RECORD 
			next*: Object;  
			
			top*, right*, bottom*, left*, width*, height*: CSS2.Term;  
			
			backgroundFixed*: BOOLEAN;  
			backgroundColor*: LONGINT;  
			backgroundImage*: Pieces.Piece;  
			backgroundPositionH*, backgroundPositionV*: CSS2.Term;  
			backgroundRepeatH*, backgroundRepeatV*: BOOLEAN;  
			
			borderColor*: ARRAY 4 OF LONGINT;  
			borderStyle*: ARRAY 4 OF SHORTINT;  
			borderWidth*: ARRAY 4 OF CSS2.Term;  
			
			color*: LONGINT;  
			(* content *)
			(* counterIncrement *)
			(* counterReset *)
			(* cursor* : INTEGER; *)
			directionLTR*: BOOLEAN;  
			display*: SHORTINT;  
			font*: Fonts.Font;  
			markerOffset*: CSS2.Term;  
			
			margin*: ARRAY 4 OF CSS2.Term;  
			maxHeight*, maxWidth*, minWidth*, minHeight*: CSS2.Term;  
			MinCW*, MaxCW*: LONGINT;   (* see CSS2, P. 257 *)
			padding*: ARRAY 4 OF CSS2.Term;  
			quotes*: ARRAY 2 OF CHAR;  
			
			textDecoration*: SET;  
			textDecorationColor*: LONGINT;  
			
			(* textShadow *)
			textTransform*: SET;  
			(* unicodeBidi* : INTEGER ; *)
			
			visibility*: SHORTINT;  
			wordSpacing*: CSS2.Term;  
			(* zIndex* : Len ; *)
			
			href*, target*, anchor*: Pieces.Piece;  
	END;  
	
	BlockDesc* = RECORD (ObjectDesc)
			dsc*: Dsc;  
			
			clearLeft*, clearRight*: BOOLEAN;  
			clip*: Pieces.Piece;  
			overflow*: SHORTINT;  
			position*: SHORTINT;  
	END;  
	
	DscDesc* = RECORD 
	END;  
	
	LinesDesc* = RECORD (DscDesc);  
			inlines*: Inline;  
			lineHeight*: LONGINT;   (* minimale H„he aller Linien (CSS2, 142) *)
			textAlign*: CSS2.Term;  
			textIndent*: CSS2.Term;  
			whiteSpacePre*: BOOLEAN;  
	END;  
	
	PrincipalDesc* = RECORD (DscDesc)
			dsc*: Block;  
	END;  
	
	FloatDesc* = RECORD (BlockDesc)
			floatLeft*, floatRight*: BOOLEAN;  
	END;  
	
	InlineDesc* = RECORD (ObjectDesc)
			floats*: Float;  
			absoluts*: Block;  
			fixeds*: Block;  
			letterSpacing*: CSS2.Term;  
			lineHeight*: LONGINT;   (* H„he des Elements *)
			verticalAlign*: LONGINT;  
			verticalAlignType*: SET;  
			piece*: Pieces.Piece;  
	END;  
	
	TableDesc* = RECORD (BlockDesc)
			colGroups*: ColGroup;  
			cols*: Col;  
			rowGroups*, lastRowGroup: RowGroup;  
			rows*: Row;  
			captionSide*: SHORTINT;  
			caption*: Block;  
			numberOfCols*: LONGINT;  
			
			borderCollapse*: BOOLEAN;  
			borderSpacingX*, borderSpacingY*: CSS2.Term;  
			cellPadding*: CSS2.Term;  
			tableLayoutFixed*: BOOLEAN;  
			
			lastCellOfActualRow: Cell;  
			actualRow: Row;  
			nextColToFill: Col;  
			lastCol: Col;  
	END;  
	
	ColGroupDesc* = RECORD (ObjectDesc)
			firstCol*, lastCol*: Col;  
	END;  
	
	ColDesc* = RECORD (ObjectDesc)
			minColWidth*, maxColWidth*, colWidth*: LONGINT;  
			auto*: BOOLEAN;  
			remainingFromAbove*: LONGINT;  
	END;  
	
	RowGroupDesc* = RECORD (ObjectDesc)
			firstRow*, lastRow*: Row;  
	END;  
	
	RowDesc* = RECORD (BlockDesc)
			cells*: Cell;  
	END;  
	
	CellDesc* = RECORD (BlockDesc)
			emptyCellsShow*: BOOLEAN;  
			rowspan*, colspan*: LONGINT;  
	END;  
	
	CaptionDesc* = RECORD (BlockDesc)
	END;  
	
	ListItemDesc* = RECORD (BlockDesc)
			listStyleImage*: CSS2.Term;  
			listStylePositionOutside*: BOOLEAN;  
			listStyleType*: SHORTINT;  
			counter*: LONGINT;  
	END;  
	
	ImageDesc* = RECORD (InlineDesc)
			image*: Pictures.Picture;  
	END;  
	
	FloatImageDesc* = RECORD (FloatDesc)
			image*: Pictures.Picture;  
	END;  
	
	BreakDesc* = RECORD (InlineDesc)
	END;  

VAR 
	Term0: CSS2.Term;  
	
	
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
		WHILE (name[i] # ':') & (i < LEN( name ) ) &(name[i] # 0X) DO INC( i ) END;  
		RETURN name[i] = ':'
	END prefixed;  

	PROCEDURE GetSource( url: ARRAY OF CHAR; VAR dtyp: ARRAY OF CHAR ): Files.File;  
	VAR f: Files.File;  R: Files.Rider;  key: LONGINT;  
		fname: ARRAY 128 OF CHAR;  
		i, j: INTEGER;  ch: CHAR;  
	BEGIN 
		IF pref( "file://", url ) THEN 
			i := 0;  j := 7;  
			REPEAT ch := url[i + 7];  fname[i] := ch;  INC( i ) UNTIL ch = 0X;  
			COPY( "image", dtyp );
			f := Files.Old( fname );  
		ELSE f := Network.RequestDoc( url, dtyp );
		END;  
		IF f = NIL THEN 
			COPY( "text", dtyp );
			f := Files.Old( "WebNotFound.html" );  
			IF f = NIL THEN Out.String( "failed to read file 'WebNotFound.html'" );  Out.Ln  END 
		END;  
		RETURN f
	END GetSource;  

	PROCEDURE OpenPicture( P: Pictures.Picture;  burl, src: ARRAY OF CHAR );  
	VAR fname: ARRAY 32 OF CHAR;  
		i, bpath, p: INTEGER;  
		url: ARRAY 256 OF CHAR;  
		f, sf: Files.File;  R, r: Files.Rider;  ch: CHAR;  
		dtyp: ARRAY 16 OF CHAR;
	BEGIN 
		U.CleanURL( src );
		U.NewUrl( burl, src, url );

		U.MakeTempName( url, fname );  f := Files.Old( fname );  
		IF f = NIL THEN 
			sf := GetSource( url, dtyp );  
			IF (sf # NIL) & (dtyp = "image") THEN 
				f := Files.New( fname );  Files.Set( R, f, 0 );  Files.Set( r, sf, 0 );  
				WHILE ~r.eof DO Files.Read( r, ch );  Files.Write( R, ch ) END;  
				Files.Register( f )
			ELSE f := NIL
			END;  
		END;  
		IF f = NIL THEN COPY( "Bart.Pict", fname ) END;  
		Pictures.Open( P, fname, TRUE )
	END OpenPicture;  

	PROCEDURE Max( a, b: LONGINT ): LONGINT;  
	BEGIN 
		IF a > b THEN RETURN a ELSE RETURN b END 
	END Max;  

	PROCEDURE Traverse*( body: HTML4.Element;  stylesheet: CSS2.StyleSheet; burl: ARRAY OF CHAR ): Block;  
	VAR res: Object;  noAnchorName: Pieces.Piece;  counterDummy: LONGINT;  

		PROCEDURE ^CalcExtremeWidths( block: Block );  

		PROCEDURE traverse( me: HTML4.Element;  VAR parentProperties: CSS2.Properties;  href, target: Pieces.Piece;  
										 VAR anchorName: Pieces.Piece;  VAR counter: LONGINT ): Object;  
		VAR properties, anonymousProperties: CSS2.Properties;  principalBlock: Block;  principalDsc: Principal;  
			lines: Lines;  inline: Inline;  block: Block;  listItem: ListItem;  child: Object;  inlines, lastInline: Inline;  
			blocks, lastBlock: Block;  html4object, lastPiece, obj: HTML4.Object;  first, last: BOOLEAN;  break: Break;  
			float, lastFloat: Float;  image: Image;  floatImage: FloatImage;  srcPiece: Pieces.Piece;  
			src: ARRAY 128 OF CHAR;  
			object: Objects.Object;  picture: Pictures.Picture;  color: LONGINT;  term: CSS2.Term;  
			tableBorders: BOOLEAN;  cellPadding: CSS2.Term;  LICounter: LONGINT;  

			PROCEDURE Set( object: Object;  VAR  (* in *) properties: CSS2.Properties );  
			
			VAR edge: SHORTINT;  

				PROCEDURE SetProperties;  
				BEGIN 
					object.backgroundFixed := properties.backgroundFixed;  
					object.backgroundColor := properties.backgroundColor;  
					object.backgroundImage := properties.backgroundImage;  
					object.backgroundPositionH := properties.backgroundPositionH;  
					object.backgroundPositionV := properties.backgroundPositionV;  
					object.backgroundRepeatH := properties.backgroundRepeatH;  
					object.backgroundRepeatV := properties.backgroundRepeatV;  
					FOR edge := CSS2.top TO CSS2.left DO 
						object.padding[edge] := properties.padding[edge];  
						object.borderColor[edge] := properties.borderColor[edge];  
						object.borderStyle[edge] := properties.borderStyle[edge];  
						object.borderWidth[edge] := properties.borderWidth[edge];  
						object.margin[edge] := properties.margin[edge]
					END;  
					object.color := properties.color;  
					(* object.content := properties.content; *)
					object.directionLTR := properties.directionLTR;  object.display := properties.display;  
					object.font := properties.font;  object.markerOffset := properties.markerOffset;  
					(* object.maxHeight := properties.maxHeight; object.maxWidth := properties.maxWidth; 
						object.minHeight := properties.minHeight; object.minWidth := properties.minWidth; *)
					object.quotes[0] := properties.quotes[0];  object.quotes[1] := properties.quotes[1];  
					object.textDecoration := properties.textDecoration;  
					object.textDecorationColor := properties.textDecorationColor;  
					object.textTransform := properties.textTransform;  object.visibility := properties.visibility;  
					object.wordSpacing := properties.wordSpacing;  object.top := properties.top;  
					object.right := properties.right;  object.bottom := properties.bottom;  object.left := properties.left;  
					object.width := properties.width;  object.height := properties.height
				END SetProperties;  

				PROCEDURE SetInlineProperties( inline: Inline );  
				BEGIN 
					inline.letterSpacing := properties.letterSpacing;  inline.lineHeight := properties.lineHeight;  
					inline.verticalAlign := properties.verticalAlign;  inline.verticalAlignType := properties.verticalAlignType;  
				END SetInlineProperties;  

				PROCEDURE SetBlockProperties( block: Block );  
				BEGIN 
					block.clearLeft := properties.clearLeft;  block.clearRight := properties.clearRight;  
					block.clip := properties.clip;  block.overflow := properties.overflow;  block.position := properties.position;  
				END SetBlockProperties;  

				PROCEDURE SetTableProperties( table: Table );  
				BEGIN 
					table.borderCollapse := properties.borderCollapse;  
					table.borderSpacingX := properties.borderSpacing[0];  
					table.borderSpacingY := properties.borderSpacing[1];  table.captionSide := properties.captionSide;  
					table.tableLayoutFixed := properties.tableLayoutFixed;  
				END SetTableProperties;  
				
				(*PROCEDURE SetCellProperties(cell : Cell);	
				BEGIN
					cell.emptyCellsShow := properties.emptyCellsShow
				END SetCellProperties;*)
				
				PROCEDURE SetFloatProperties( float: Float );  
				BEGIN 
					float.floatLeft := properties.floatLeft;  float.floatRight := properties.floatRight;  
				END SetFloatProperties;  

				PROCEDURE SetListItemProperties( listItem: ListItem );  
				BEGIN 
					listItem.listStyleImage := properties.listStyleImage;  
					listItem.listStylePositionOutside := properties.listStylePositionOutside;  
					listItem.listStyleType := properties.listStyleType;  
				END SetListItemProperties;  

			BEGIN 
				SetProperties;  object.href := href;  object.target := target;  object.anchor := anchorName;  
				anchorName := NIL;  
				IF object IS Inline THEN SetInlineProperties( object( Inline ) )
				ELSIF object IS Block THEN 
					SetBlockProperties( object( Block ) );  
					IF object IS Float THEN SetFloatProperties( object( Float ) )
					ELSIF object IS ListItem THEN SetListItemProperties( object( ListItem ) )
					ELSIF object IS Table THEN SetTableProperties( object( Table ) )
					END 
				END 
			END Set;  

			PROCEDURE SetDsc( dsc: Dsc;  properties: CSS2.Properties );  
			
			BEGIN 
				IF dsc IS Lines THEN 
					dsc( Lines ).lineHeight := properties.lineHeight;  
					dsc( Lines ).textAlign := properties.textAlign;  
					dsc( Lines ).textIndent := properties.textIndent;  
					dsc( Lines ).whiteSpacePre := properties.whiteSpacePre;  
				END;  
			END SetDsc;  

			PROCEDURE AddInline( inline: Inline );  
			VAR last: Inline;  
			BEGIN 
				last := inline;  
				WHILE last.next # NIL DO last := last.next( Inline ) END;  
				IF inlines = NIL THEN Pieces.DeleteLeadingWhiteSpaces( inline.piece );  inlines := inline 
				ELSE lastInline.next := inline
				END;  
				lastInline := last
			END AddInline;  

			PROCEDURE AddBlock( block: Block );  
			VAR last: Block;  
			BEGIN 
				last := block;  
				WHILE last.next # NIL DO last := last.next( Block ) END;  
				IF blocks = NIL THEN blocks := block ELSE lastBlock.next := block END;  
				lastBlock := last
			END AddBlock;  

			PROCEDURE whiteSpaceLines( ): BOOLEAN;  
			VAR inline: Inline;  
			BEGIN 
				inline := inlines;  
				WHILE inline # NIL DO 
					IF ~Pieces.IsWhiteSpace( inline.piece ) OR (inline IS Image) THEN RETURN FALSE END;  
					IF inline.next = NIL THEN RETURN TRUE ELSE inline := inline.next( Inline ) END 
				END;  
				RETURN TRUE
			END whiteSpaceLines;  

			PROCEDURE AnonymousLines;  
			VAR block: Block;  anonymousProperties: CSS2.Properties;  lines: Lines;  
			BEGIN 
				IF ~whiteSpaceLines() THEN 
					NEW( block );  anonymousProperties := CSS2.defaultProperties;  
					CSS2.InheritProperties( anonymousProperties, properties );  
					CSS2.CheckValues( anonymousProperties, properties );  Set( block, anonymousProperties );  

					NEW( lines );  SetDsc( lines, anonymousProperties );  lines.inlines := inlines;  

					block.dsc := lines;  AddBlock( block )
				END;  
				inlines := NIL 
			END AnonymousLines;  

			PROCEDURE InsertCell( table: Table;  me: HTML4.Element;  
											   VAR  (* in *) properties: CSS2.Properties;  
											   tableBorder: BOOLEAN );  
			VAR cell: Cell;  lines: Lines;  principal: Principal;  anonymousProperties: CSS2.Properties;  i: LONGINT;  
				noAnchorName: Pieces.Piece;  counterDummy: LONGINT;  
			BEGIN 
				NEW( cell );  Set( cell, properties );  counterDummy := 1;  
				child := traverse( me, properties, NIL , NIL , noAnchorName, counterDummy );  
				
				cell.colspan := Max( 1, Pieces.ConvertToInteger( HTML4.ThisAttribute( me, "colspan" ) ) );  
				cell.rowspan := Max( 1, Pieces.ConvertToInteger( HTML4.ThisAttribute( me, "rowspan" ) ) );  
				anonymousProperties := CSS2.defaultProperties;  
				
				CSS2.InheritProperties( anonymousProperties, properties );  
				CSS2.CheckValues( anonymousProperties, properties );  
				
				IF child # NIL THEN
					IF child IS Inline THEN 
						NEW( lines );  SetDsc( lines, anonymousProperties );  lines.inlines := child( Inline );  cell.dsc := lines
					ELSIF child IS Block THEN 
						NEW( principal );  SetDsc( principal, anonymousProperties );  principal.dsc := child( Block );  
						cell.dsc := principal
					END; 
				END; 
			
				IF tableBorder THEN 
					cell.borderWidth[CSS2.top] := CSS2.NewTerm( 1, 1.0, CSS2.dimless );  
					cell.borderWidth[CSS2.right] := cell.borderWidth[CSS2.top];  
					cell.borderWidth[CSS2.bottom] := cell.borderWidth[CSS2.top];  
					cell.borderWidth[CSS2.left] := cell.borderWidth[CSS2.top];  

					cell.borderColor[CSS2.top] := CSS2.GrooveColor;  cell.borderColor[CSS2.left] := CSS2.GrooveColor;  
					cell.borderColor[CSS2.right] := CSS2.RidgeColor;  cell.borderColor[CSS2.bottom] := CSS2.RidgeColor;  

					cell.borderStyle[CSS2.top] := CSS2.solid;  cell.borderStyle[CSS2.right] := CSS2.solid;  
					cell.borderStyle[CSS2.bottom] := CSS2.solid;  cell.borderStyle[CSS2.left] := CSS2.solid
				END;  
		
				CalcExtremeWidths( cell );  

				i := 0;  
				WHILE i < cell.colspan DO 
					IF table.nextColToFill = NIL THEN NEW( table.nextColToFill );  
						(* .. *)
						IF table.cols = NIL THEN table.cols := table.nextColToFill ELSE table.lastCol.next := table.nextColToFill END;  
						table.lastCol := table.nextColToFill
					END;  
					
					IF table.nextColToFill.remainingFromAbove > 0 THEN 
						(* .. cell.colspan := i  !!!! *)
					ELSE table.nextColToFill.remainingFromAbove := cell.rowspan
					END;  
					
					DEC( table.nextColToFill.remainingFromAbove );  
					IF table.nextColToFill.next # NIL THEN table.nextColToFill := table.nextColToFill.next( Col ) 
					ELSE table.nextColToFill := NIL 
					END;  
					
					INC( i )
				END;  
				
				WHILE (table.nextColToFill # NIL ) & (table.nextColToFill.remainingFromAbove > 0) DO 
					DEC( table.nextColToFill.remainingFromAbove );  
					IF table.nextColToFill.next # NIL THEN table.nextColToFill := table.nextColToFill.next( Col ) 
					ELSE table.nextColToFill := NIL 
					END 
				END;  
				
				IF table.lastCellOfActualRow = NIL THEN table.actualRow.cells := cell
				ELSE table.lastCellOfActualRow.next := cell
				END;  
				table.lastCellOfActualRow := cell
			END InsertCell;  

			PROCEDURE InsertRow( table: Table;  me: HTML4.Element;  VAR  (* in *) properties: CSS2.Properties;  
											    tableBorder: BOOLEAN );  
			VAR html4object: HTML4.Object;  row: Row;  childProperties: CSS2.Properties;  
			BEGIN 
				NEW( row );  Set( row, properties );  
				IF table.actualRow # NIL THEN table.actualRow.next := row ELSE table.rows := row END;  
				table.actualRow := row;  

				table.lastCellOfActualRow := NIL;  table.nextColToFill := table.cols;  

				html4object := me.objects;  
				WHILE html4object # NIL DO 
					IF html4object IS HTML4.Element THEN 
						CSS2.AssignValues( childProperties, html4object( HTML4.Element ), properties, stylesheet );  
						IF childProperties.display = CSS2.tableCell THEN 
							InsertCell( table, html4object( HTML4.Element ), childProperties, tableBorder );  
						END 
					END;  
					html4object := html4object.next
				END 
			END InsertRow;  

			PROCEDURE InsertRowGroup( table: Table;  me: HTML4.Element;  VAR  (* in *) properties: CSS2.Properties;  
														  tableBorder: BOOLEAN );  
			VAR html4object: HTML4.Object;  rowGroup: RowGroup;  childProperties: CSS2.Properties;  
			BEGIN 
				NEW( rowGroup );  Set( rowGroup, properties );  
				IF table.lastRowGroup = NIL THEN table.rowGroups := rowGroup ELSE table.lastRowGroup.next := rowGroup END;  
				table.lastRowGroup := rowGroup;  

				html4object := me.objects;  
				WHILE html4object # NIL DO 
					IF html4object IS HTML4.Element THEN 
						CSS2.AssignValues( childProperties, html4object( HTML4.Element ), properties, stylesheet );  
						IF childProperties.display = CSS2.tableRow THEN 
							InsertRow( table, html4object( HTML4.Element ), childProperties, tableBorder );  
						END 
					END;  
					html4object := html4object.next
				END 
			END InsertRowGroup;  

			PROCEDURE NewTable( me: HTML4.Element;  VAR  (* in *) properties: CSS2.Properties;  
											    tableBorder: BOOLEAN;  cellPadding: CSS2.Term ): Table;  
			VAR html4object: HTML4.Object;  table: Table;  childProperties: CSS2.Properties;  child: Object;  
				(*lastColGroup : ColGroup;*)
				lastCol: Col;  noAnchorName: Pieces.Piece;  counterDummy: LONGINT;  
				
				   (*
				   PROCEDURE AddColGroupToTable;
					BEGIN
						IF table.cols = NIL THEN
							IF table.colGroups = NIL THEN
								table.colGroups := child(ColGroup)
							ELSE
								lastColGroup.next := child(ColGroup)
							END;
							lastColGroup := child(ColGroup)
						END;
					END AddColGroupToTable;
					*)
				
				
			BEGIN 
				NEW( table );  Set( table, properties );  table.cellPadding := cellPadding;  

				html4object := me.objects;  
				WHILE html4object # NIL DO 
					IF html4object IS HTML4.Element THEN 
						CSS2.AssignValues( childProperties, html4object( HTML4.Element ), properties, stylesheet );  
						IF childProperties.display = CSS2.tableCaption THEN 
							counterDummy := 1;  
							child := 
								traverse( html4object( HTML4.Element ), properties, NIL , NIL , noAnchorName, counterDummy );  
							IF table.caption = NIL THEN table.caption := child( Caption ) END 
							(* ELSIF childProperties.display = CSS2.tableColumnGroup THEN
						child := traverseColGroup(html4object(HTML4.Element), childProperties);
						AddColGroupToTable; *)
						ELSIF childProperties.display = CSS2.tableColumn THEN 
							IF table.colGroups = NIL THEN 
								IF table.cols = NIL THEN table.cols := child( Col ) ELSE lastCol.next := child( Col ) END;  
								lastCol := child( Col )
							END 
						ELSIF childProperties.display = CSS2.tableRowGroup THEN 
							InsertRowGroup( table, html4object( HTML4.Element ), childProperties, tableBorder );  
						END 
					END;  
					html4object := html4object.next
				END;  
				RETURN table
			END NewTable;  

		BEGIN 
			CSS2.AssignValues( properties, me, parentProperties, stylesheet );  
			
			IF me.type.name = "BR" THEN NEW( break );  Set( break, properties );  RETURN break
			ELSIF me.type.name = "A" THEN 
				IF HTML4.ThisAttribute( me, "href" ) # NIL THEN 
					href := HTML4.ThisAttribute( me, "href" );  target := HTML4.ThisAttribute( me, "target" )
				ELSE anchorName := HTML4.ThisAttribute( me, "name" )
				END ;
			ELSIF me.type.name = "IMG" THEN 
				IF Pieces.CAPCompare( HTML4.ThisAttribute( me, "align" ), "right" ) THEN 
					properties.floatRight := TRUE;  properties.floatLeft := FALSE
				ELSIF Pieces.CAPCompare( HTML4.ThisAttribute( me, "align" ), "left" ) THEN 
					properties.floatRight := FALSE;  properties.floatLeft := TRUE
				END;  
				
				object := Gadgets.CreateObject( "Pictures.NewPicture" );  
				picture := object( Pictures.Picture );  
				srcPiece := HTML4.ThisAttribute( me, "SRC" );  
				
				Pieces.Convert( srcPiece, src ); 
				OpenPicture( picture, burl, src );
				
				IF properties.floatRight OR properties.floatLeft THEN 
					NEW( floatImage );  floatImage.floatLeft := properties.floatLeft;  
					floatImage.floatRight := properties.floatRight;  Set( floatImage, properties );  
					floatImage.image := picture;  
					floatImage.width := CSS2.NewTerm( picture.width, picture.width, CSS2.px );  
					floatImage.height := CSS2.NewTerm( picture.height, picture.height, CSS2.px );  RETURN floatImage
				ELSE 
					NEW( image );  Set( image, properties );  image.image := picture;  
					image.width := CSS2.NewTerm( picture.width, picture.width, CSS2.px );  
					image.height := CSS2.NewTerm( picture.height, picture.height, CSS2.px );  RETURN image
				END;  
			ELSIF (me.type.name = "TD") OR (me.type.name = "TH") OR (me.type.name = "TABLE") THEN 
				color := HTML4.Color( HTML4.ThisAttribute( me, "bgcolor" ) );  
				IF color >= 0 THEN properties.backgroundColor := color END;  
			ELSIF me.type.name = "BODY" THEN 
				color := HTML4.Color( HTML4.ThisAttribute( me, "text" ) );  
				IF color >= 0 THEN properties.color := color END;  
				color := HTML4.Color( HTML4.ThisAttribute( me, "bgcolor" ) );  
				IF color >= 0 THEN properties.backgroundColor := color END 
			END;  
			IF me.type.name = "TABLE" THEN 
				tableBorders := FALSE;  cellPadding := NIL;  
				IF HTML4.ThisAttribute( me, "cellspacing" ) # NIL THEN 
					properties.borderSpacing[0] := CSS2P.HTML4LengthTerm( HTML4.ThisAttribute( me, "cellspacing" ) );  
					properties.borderSpacing[1] := properties.borderSpacing[0];  
				END;  
				IF HTML4.ThisAttribute( me, "cellpadding" ) # NIL THEN 
					cellPadding := CSS2P.HTML4LengthTerm( HTML4.ThisAttribute( me, "cellpadding" ) );  
				END;  
				IF HTML4.ThisAttribute( me, "border" ) # NIL THEN 
					properties.borderWidth[CSS2.top] := CSS2P.HTML4LengthTerm( HTML4.ThisAttribute( me, "border" ) );  
					properties.borderWidth[CSS2.right] := properties.borderWidth[CSS2.top];  
					properties.borderWidth[CSS2.bottom] := properties.borderWidth[CSS2.top];  
					properties.borderWidth[CSS2.left] := properties.borderWidth[CSS2.top];  
					properties.borderColor[CSS2.top] := CSS2.RidgeColor;  
					properties.borderColor[CSS2.left] := CSS2.RidgeColor;  
					properties.borderColor[CSS2.right] := CSS2.GrooveColor;  
					properties.borderColor[CSS2.bottom] := CSS2.GrooveColor;  
					properties.borderStyle[CSS2.top] := CSS2.solid;  properties.borderStyle[CSS2.right] := CSS2.solid;  
					properties.borderStyle[CSS2.bottom] := CSS2.solid;  properties.borderStyle[CSS2.left] := CSS2.solid;  
					tableBorders := ~Pieces.CAPCompare( HTML4.ThisAttribute( me, "border" ), "0" );  
				END;  
			END;  
			IF (me.type.name = "TD") OR (me.type.name = "TH") OR (me.type.name = "TABLE") OR 
			    (me.type.name = "COL") OR (me.type.name = "COLGROUP") OR (me.type.name = "TBODY") OR 
			    (me.type.name = "TFOOT") OR (me.type.name = "THEAD") OR (me.type.name = "TR") OR 
			    (me.type.name = "H1") OR (me.type.name = "H2") OR (me.type.name = "H3") OR (me.type.name = "H4") OR 
			    (me.type.name = "H5") OR (me.type.name = "H6") OR (me.type.name = "P") OR (me.type.name = "DIV") THEN 
				
				IF HTML4.ThisAttribute( me, "align" ) # NIL THEN 
					NEW( term );  term.piece := HTML4.ThisAttribute( me, "align" );  term.unit := CSS2.piece;  
					properties.textAlign := term
				END 
			END;  

			(* FONT wird in AssignValues behandelt *)
			
			(* CSS2, page 115 *)
			IF (properties.position = CSS2.absolute) OR (properties.position = CSS2.fixed) THEN 
				properties.display := CSS2.block;  properties.floatLeft := FALSE;  properties.floatRight := FALSE
			ELSIF properties.floatLeft OR properties.floatRight THEN properties.display := CSS2.block
			END;  
			
			IF properties.display = CSS2.table THEN RETURN NewTable( me, properties, tableBorders, cellPadding )
			END;  
			
			html4object := me.objects;  first := TRUE;  

			obj := html4object;  
			WHILE obj # NIL DO 
				IF ~(obj IS HTML4.Element) THEN lastPiece := obj END;  
				obj := obj.next
			END;  
			
			LICounter := 1;  
			WHILE html4object # NIL DO 
				IF html4object IS HTML4.Element THEN 
					child := traverse( html4object( HTML4.Element ), properties, href, target, anchorName, LICounter );  
					IF child # NIL THEN 
						IF child IS Inline THEN AddInline( child( Inline ) )
						ELSIF (child IS Float) & (lastInline # NIL ) THEN 
							lastFloat := lastInline.floats;  
							IF lastFloat # NIL THEN 
								WHILE lastFloat.next # NIL DO lastFloat := lastFloat.next( Float ) END;  
								lastFloat.next := child( Float )
							ELSE lastInline.floats := child( Float )
							END;  
						ELSIF child IS Block THEN 
							IF inlines # NIL THEN AnonymousLines END;  
							AddBlock( child( Block ) )
						END 
					END 
				ELSE  (* Piece *)
					NEW( inline );  
					IF properties.display = CSS2.inline THEN Set( inline, properties ) 
					ELSE 
						anonymousProperties := CSS2.defaultProperties;  
						CSS2.InheritProperties( anonymousProperties, properties );  
						CSS2.CheckValues( anonymousProperties, properties );  Set( inline, anonymousProperties )
					END;  
					
					IF ~first THEN 
						inline.margin[CSS2.left] := Term0;  inline.borderWidth[CSS2.left] := Term0;  
						inline.padding[CSS2.left] := Term0
					END;  
					
					last := html4object = lastPiece;  
					IF ~last THEN 
						inline.margin[CSS2.right] := Term0;  inline.borderWidth[CSS2.right] := Term0;  
						inline.padding[CSS2.right] := Term0
					END;  
					inline.piece := html4object( HTML4.Piece ).piece;  AddInline( inline )
				END;  
				html4object := html4object.next;  first := FALSE
			END;   (* WHILE child *)

			IF (blocks # NIL ) OR (properties.display = CSS2.block) OR (properties.display = CSS2.listItem) THEN 
				IF inlines # NIL THEN 
					IF blocks # NIL THEN AnonymousLines 
					ELSE 
						NEW( lines );  SetDsc( lines, properties );  lines.inlines := inlines;  
						IF properties.display = CSS2.block THEN 
							IF properties.floatLeft OR properties.floatRight THEN 
								NEW( float );  Set( float, properties );  float.dsc := lines;  blocks := float
							ELSE NEW( block );  Set( block, properties );  block.dsc := lines;  blocks := block
							END 
						ELSIF properties.display = CSS2.listItem THEN 
							NEW( listItem );  Set( listItem, properties );  listItem.counter := counter;  INC( counter );  
							listItem.dsc := lines;  blocks := listItem
						END;  
						inlines := NIL 
					END 
				END;  
				
				IF blocks = NIL THEN  (* empty block *)
					NEW( blocks );  Set( blocks, properties )
				END;  
				
				IF blocks.next # NIL THEN 
					NEW( principalBlock );  Set( principalBlock, properties );  NEW( principalDsc );  
					principalDsc.dsc := blocks;  principalBlock.dsc := principalDsc;  RETURN principalBlock
				ELSE RETURN blocks
				END 
			ELSE RETURN inlines
			END 
		END traverse;  

		PROCEDURE CalcExtremeWidths( block: Block );  
		VAR child: Object;  

			PROCEDURE LinesExtremeWidths( block: Block );  
			VAR inline: Inline;  R: Files.Rider;  r: Objects.Object;  i: INTEGER;  ch, prevch: CHAR;  
				thisWord, thisWordRel, allWords, allWordsRel, largestWord: LONGINT;  

				PROCEDURE RealWidth( absWidth: LONGINT;  relWidth: LONGINT ): LONGINT;  
				BEGIN 
					IF relWidth < 90 THEN RETURN 100*absWidth DIV (100 - relWidth) ELSE RETURN 10*absWidth END;  
				END RealWidth;  

			BEGIN 
				IF block = NIL THEN RETURN END;  
				IF (block.dsc = NIL ) OR ~(block.dsc IS Lines) THEN RETURN END;  
				
				thisWord := 0;  largestWord := 0;  thisWordRel := 0;  allWords := 0;  allWordsRel := 0;  inline := block.dsc( Lines ).inlines;  
				WHILE inline # NIL DO 
					
					IF inline.margin[CSS2.left].unit = CSS2.percent THEN 
						INC( thisWordRel, inline.margin[CSS2.left].num );  INC( allWordsRel, inline.margin[CSS2.left].num )
					ELSE 
						INC( thisWord, CSS2.CalcWidth( inline.margin[CSS2.left], 0, inline.font, 0 ) );  
						INC( allWords, CSS2.CalcWidth( inline.margin[CSS2.left], 0, inline.font, 0 ) )
					END;  
					INC( thisWord, CSS2.CalcBorderWidth( inline.borderWidth[CSS2.left], inline.font, 0 ) );  
					INC( allWords, CSS2.CalcBorderWidth( inline.borderWidth[CSS2.left], inline.font, 0 ) );  
					IF inline.padding[CSS2.left].unit = CSS2.percent THEN 
						INC( thisWordRel, inline.padding[CSS2.left].num );  INC( allWordsRel, inline.padding[CSS2.left].num );  
					ELSE 
						INC( thisWord, CSS2.CalcWidth( inline.padding[CSS2.left], 0, inline.font, 0 ) );  
						INC( allWords, CSS2.CalcWidth( inline.padding[CSS2.left], 0, inline.font, 0 ) )
					END;  
					
					IF inline IS Image THEN 
						thisWord := thisWord + inline( Image ).image.width;  
						allWords := allWords + inline( Image ).image.width;  
						IF RealWidth( thisWord, thisWordRel ) > largestWord THEN 
							largestWord := RealWidth( thisWord, thisWordRel )
						END;  
						thisWord := 0;  thisWordRel := 0
					
					ELSIF inline.piece # NIL THEN 
						Files.Set( R, inline.piece.f, inline.piece.off );  Files.Read( R, ch );  
						IF (ch < " ") THEN ch := " " END;  
						prevch := ch;  i := 0;  
						WHILE (i < inline.piece.len) & ~R.eof DO 
							inline.font.GetObj( inline.font, ORD( ch ), r );  allWords := allWords + r( Fonts.Char ).dx;  
							IF ch > " " THEN thisWord := thisWord + r( Fonts.Char ).dx 
							ELSE 
								IF RealWidth( thisWord, thisWordRel ) > largestWord THEN 
									largestWord := RealWidth( thisWord, thisWordRel )
								END;  
								thisWord := 0;  thisWordRel := 0
							END;  
							INC( i );  prevch := ch;  Files.Read( R, ch );  
							IF prevch = " " THEN 
								WHILE ~R.eof & (ch <= " ") DO Files.Read( R, ch );  INC( i ) END 
							END;  
							IF ch < " " THEN ch := " " END 
						END 
					END;  
					
					IF inline.padding[CSS2.right].unit = CSS2.percent THEN 
						INC( thisWordRel, inline.padding[CSS2.right].num );  
						INC( allWordsRel, inline.padding[CSS2.right].num );  
					ELSE 
						INC( thisWord, CSS2.CalcWidth( inline.padding[CSS2.right], 0, inline.font, 0 ) );  
						INC( allWords, CSS2.CalcWidth( inline.padding[CSS2.right], 0, inline.font, 0 ) )
					END;  
					INC( thisWord, CSS2.CalcBorderWidth( inline.borderWidth[CSS2.right], inline.font, 0 ) );  
					INC( allWords, CSS2.CalcBorderWidth( inline.borderWidth[CSS2.right], inline.font, 0 ) );  
					IF inline.margin[CSS2.right].unit = CSS2.percent THEN 
						INC( thisWordRel, inline.margin[CSS2.right].num );  INC( allWords, inline.margin[CSS2.right].num )
					ELSE 
						INC( thisWord, CSS2.CalcWidth( inline.margin[CSS2.right], 0, inline.font, 0 ) );  
						INC( allWords, CSS2.CalcWidth( inline.margin[CSS2.right], 0, inline.font, 0 ) )
					END;  
					
					IF inline.next # NIL THEN inline := inline.next( Inline )
					ELSE inline := NIL 
					END 
				END;  
				
				IF RealWidth( thisWord, thisWordRel ) > largestWord THEN 
					largestWord := RealWidth( thisWord, thisWordRel )
				END;  
				block.MinCW := largestWord;  block.MaxCW := RealWidth( allWords, allWordsRel )
			END LinesExtremeWidths;  

			PROCEDURE TableExtremeWidths( table: Table );  
			VAR row: Object;  cell: Object;  rowMinWidth, rowMaxWidth: LONGINT;  
			BEGIN 
				row := table.rows;  
				WHILE row # NIL DO 
					rowMinWidth := 0;  rowMaxWidth := 0;  cell := row( Row ).cells;  
					WHILE cell # NIL DO 
						CalcExtremeWidths( cell( Block ) );  INC( rowMinWidth, cell.MinCW );  
						INC( rowMaxWidth, cell.MaxCW );  cell := cell.next
					END;  
					table.MinCW := Max( table.MinCW, rowMinWidth );  
					table.MaxCW := Max( table.MaxCW, rowMaxWidth );  row := row.next
				END;  
			END TableExtremeWidths;  

		BEGIN 
			IF (block.dsc # NIL ) & (block.dsc IS Principal) THEN 
				block.MinCW := 0;  block.MaxCW := 0;  child := block.dsc( Principal ).dsc;  
				WHILE child # NIL DO 
					CalcExtremeWidths( child( Block ) );  
					IF child.MinCW > block.MinCW THEN block.MinCW := child.MinCW END;  
					IF child.MaxCW > block.MaxCW THEN block.MaxCW := child.MaxCW END;  
					child := child.next
				END;  
			ELSIF (block.dsc # NIL ) & (block.dsc IS Lines) THEN LinesExtremeWidths( block )
			ELSIF block IS Table THEN TableExtremeWidths( block( Table ) )
			END;  
		END CalcExtremeWidths;  

	BEGIN 
		noAnchorName := NIL;  counterDummy := 1;  
		res := traverse( body, CSS2.defaultProperties, NIL , NIL , noAnchorName, counterDummy );  
		IF res IS Block THEN 
			(* CalcExtremeWidths(res(Block)) *)
			RETURN res( Block )
		ELSE HALT( 99 )
		END 
	END Traverse;  

BEGIN 
	NEW( Term0 );  Term0.unit := CSS2.dimless;  Term0.num := 0;  Term0.realNum := 0.0;  
END WebCSS2Format.	
	
	

		
	

