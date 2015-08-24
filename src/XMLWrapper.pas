{$include project.inc}

unit XMLWrapper;

interface

uses
  {$ifdef fpc}
    Classes,
    //xmlIntf,
    dom, xmlread, xmlwrite
  {$else} {$ifdef MSXML}
    {MS}
    msxml, activex
  {$else}
    xmlIntf, xmlDoc, activex
  {$endif} {$endif}
  ;

{$undef xml_element_is_equal_to_node}

{$ifdef fpc}
type

//IXMLDOMDocument    = dom.TDOMDocument    ;
  IXMLDOMDocument    = dom.TXMLDocument    ;
  IXMLDOMNode        = dom.TDOMNode        ;
  IXMLDOMElement     = dom.TDOMElement     ;
//IXMLDOMElement     = dom.TDOMNode        ;
  IXMLDOMAttribute   = dom.TDOMAttr        ;
  IXMLDOMNodeList    = dom.TDOMNodeList    ;
  IXMLDOMNamedNodeMap= dom.TDOMNamedNodeMap;

{$else} {$ifdef MSXML}

type

  IXMLDOMDocument    = msxml.IXMLDOMDocument    ;
  IXMLDOMNode        = msxml.IXMLDOMNode        ;
  IXMLDOMElement     = msxml.IXMLDOMElement     ;
  IXMLDOMAttribute   = msxml.IXMLDOMAttribute   ;
  IXMLDOMNodeList    = msxml.IXMLDOMNodeList    ;
  IXMLDOMNamedNodeMap= msxml.IXMLDOMNamedNodeMap;

{$else}

type

  IXMLDOMDocument    = xmlIntf.IXMLDocument;
  IXMLDOMNode        = xmlIntf.IXMLNode    ;
  IXMLDOMElement     = xmlIntf.IXMLNode    ;
  IXMLDOMAttribute   = xmlIntf.IXMLNode    ;
  IXMLDOMNodeList    = xmlIntf.IXMLNodeList;
  IXMLDOMNamedNodeMap= xmlIntf.IXMLNodeList;

{$define xml_element_is_equal_to_node}

{$endif} {$endif}

function nodeOwnerDocument(src   : IXMLDOMNode    ): IXMLDOMDocument    ; overload;
function nodeOwnerDocument(src   : IXMLDOMDocument): IXMLDOMDocument    ; overload;

function nodeListCount (src   : IXMLDOMNodeList    ): integer            ; overload;
function nodeMapCount  (src   : IXMLDOMNamedNodeMap): integer            ; overload;
function nodeCount     (src   : IXMLDOMDocument    ): integer            ; overload;
function nodeCount     (src   : IXMLDOMNode        ): integer            ; overload;
function nodeCount     (src   : IXMLDOMNodeList    ): integer            ; overload;
function nodeValue     (src   : IXMLDOMNode        ): String             ; overload; // for text node
function nodeValueDef  (src   : IXMLDOMNode         ;
                        defVal: String             ): String             ; overload; // for text node
function nodeAt        (src   : IXMLDOMNode         ;
                        index : integer            ): IXMLDOMNode        ; overload;
function nodeAt        (src   : IXMLDOMDocument     ;
                        index : integer            ): IXMLDOMNode        ; overload;
function nodeAt        (src   : IXMLDOMNodeList     ;
                        index : integer            ): IXMLDOMNode        ; overload;
function nodeFirst     (src   : IXMLDOMNode        ): IXMLDOMNode        ; overload;
function nodeFirst     (src   : IXMLDOMDocument    ): IXMLDOMElement     ; overload;
function nodeTag       (src   : IXMLDOMNode        ): String             ; overload;
function nodeAttrs     (src   : IXMLDOMNode        ): IXMLDOMNamedNodeMap; overload;
function hasAttr       (src   : IXMLDOMNode         ;
                        name  : String             ): boolean            ; overload;
function attrCount     (src   : IXMLDOMNode        ): integer            ; overload;
function attrNode      (src   : IXMLDOMNode         ;
                        index : integer            ): IXMLDOMAttribute   ; overload;
function attrNode      (src   : IXMLDOMNode         ;
                        name  : String             ): IXMLDOMAttribute   ; overload;
function attrName      (src   : IXMLDOMAttribute   ): String             ;
function attrValue     (src   : IXMLDOMNode         ;
                        name  : String             ): String             ; overload;
function createElement (doc   : IXMLDOMDocument     ;
                        tag   : String             ): IXMLDOMElement     ; overload;
function createTextNode(doc   : IXMLDOMDocument     ;
                        text  : String             ): IXMLDOMNode        ; overload;
function appendChild   (parent: IXMLDOMElement      ;
                        child : IXMLDOMElement     ): IXMLDOMElement     ; overload;
function appendChild   (parent: IXMLDOMDocument     ;
                        child : IXMLDOMElement     ): IXMLDOMElement     ; overload;
{$ifndef xml_element_is_equal_to_node}
function appendChild   (parent: IXMLDOMNode         ;
                        child : IXMLDOMElement     ): IXMLDOMElement     ; overload;
function appendChild   (parent: IXMLDOMNode         ;
                        child : IXMLDOMNode        ): IXMLDOMNode        ; overload;
function appendChild   (parent: IXMLDOMElement      ;
                        child : IXMLDOMNode        ): IXMLDOMNode        ; overload;
{$endif}
function findFirstNodeByTagAttrValue(parent: IXMLDOMNode    ; tag, attr, value: String): IXMLDOMElement; overload;
function findFirstNodeByTag         (parent: IXMLDOMNode    ; tag             : String): IXMLDOMElement; overload;
function findFirstNodeByTagAttrValue(parent: IXMLDOMNodeList; tag, attr, value: String): IXMLDOMElement; overload;
function findFirstNodeByTag         (parent: IXMLDOMNodeList; tag             : String): IXMLDOMElement; overload;

function createDocument  (): IXMLDOMDocument; overload;
function createDocumentNI(): IXMLDOMDocument; overload;
function createDocument(encoding: String): IXMLDOMDocument; overload;

procedure setDocumentElement(document: IXMLDOMDocument; element: IXMLDOMElement);

function nodeToString      (src: IXMLDOMNode       ): String; overload;
function documentToString  (src: IXMLDOMDocument   ): String; overload;
//function documentToStringNI(src: IXMLDOMDocument   ): String; overload;

function documentFromString(src: String            ): IXMLDOMDocument; overload;{
function documentFromStream(src: TStream           ): IXMLDOMDocument; overload;}
function documentFromFile  (fileName: String       ): IXMLDOMDocument; overload;

procedure setAttrValue     (src   : IXMLDOMElement  ;
                            name  : String          ;
                            value : String         ); overload;
procedure nodeClose        (src   : IXMLDOMNode    ); overload;
procedure nodeClose        (src   : IXMLDOMDocument); overload;

procedure coInitializeThread();

function nodeFirstValue    (src   : IXMLDOMNode     ;
                            defVal: String         ): String;

function isTextNode        (src   : IXMLDOMNode    ): boolean;
function isElementNode     (src   : IXMLDOMNode    ): boolean;

implementation

function nodeCount    (src   : IXMLDOMDocument  ): integer            ;
  {$ifdef MSXML}
    begin
      result:= src.childNodes.length;
    end;
  {$else}
    begin
      result:= src.childNodes.count;
    end;
  {$endif}

function nodeCount    (src   : IXMLDOMNode      ): integer            ;
  {$ifdef MSXML}
    begin
      result:= src.childNodes.length;
    end;
  {$else}
    begin
      result:= src.childNodes.count;
    end;
  {$endif}

function nodeCount     (src   : IXMLDOMNodeList    ): integer            ; overload;
  {$ifdef MSXML}
    begin
      result:= src.length;
    end;
  {$else}
    begin
      result:= src.count;
    end;
  {$endif}

function nodeValue     (src   : IXMLDOMNode        ): String             ; overload;
  {$ifdef fpc}
    begin
      result:= src.nodeValue;
    end;
  {$else}
    begin
      result:= src.text;
    end;
  {$endif}

function nodeValueDef  (src   : IXMLDOMNode         ;
                        defVal: String             ): String             ; overload;
  begin
    if assigned(src) then
      result:= nodeValue(src)
    else
      result:= defVal;
  end;


function nodeFirst    (src   : IXMLDOMNode     ): IXMLDOMNode;
  {$ifdef fpc}
    begin
      result:= src.childNodes[0]{ as IXMLDOMElement};
    end;
  {$else}
    begin
      result:= src.childNodes.first;
    end;
  {$endif}

function nodeFirst    (src   : IXMLDOMDocument ): IXMLDOMElement     ;
  begin
    result:= src.documentElement;
  end;

function nodeAt       (src   : IXMLDOMNode      ;
                       index : integer         ): IXMLDOMNode; overload;
  {$ifdef fpc}
    begin
      result:= src.childNodes[index]{ as IXMLDOMElement};
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.childNodes[index];
    end;
  {$else}
    begin
      result:= src.childNodes[index];
    end;
  {$endif} {$endif}

function nodeAt       (src   : IXMLDOMDocument     ;
                       index : integer            ): IXMLDOMNode; overload;
  {$ifdef fpc}
    begin
      result:= src.childNodes[index]{ as IXMLDOMElement};
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.childNodes[index];
    end;
  {$else}
    begin
      result:= src.childNodes[index];
    end;
  {$endif} {$endif}

function nodeAt        (src   : IXMLDOMNodeList     ;
                        index : integer            ): IXMLDOMNode; overload;
  {$ifdef fpc}
    begin
      result:= src[index]{ as IXMLDOMElement};
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src[index];
    end;
  {$else}
    begin
      result:= src[index];
    end;
  {$endif} {$endif}

function nodeOwnerDocument(src   : IXMLDOMNode    ): IXMLDOMDocument;
  {$ifdef fpc}
    begin
      result:= src.ownerDocument as IXMLDOMDocument;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.ownerDocument;
    end;
  {$else}
    begin
      result:= src.ownerDocument;
    end;
  {$endif} {$endif}

function nodeOwnerDocument(src   : IXMLDOMDocument): IXMLDOMDocument; begin result:= src; end;

function nodeListCount(src: IXMLDOMNodeList): integer;
  {$ifdef MSXML}
    begin
      result:= src.length;
    end;
  {$else}
    begin
      result:= src.count;
    end;
  {$endif}

function nodeMapCount (src   : IXMLDOMNamedNodeMap): integer            ;
  {$ifdef fpc}
    begin
      result:= src.length;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.length;
    end;
  {$else}
    begin
      result:= src.count;
    end;
  {$endif} {$endif}

function nodeTag  (src: IXMLDOMNode    ): String;
  {$ifdef MSXML}
    begin
      result:= src.tagName ;
    end;
  {$else}
    begin
      result:= src.nodeName;
    end;
  {$endif}

function nodeAttrs(src: IXMLDOMNode    ): IXMLDOMNamedNodeMap;
  {$ifdef fpc}
    begin
      result:= src.attributes    ;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.attributes    ;
    end;
  {$else}
    begin
      result:= src.attributeNodes;
    end;
  {$endif} {$endif}

function hasAttr      (src   : IXMLDOMNode      ;
                       name  : String          ): boolean            ;
  {$ifdef fpc}
    begin
      result:= assigned(src.attributes.getNamedItem(name));
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.hasAttribute(name);
    end;
  {$else}
    begin
      result:= src.hasAttribute(name);
    end;
  {$endif} {$endif}

function attrCount(src: IXMLDOMNode    ): integer;
  {$ifdef fpc}
    begin
      result:= src.attributes    .length;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.attributes    .length;
    end;
  {$else}
    begin
      result:= src.attributeNodes.count;
    end;
  {$endif} {$endif}

function attrNode (src: IXMLDOMNode    ; index: integer): IXMLDOMAttribute;
  {$ifdef fpc}
    begin
      result:= src.attributes    [index] as IXMLDOMAttribute;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.attributes    [index];
    end;
  {$else}
    begin
      result:= src.attributeNodes[index];
    end;
  {$endif} {$endif}

function attrNode (src: IXMLDOMNode; name  : String): IXMLDOMAttribute;
  {$ifdef fpc}
    begin
      result:= src.attributes.getNamedItem(name) as IXMLDOMAttribute;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.attributes    [name];
    end;
  {$else}
    begin
      result:= src.attributeNodes[name];
    end;
  {$endif} {$endif}

function attrName     (src: IXMLDOMAttribute): String ;
  {$ifdef MSXML}
    begin
      result:= src.name    ;
    end;
  {$else}
    begin
      result:= src.nodeName;
    end;
  {$endif}

function attrValue    (src   : IXMLDOMNode      ;
                       name  : String          ): String             ;
  {$ifdef fpc}
    begin
      result:= src.attributes.getNamedItem(name).textContent;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.attributes    [name].value;
    end;
  {$else}
    begin
      result:= src.attributeNodes[name].text;
    end;
  {$endif} {$endif}

function createElement(doc: IXMLDOMDocument; tag: String): IXMLDOMElement;
  {$ifdef fpc}
    begin
      result:= doc.createElement(tag);
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= doc.createElement(tag);
    end;
  {$else}
    begin
      result:= doc.createElement(tag, '');
    end;
  {$endif} {$endif}

function createTextNode(doc   : IXMLDOMDocument     ;
                        text  : String             ): IXMLDOMNode     ; overload;
  {$ifdef fpc}
    begin
      result:= doc.createTextNode(text);
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= doc.createTextNode(text);
    end;
  {$else}
    begin
      result:= doc.createNode(text, ntText);
    end;
  {$endif} {$endif}


function appendChild(parent, child: IXMLDOMElement): IXMLDOMElement;
  {$ifdef fpc}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else} {$ifdef MSXML}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else}
    begin
      parent.childNodes.add(child);
      result:= child;
    end;
  {$endif} {$endif}

function appendChild   (parent: IXMLDOMDocument     ;
                        child : IXMLDOMElement     ): IXMLDOMElement     ;
  {$ifdef fpc}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else} {$ifdef MSXML}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else}
    begin
      parent.childNodes.add(child);
      result:= child;
    end;
  {$endif} {$endif}


{$ifndef xml_element_is_equal_to_node}

function appendChild(parent: IXMLDOMNode; child : IXMLDOMElement): IXMLDOMElement;
  {$ifdef fpc}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else} {$ifdef MSXML}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else}
    begin
      parent.childNodes.add(child);
      result:= child;
    end;
  {$endif} {$endif}

function appendChild(parent: IXMLDOMNode; child : IXMLDOMNode): IXMLDOMNode;
  {$ifdef fpc}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else} {$ifdef MSXML}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else}
    begin
      parent.childNodes.add(child);
      result:= child;
    end;
  {$endif} {$endif}

function appendChild(parent: IXMLDOMElement; child: IXMLDOMNode): IXMLDOMNode;
  {$ifdef fpc}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else} {$ifdef MSXML}
    begin
      parent.appendChild(child);
      result:= child;
    end;
  {$else}
    begin
      parent.childNodes.add(child);
      result:= child;
    end;
  {$endif} {$endif}

{$endif}

function findFirstNodeByTagAttrValue(parent: IXMLDOMNode; tag, attr, value: String): IXMLDOMElement;
  {$ifdef MSXML}
    begin
      aChildNode:= parent.selectSingleNode(
        './' + tag   +
        '@[' + attr  +
        '="' + value + '"]'
        );
    end;
  {$else}
    var i   : integer    ;
    var node: IXMLDOMNode;
    begin
      result:= nil;
      for i:= 0 to nodeCount(parent) - 1 do
        begin
          node:= nodeAt(parent, i);
          if tag = nodeTag(node) then
            if hasAttr(node, attr) then
              if value = attrValue(node, attr) then
                begin
                  result:= node as IXMLDOMElement;
                  exit;
                end;
        end;
    end;
  {$endif}

function findFirstNodeByTag         (parent: IXMLDOMNode; tag             : String): IXMLDOMElement;
  var i   : integer    ;
  var node: IXMLDOMNode;
  begin
    result:= nil;
    for i:= 0 to nodeCount(parent) - 1 do
      begin
        node:= nodeAt(parent, i);
        if tag = nodeTag(node) then
          begin
            result:= node as IXMLDOMElement;
            exit;
          end;
      end;
  end;

function findFirstNodeByTagAttrValue(parent: IXMLDOMNodeList; tag, attr, value: String): IXMLDOMElement; overload;
  var i   : integer    ;
  var node: IXMLDOMNode;
  begin
    result:= nil;
    for i:= 0 to nodeCount(parent) - 1 do
      begin
        node:= nodeAt(parent, i);
        if tag = nodeTag(node) then
          if hasAttr(node, attr) then
            if value = attrValue(node, attr) then
              begin
                result:= node as IXMLDOMElement;
                exit;
              end;
      end;
  end;

function findFirstNodeByTag         (parent: IXMLDOMNodeList; tag             : String): IXMLDOMElement; overload;
  var i   : integer    ;
  var node: IXMLDOMNode;
  begin
    result:= nil;
    for i:= 0 to nodeCount(parent) - 1 do
      begin
        node:= nodeAt(parent, i);
        if tag = nodeTag(node) then
          begin
            result:= node as IXMLDOMElement;
            exit;
          end;
      end;
  end;

function createDocument(): IXMLDOMDocument;
  {$ifdef fpc}
    begin
      result:= TXMLDocument.create();
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= CoDOMDocument.Create;
    end;
  {$else}
    begin
      result:= newXMLDocument();
      result.options:= result.options + [doNodeAutoIndent];
      result.active:= true;
    end;
  {$endif} {$endif}

function createDocumentNI(): IXMLDOMDocument; overload;
  {$ifdef fpc}
    begin
      result:= TXMLDocument.create();
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= CoDOMDocument.Create;
    end;
  {$else}
    begin
      result:= newXMLDocument();
      result.options:= result.options - [doNodeAutoIndent];
      result.active:= true;
    end;
  {$endif} {$endif}


function createDocument(encoding: String): IXMLDOMDocument; overload;
  {$ifdef fpc}
    begin
      result:= TXMLDocument.create();
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= CoDOMDocument.Create;
    end;
  {$else}
    begin
      result:= newXMLDocument();
      result.encoding:= encoding;//'utf-8'
      result.options:= result.options + [doNodeAutoIndent];
      result.active:= true;
    end;
  {$endif} {$endif}


procedure setDocumentElement(document: IXMLDOMDocument; element: IXMLDOMElement);
  {$ifdef fpc}
    begin
      document.insertBefore(element, nodeFirst(document));
    end;
  {$else} {$ifdef MSXML}
    begin
      document.documentElement:= element;
    end;
  {$else}
    begin
      document.documentElement:= element;
    end;
  {$endif} {$endif}


function nodeToString(src: IXMLDOMNode): String;
  {$ifdef fpc}
    var temp: TMemoryStream;
    begin
      temp:= TMemoryStream.create();
      try
        writeXML(src, temp);
        setLength(result, temp.size);
        temp.position:= 0;
        temp.read(result[1], temp.size);
      finally
        temp.free();
        temp:= nil;
      end;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.xml;
    end;
  {$else}
    begin
      result:= src.xml;
    end;
  {$endif} {$endif}

function documentToString(src: IXMLDOMDocument): String;
  {$ifdef fpc}
    var temp: TMemoryStream;
    begin
      temp:= TMemoryStream.create();
      try
        writeXMLFile(src, temp);
        setLength(result, temp.size);
        temp.position:= 0;
        temp.read(result[1], temp.size);
      finally
        temp.free();
        temp:= nil;
      end;
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= src.xml;
    end;
  {$else}
    begin
      //result:= src.XML.Text;
      result:= src.node.xml;
    end;
  {$endif} {$endif}
(*
function documentToStringNI(src: IXMLDOMDocument   ): String; overload;
  {$ifdef fpc}
    begin
      result:= documentToString(src);
    end;
  {$else} {$ifdef MSXML}
    begin
      result:= documentToString(src);
    end;
  {$else}
    var saveOptions: TXMLDocOptions;
    begin
      saveOptions:= src.options;
      try
        src.options:= src.options - [doNodeAutoIndent];
        result:= documentToString(src);
      finally
        src.options:= saveOptions;
      end;
    end;
  {$endif} {$endif}
*)
function documentFromString(src: String         ): IXMLDOMDocument; overload;
  {$ifdef fpc}
    var temp: TMemoryStream;
    begin
      result:= nil;
      temp:= TMemoryStream.create();
      try
        temp.write(pchar(src)^, length(src));
        temp.position:= 0;
        readXMLFile(result, temp);
      finally
        temp.free();
        temp:= nil;
      end;
    end;
  {$else}
    begin
      result:= TXMLDocument.create(nil);
      result.xml.add(src);
      result.active:= true;
    end;
  {$endif}


function documentFromFile  (fileName: String       ): IXMLDOMDocument; overload;
  {$ifdef fpc}
    begin
      result:= nil;
      readXMLFile(result, fileName);
    end;
  {$else}
    begin
      result:= loadXMLDocument(fileName);
    end;
  {$endif}

procedure setAttrValue     (src   : IXMLDOMElement ;
                            name  : String         ;
                            value : String        ); overload;
  begin
    src.setAttribute(name, value);
  end;

procedure nodeClose      (src: IXMLDOMNode    ); overload;
  {$ifdef fpc}
    begin
      src.free();
    end;
  {$else}
    begin
    end;
  {$endif}

procedure nodeClose      (src: IXMLDOMDocument); overload;
  {$ifdef fpc}
    begin
      src.free();
    end;
  {$else}
    begin
    end;
  {$endif}

procedure coInitializeThread();
  begin
    {$ifdef fpc}
    {$else}
      coInitialize(nil);
    {$endif}
  end;

function nodeFirstValue    (src   : IXMLDOMNode     ;
                            defVal: String         ): String;
  var first: IXMLDOMNode;
  begin
    result:= defVal;
    if not assigned(src) then
      exit;

    first:= nodeFirst(src);
    if not assigned(first) then
      exit;

    result:= nodeValue(first);  
  end;

function isTextNode        (src   : IXMLDOMNode    ): boolean;
  {$ifdef fpc}
    begin
      result:= TEXT_NODE = src.NodeType;
    end;
  {$else} {$ifdef MSXML}
  {$else}
    begin
      result:= src.IsTextElement;
    end;
  {$endif} {$endif}

function isElementNode     (src   : IXMLDOMNode    ): boolean;
  {$ifdef fpc}
    begin
      result:= ELEMENT_NODE = src.NodeType;
    end;
  {$else} {$ifdef MSXML}
  {$else}
    begin
      result:= ntElement = src.NodeType;
    end;
  {$endif} {$endif}

initialization
  coInitializeThread();
  (*
  {$ifdef fpc}
  {$else}
    coInitialize(nil);
  {$endif}
  *)
end.