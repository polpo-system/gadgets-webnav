MODULE WebSGML;  

IMPORT Texts, Scanner := WebSGMLScanner, Strings, Out;  

CONST 
	debug = FALSE;  

CONST 
	maxtaglen* = 10;  maxattrlen = 12;  

TYPE 
	ElementType* = POINTER TO ElementTypeDesc;  
	Attr* = POINTER TO AttrDesc;  
	AttrValue* = POINTER TO AttrValueDesc;  
	ContentGroup* = POINTER TO ContentGroupDesc;  
	Fix = POINTER TO FixDesc;  
	
	ContentGroupDesc* = RECORD;  
			next*, children*: ContentGroup;  
			element*: ElementType;  
			last: ContentGroup;  
						 (* Vereinfacht das einf…gen am Schluss der Liste. Die Reihenfolge muss eingehalten werden wegen dem "," *)
			maxone*, minone*: BOOLEAN;  
			fixedorder*, exklusive*: BOOLEAN
	END;  
	
	ElementTypeDesc* = RECORD;  
			next*, slink: ElementType;   (* slink is needed in AttrDef *)
			name*: ARRAY maxtaglen + 1 OF CHAR;  
			beginopt*, endopt*, empty*: BOOLEAN;  
			content*, forbiddenContent*: ContentGroup;  
			attributes*: Attr
	END;  
	
	AttrValueDesc* = RECORD;  
			next*: AttrValue;  
			value*: Scanner.Ident;  
	END;  
	
	AttrDesc* = RECORD;  
			next*: Attr;  
			name*: ARRAY maxattrlen + 1 OF CHAR;  
			values*: AttrValue;  
			default*: Scanner.Ident;  
	END;  
	
	FixDesc = RECORD;  
			next: Fix;  
			where: ContentGroup;  
			what: ARRAY maxtaglen + 1 OF CHAR;  
	END;  

VAR 
	FixList: Fix;  Elements: ElementType;  sym: INTEGER;  

	PROCEDURE isElement*( e: ElementType;  name: ARRAY OF CHAR ): BOOLEAN;  
	BEGIN 
		WHILE e # NIL DO 
			IF e.name = name THEN RETURN TRUE END;  
			e := e.next
		END;  
		RETURN FALSE
	END isElement;  

	PROCEDURE ThisElementType*( type: ElementType;  name: ARRAY OF CHAR ): ElementType;  
	BEGIN 
		WHILE (type # NIL ) & (type.name # name) DO type := type.next END;  
		IF type = NIL THEN 
			NEW( type );  COPY( name, type.name );  type.beginopt := FALSE;  type.endopt := FALSE;  type.empty := FALSE
		END;  
		RETURN type
	END ThisElementType;  

	PROCEDURE Insert( VAR child, at: ContentGroup );  
	BEGIN 
		IF at.last = NIL THEN at.children := child ELSE at.last.next := child END;  
		at.last := child
	END Insert;  

	PROCEDURE findElement( name: ARRAY OF CHAR;  VAR cg: ContentGroup );  
	VAR e: ElementType;  fix: Fix;  
	BEGIN 
		e := Elements;  
		WHILE e # NIL DO 
			IF e.name = name THEN cg.element := e;  RETURN END;  
			e := e.next
		END;  
		IF cg.element = NIL THEN NEW( fix );  fix.where := cg;  COPY( name, fix.what );  fix.next := FixList;  FixList := fix END 
	END findElement;  

	PROCEDURE fixElement( name: ARRAY OF CHAR;  e: ElementType );  
	VAR fix: Fix;  
	BEGIN 
		WHILE (FixList # NIL ) & (FixList.what = name) DO FixList.where.element := e;  FixList := FixList.next END;  
		IF FixList # NIL THEN 
			fix := FixList;  
			WHILE fix.next # NIL DO 
				IF fix.next.what = name THEN fix.next.where.element := e;  fix.next := fix.next.next ELSE fix := fix.next END 
			END 
		END 
	END fixElement;  

	PROCEDURE ParseContent( VAR res: ElementType );  
	VAR temp: ContentGroup;  

		PROCEDURE ContentTerm( ): ContentGroup;  
		VAR temp: ContentGroup;  res: ContentGroup;  
		BEGIN 
			NEW( res );  
			IF sym = Scanner.lparen THEN 
				Scanner.Get( sym );  
				WHILE (sym = Scanner.ident) OR (sym = Scanner.lparen) DO 
					temp := ContentTerm();  Insert( temp, res );  
					IF sym = Scanner.or THEN res.exklusive := TRUE;  Scanner.Get( sym )
					ELSIF sym = Scanner.comma THEN res.exklusive := FALSE;  res.fixedorder := TRUE;  Scanner.Get( sym )
					ELSIF sym = Scanner.and THEN res.exklusive := FALSE;  res.fixedorder := FALSE;  Scanner.Get( sym )
					END 
				END;  
				IF sym = Scanner.rparen THEN Scanner.Get( sym ) ELSE Scanner.Mark( ")?" ) END;  
			ELSIF sym = Scanner.ident THEN findElement( Scanner.id, res );  Scanner.Get( sym );  
			ELSE Scanner.Mark( "( or ident?" );  
			END;  
			
			IF sym = Scanner.question THEN res.maxone := TRUE;  res.minone := FALSE;  Scanner.Get( sym )
			ELSIF sym = Scanner.times THEN res.maxone := FALSE;  res.minone := FALSE;  Scanner.Get( sym )
			ELSIF (sym = Scanner.plus) & ~Scanner.preSpace THEN 
				res.maxone := FALSE;  res.minone := TRUE;  Scanner.Get( sym )
			ELSE res.maxone := TRUE;  res.minone := TRUE
			END;  
			RETURN res
		END ContentTerm;  

	BEGIN 
		res.content := ContentTerm();  
		LOOP 
			IF sym = Scanner.minus THEN Scanner.Get( sym );  res.forbiddenContent := ContentTerm();  EXIT 
			ELSIF sym = Scanner.plus THEN  (* possible error: "(LI)+ (NEWLI)" don't differ to "(LI) +(NEWLI)" *)
				Scanner.Get( sym );  temp := ContentTerm();  Insert( temp, res.content );  
			ELSIF sym = Scanner.lparen THEN  (* possible error: "(LI)+ (NEWLI)" don't differ to "(LI) +(NEWLI)" *)
				temp := ContentTerm();  Insert( temp, res.content );  
			ELSE EXIT 
			END;  
		END 
	END ParseContent;  

	PROCEDURE ElementDef;  
	VAR firstelement, element, lastElement: ElementType;  List: BOOLEAN;  
	BEGIN 
		NEW( firstelement );  
		IF sym = Scanner.lparen THEN List := TRUE;  Scanner.Get( sym ) ELSE List := FALSE END;  
		IF sym = Scanner.ident THEN 
			Strings.Upper( Scanner.id, firstelement.name );  fixElement( Scanner.id, firstelement );  Scanner.Get( sym );  
		ELSE Scanner.Mark( "ident?" )
		END;  
		
		IF List THEN 
			WHILE sym = Scanner.or DO 
				Scanner.Get( sym );  
				IF sym = Scanner.ident THEN 
					NEW( element );  
					IF lastElement = NIL THEN lastElement := element END;  
					Strings.Upper( Scanner.id, element.name );  fixElement( Scanner.id, element );  Scanner.Get( sym );  
					element.next := firstelement.next;  firstelement.next := element;  
				ELSE Scanner.Mark( "ident?" )
				END 
			END 
		END;  
		IF lastElement = NIL THEN lastElement := firstelement END;  
		lastElement.next := Elements;  Elements := firstelement;  
		
		IF List THEN 
			IF sym = Scanner.rparen THEN Scanner.Get( sym ) ELSE Scanner.Mark( ")?" ) END 
		END;  
		
		firstelement.beginopt := (sym # Scanner.minus);  Scanner.Get( sym );  
		firstelement.endopt := (sym # Scanner.minus);  Scanner.Get( sym );  
		firstelement.empty := ((sym = Scanner.ident) & (Scanner.id = "EMPTY"));  
		IF ~firstelement.empty THEN ParseContent( firstelement ) ELSE Scanner.Get( sym ) END;  
		
		IF List THEN 
			element := firstelement.next;  
			LOOP 
				IF element = NIL THEN EXIT END;  
				element.beginopt := firstelement.beginopt;  element.endopt := firstelement.endopt;  
				element.empty := firstelement.empty;  element.content := firstelement.content;  
				element.forbiddenContent := firstelement.forbiddenContent;  
				IF element = lastElement THEN EXIT END;  
				element := element.next
			END;  
		END 
	END ElementDef;  

	PROCEDURE AttListDef;  
	VAR attr, attrs: Attr;  attrValue: AttrValue;  element, temp: ElementType;  List: BOOLEAN;  

		PROCEDURE Find( VAR e: ElementType );  
		BEGIN 
			e := Elements;  
			WHILE (e # NIL ) & (e.name # Scanner.id) DO e := e.next( ElementType );  END;  
			IF e = NIL THEN Scanner.Mark( "unknown element" ) END 
		END Find;  

		PROCEDURE NewAttrValue( name: ARRAY OF CHAR ): AttrValue;  
		VAR res: AttrValue;  
		BEGIN 
			NEW( res );  COPY( name, res.value );  RETURN res
		END NewAttrValue;  

	BEGIN 
		IF sym = Scanner.lparen THEN List := TRUE;  Scanner.Get( sym ) ELSE List := FALSE END;  
		
		Find( element );  element.slink := NIL;  Scanner.Get( sym );  
		
		IF List THEN 
			WHILE sym = Scanner.or DO 
				Scanner.Get( sym );  Find( temp );  
				IF temp # NIL THEN temp.slink := element.slink;  element.slink := temp END;  
				Scanner.Get( sym )
			END 
		END;  
		
		IF List THEN 
			IF (sym = Scanner.rparen) THEN Scanner.Get( sym ) ELSE Scanner.Mark( ")?" ) END 
		END;  
		
		NEW( attrs );  
		LOOP 
			NEW( attr );  
			IF sym = Scanner.ident THEN COPY( Scanner.id, attr.name );  Scanner.Get( sym ) ELSE Scanner.Mark( "ident?" ) END;  
			IF sym = Scanner.gt THEN Scanner.Mark( "> to early" );  EXIT END;  
			
			IF sym = Scanner.ident THEN attr.values := NewAttrValue( Scanner.id );  Scanner.Get( sym );  
			ELSIF sym = Scanner.lparen THEN 
				Scanner.Get( sym );  
				WHILE sym = Scanner.ident DO 
					attrValue := NewAttrValue( Scanner.id );  Scanner.Get( sym );  attrValue.next := attr.values;  
					attr.values := attrValue;  
					IF sym = Scanner.or THEN Scanner.Get( sym ) END;  
				END;  
				IF sym = Scanner.rparen THEN Scanner.Get( sym ) END 
			ELSE Scanner.Mark( "ident or (?" )
			END;  
			
			IF sym = Scanner.gt THEN Scanner.Mark( "> to early" );  EXIT END;  
			
			IF (sym = Scanner.ident) THEN attr.default := Scanner.id;  Scanner.Get( sym )
			ELSE Scanner.Mark( "ident?" )
			END;  
			attr.next := attrs.next;  attrs.next := attr;  
			
			IF sym = Scanner.gt THEN EXIT END;  
			IF sym # Scanner.ident THEN Scanner.Mark( "ident (AttlistDef)" );  EXIT END;  
		END;  
		WHILE element # NIL DO element.attributes := attrs.next;  element := element.slink END 
	END AttListDef;  

	PROCEDURE Definitions;  
	BEGIN 
		WHILE sym # Scanner.eof DO 
			CASE sym OF 
			   Scanner.element: 
					Scanner.Get( sym );  ElementDef;  
			| Scanner.attlist: 
					Scanner.Get( sym );  AttListDef;  
			ELSE 
				WHILE (sym # Scanner.element) & (sym # Scanner.attlist) & (sym # Scanner.eof) DO Scanner.Get( sym );  END;  
			END  
		END 
	END Definitions;  

	PROCEDURE Parse*( name: ARRAY OF CHAR;  pos: LONGINT ): ElementType;  
	VAR T: Texts.Text;  fix: Fix;  pcdataElementType: ElementType;  
	BEGIN 
		NEW( T );  Texts.Open( T, name );  Scanner.Init( T, pos );  Scanner.Get( sym );  

		NEW( pcdataElementType );  pcdataElementType.name := "#PCDATA";  
		Definitions;  
		fixElement( "#PCDATA", pcdataElementType );  
		
		IF FixList # NIL THEN 
			IF debug THEN Out.String( "fixList not empty" );  Out.Ln END;  
			fix := FixList;  
			WHILE fix # NIL DO 
				IF debug THEN Out.String( "Not fixed : " );  Out.String( fix.what );  Out.Ln END;  
				fix := fix.next
			END 
		END;  
		RETURN Elements
	END Parse;  

END WebSGML.