WebNavigator - an HTML 4 browser with style sheets (CSS 2) for the desktop

Open a page (http:// and file:// addresses; there is no HTTPS):
  Desktops.OpenDoc "file://WebNavigatorAbout.html" (WebNavDocs.NewDoc) ~
  Desktops.OpenDoc "file://WebNavTables.html" (WebNavDocs.NewDoc) ~
  Desktops.OpenDoc "file://WebNavFonts.html" (WebNavDocs.NewDoc) ~
  Desktops.OpenDoc "http://info.cern.ch/" (WebNavDocs.NewDoc) ~

A middle click on a link follows it; Back in the menu bar goes to the page before,
Reload loads the page again.

To open every http and file address with WebNavigator, change the section
DocumentServices of Oberon.Text:
  http = HTTPDocs.NewDoc    becomes    http = WebNavDocs.NewDoc
  file = HyperDocs.NewDoc   becomes    file = WebNavDocs.NewDoc

An older panel of the browser, not kept up to date:
  Gadgets.Insert WebNavigators.NewPanel ~

The diploma thesis behind it (in German, partly out of date):
  Edit.Open WebNavigator.Text

Unload:
  System.Free WebNavigators WebNavDocs WebCSS2B WebCSS2Format WebCSS2P WebCSS2Scanner
    WebCSS2 WebHTML4 WebSGML WebSGMLScanner WebHTML4Scanner WebPieces WebNetwork WebUtils ~

History
  21.12.1998  Bruno Eberhard  diploma thesis started (ETH Zurich, J. Gutknecht, E. Zeller)
  20.04.1999  Bruno Eberhard  diploma thesis ended
  04.04.2000  prk             placed on the web
  25.05.2000  pjm             beta release 1
  30.05.2000  pjm             beta release 2
  27.11.2000  g.f.            beta release 3 (network interface, Back in the menu bar)
  10.12.2000  g.f.            beta release 4 (borders, links to frames)
  2026        polpo           runs on all ports of polpo (see the commits)
