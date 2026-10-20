Welcome to WebNavigator

What is WebNavigator?
A HTML 4.0 browser with Cascading Style Sheets for ETH Oberon.

Where to get WebNavigator?
http://www.oberon.ethz.ch/software/WebNavigator.html

Documentation
WebNavigator.Text (out of date)

Demo
Desktops.OpenDoc "file://WebNavigatorAbout.html" (WebNavDocs.NewDoc) ~
Desktops.OpenDoc "http://www.oberon.ethz.ch/" (WebNavDocs.NewDoc)
Desktops.OpenDoc "http://www.inf.ethz.ch/" (WebNavDocs.NewDoc)
Desktops.OpenDoc "http://www.sun.com/" (WebNavDocs.NewDoc)
Desktops.OpenDoc "http://www.informatik.uni-bremen.de/" (WebNavDocs.NewDoc)

Gadgets.Insert WebNavigators.NewPanel ~ 

Installation
Compress.ExtractAll WebNavBeta3.Arc ~

Compiler.Compile \2s 
	WebUtils.Mod   WebNetwork.Mod   WebPieces.Mod
	WebSGMLScanner.Mod   WebSGML.Mod 
	WebHTML4Scanner.Mod WebHTML4.Mod 
	WebCSS2.Mod   WebCSS2Scanner.Mod   WebCSS2P.Mod   WebCSS2Format.Mod   WebCSS2B.Mod 
	WebNavDocs.Mod ~
	
	WebNavigators.Mod	{ not up to date! }
	
If you want to make NavDocs the default for HTML documents edit Oberon.Text and make the
following changes in the DocumentServices section:

	file = HyperDocs.NewDoc	-->    file = WebNavDocs.NewDoc
	http = HTTPDocs.NewDoc	-->    http = WebNavDocs.NewDoc
	

Unload
System.Free WebNavigators WebNavDocs WebCSS2B WebCSS2Format WebCSS2P WebCSS2Scanner WebCSS2 
	WebHTML4 WebSGML WebSGMLScanner WebHTML4Scanner WebPieces WebNetwork WebUtils~

Create distribution
System.DeleteFiles WebNavBeta4.Arc ~
Compress.Add WebNavBeta4.Arc 
	WebUtils.Mod   WebNetwork.Mod   WebPieces.Mod
	WebSGMLScanner.Mod   WebSGML.Mod 
	WebHTML4Scanner.Mod WebHTML4.Mod 
	WebCSS2.Mod WebCSS2Scanner.Mod WebCSS2P.Mod WebCSS2Format.Mod WebCSS2B.Mod 
	WebNavigators.Mod WebNavDocs.Mod 
	
	WebHTML4Loose.SGML   WebHTML4.CSS   
	WebNavigatorAbout.html   WebNotFound.html   WebNotSupported.html
	WebNav.gif   WebNavSmall.gif   WebNavFonts.html   WebNavTables.html 
	WebNavigator.Text   WebNavigator.Tool ~

Note: use EditTools.OpenAscii ^ and EditTools.StoreAscii * to edit .html files.

History

21.12.1998	Bruno Eberhard	Diplomarbeit started

20.04.1999	Bruno Eberhard	Diplomarbeit ended
	"http://www.cs.inf.ethz.ch/gutknecht/stud_work/1998WS_eberhard/HTML4.Arc"
	"http://www.cs.inf.ethz.ch/gutknecht/stud_work/1998WS_eberhard/Dokumentation.Text"
	"http://www.cs.inf.ethz.ch/gutknecht/stud_work/1998WS_eberhard/HTML4T.ARC"

??.??.1999	Bruno Eberhard	Maintanance

04.04.2000	prk	Placed on web
25.05.2000	pjm	Beta release 1
30.05.2000	pjm	Beta release 2 (tool fixed)
27.11.2000	g.f.	Beta release 3 (network interface added, 'Back' added to Menu bar of WebNavDocs)
10.12.2000	g.f.	Beta release 4 (border handling fixed, appropriation of links to frames fixed)

To do
o big: user interface: enter URL, Back, Forward, Reload
o medium: implement printing
o medium: clever update - no flicker (Images?)
o small: <P> should generate line space
o small: fix list numbering
o small: use Courier font for <pre>
