MODULE WebNavTest;  (** WebNavTest.Run: URLs, parsing, layout and a document of WebNavigator; needs the desktop's display *)

IMPORT Files, Objects, Gadgets, Documents, Out := out, U := WebUtils, HTML4 := WebHTML4, CSS2 := WebCSS2,
  CSS2P := WebCSS2P, Format := WebCSS2Format, CSS2B := WebCSS2B;

VAR fails, checks: LONGINT;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); Out.String("FAIL "); Out.String(what); Out.Ln END
END Check;

PROCEDURE Url(base, link, want: ARRAY OF CHAR);
VAR u: U.ustring; i: INTEGER;
BEGIN
  i := 0; WHILE i < LEN(u) - 1 DO u[i] := "x"; INC(i) END; u[i] := 0X;  (* NewUrl must end the URL itself *)
  U.NewUrl(base, link, u); Check(want, u = want)
END Url;

PROCEDURE Urls;
VAR s: U.ustring;
BEGIN
  Url("http://host/a/b.html", "", "http://host/a/b.html");
  Url("http://host/a/b.html", "c.html", "http://host/a/c.html");
  Url("http://host/a/b.html", "/d.html", "http://host/d.html");
  Url("http://host/a/b.html", "http://other/", "http://other/");
  s := "http%3A//host/x%20y"; U.CleanURL(s); Check("CleanURL", s = "http://host/x y")
END Urls;

(* a page from share/ parsed, formatted and laid out 600 pixels wide *)
PROCEDURE Layout(name: ARRAY OF CHAR; css: CSS2.StyleSheet);
VAR html, body: HTML4.Element; b: Format.Block; box: CSS2B.Box; w, h: LONGINT; links: CSS2B.Link;
  anchors: CSS2B.Anchor;
BEGIN
  html := HTML4.Read(Files.Old(name)); Check(name, html # NIL);
  IF html # NIL THEN
    body := HTML4.ThisChild(html, "BODY"); Check("BODY", body # NIL);
    IF body # NIL THEN
      b := Format.Traverse(body, css, name); Check("blocks", b # NIL);
      w := 600; box := CSS2B.Layout(b, w, h, links, anchors);
      Check("boxes", box # NIL); Check("width", (w > 0) & (w <= 600)); Check("height", (h > 0) & (h < 10000))
    END
  END
END Layout;

PROCEDURE Doc(url: ARRAY OF CHAR);
VAR obj: Objects.Object; d: Documents.Document;
BEGIN
  obj := Gadgets.CreateObject("WebNavDocs.NewDoc");
  IF (obj # NIL) & (obj IS Documents.Document) THEN
    d := obj(Documents.Document); COPY(url, d.name); d.Load(d); Check(url, d.dsc # NIL)
  ELSE Check("WebNavDocs.NewDoc", FALSE)
  END
END Doc;

PROCEDURE Run*;
VAR css: CSS2.StyleSheet;
BEGIN
  fails := 0; checks := 0;
  Urls;
  css := CSS2P.ReadStyleSheet(Files.Old("WebHTML4.CSS"), 0); Check("WebHTML4.CSS", css # NIL);
  Layout("WebNavTables.html", css); Layout("WebNavFonts.html", css);
  Doc("file://WebNavigatorAbout.html");
  Out.String("WebNavTest: "); Out.Int(checks, 0); Out.String(" checks, "); Out.Int(fails, 0); Out.String(" failed"); Out.Ln
END Run;

END WebNavTest.
