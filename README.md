# gadgets-webnav

WebNavigator for the desktop of [polpo](https://github.com/polpo-system/polpo): an HTML 4 browser
with Cascading Style Sheets (CSS 2). It lays out headings, paragraphs, lists, tables, frames and
pictures (GIF, JPEG and PNG, through Pictures and the packages gif, jpeg and png), follows links and fetches pages over HTTP and HTTPS (TLS 1.3 of polpo's tls
package), following redirects. Pages in UTF-8 are shown with the characters of the Oberon fonts.
Scripts and most style sheets of today's pages are ignored.

```
portia.Install gadgets-webnav
```

## Using

    Desktops.OpenDoc "file://WebNavigatorAbout.html" (WebNavDocs.NewDoc) ~
    Desktops.OpenDoc "https://info.cern.ch/" (WebNavDocs.NewDoc) ~

In the desktop the finder has the entry WebNavigator, which opens a start page with links (the
file share/WebNavigator.Finder makes the entry). A middle click on a link follows it; Back and
Reload are in the menu bar of the document. `tools/WebNavigator.Tool` has more, also how to open
any address and every http and file address with it.

## What is here

    src/WebUtils.Mod           URLs
    src/WebPieces.Mod          pieces of a file
    src/WebSGMLScanner.Mod     the DTD of HTML 4 (share/WebHTML4Loose.SGML)
    src/WebSGML.Mod
    src/WebHTML4Scanner.Mod    HTML 4 into a tree of elements
    src/WebHTML4.Mod
    src/WebCSS2Scanner.Mod     style sheets (share/WebHTML4.CSS is the default one)
    src/WebCSS2.Mod
    src/WebCSS2P.Mod
    src/WebNetwork.Mod         HTTP and HTTPS through the http and httpsPure modules (HTTPDocs0
                               and NetTools for a proxy)
    src/WebCSS2Format.Mod      the tree with its styles into blocks and lines
    src/WebCSS2B.Mod           the layout into boxes, drawing
    src/WebNavDocs.Mod         the document (WebNavDocs.NewDoc)
    src/WebNavigators.Mod      an older panel of the browser
    share/                     the pages that come with it, pictures, the DTD, the style sheet,
                               WebNavigator.Text (the diploma thesis, in German), the start page
                               WebNavStart.html and WebNavigator.Finder (the entry of the finder)
    tools/WebNavigator.Tool
    test/WebNavTest.Mod

WebNavigator was written by Bruno Eberhard as a diploma thesis at ETH Zurich (1998-1999) and
released by ETH as WebNavBeta4.Arc in December 2000. The first commit has its files unchanged
(the sources and the tool text converted from Oberon texts to plain text). The later commits make
it run with all of polpo's compilers: plain exports and HALT numbers, local variables set before
they are read (the x86 compiler happened to leave zeros in them), the end of a URL, and a call in
the older panel. Then HTTPS, UTF-8 and pages of HTML 5 whose elements made the parser split the
body.

## Tests

    WebNavTest.Run      24 checks: URLs (of file:// pages too), two pages parsed and laid out, a page of HTML 5, a
                        document opened from a file; it needs the desktop's display

The license is GPL-3 (`LICENSE`); the code comes from ETH Oberon, whose license (`LICENSE.ETH`)
asks to keep its copyright notice and conditions, which `LICENSE.ETH` does.
