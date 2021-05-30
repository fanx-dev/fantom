//
// Copyright (c) 2011, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Aug 11  Brian Frank  Creation
//

**
** ApiDocParser is used to parse the text file syntax of the
** apidoc file generated by the compiler.  These files are
** designed to give us full access everything we need to build
** a documentation model of pods, types, and slots using a
** simple human readable format.
**
** The syntax is defined as:
**   <file>      :=  <class> <slot>*
**   <class>     :=  "== " <name> <nl> <attrs>
**   <slot>      :=  (<fieldSig> | <methodSig>) <attrs>
**   <fieldSig>  :=  "-- " <name> <sp> <type> [":=" <expr>] <nl>
**   <methodSig> :=  "-- " <name> "(" <nl> [<param> <nl>]* ")" <sp> <return> <nl>
**   <param>     :=  <name> <type> [":=" <expr>]
**   <return>    :=  <type>
**
**   <attrs>     :=  <meta>* <facet>* <nl> <doc>.
**   <meta>      :=  <name> "=" <expr> <nl>
**   <facet>     :=  "@" <type> ["{" <nl> [<name> "=" <expr> <nl>]* "}"] <nl>
**   <doc>       :=  lines of text until "-- "
**
**   <name>      :=  Fantom identifier
**   <type>      :=  Fantom type signature (no spaces allowed)
**   <expr>      :=  text until end of line
**   <nl>        :=  "\n"
**   <sp>        :=  " "
**
** Standard attributes:
**   - base: list of space separated base class type signatures
**   - mixins: list of space separated mixin type signatures
**   - loc: <file> ":" <line> "/" <docLine>
**   - flags: type or slot space separated flag keywords
**   - set: field setter flags
**
** Note that the grammar is defined such that expr to display
** in docs for field and parameter defaults is always positioned at
** the end of the line (avoiding nasty escaping problems).
**
internal class ApiDocParser
{
  new make(DocPod pod, InStream in)
  {
    this.pod = pod
    this.in = in
    consumeLine
  }

  DocType parseType(Bool close := true)
  {
    try
    {
      // == <name>
      if (!cur.startsWith("== ")) throw Err("Expected == <name>")
      name := cur[3..-1]
      consumeLine

      // parse attrs
      attrs  := parseAttrs
      this.typeRef = DocTypeRef("${pod.name}::${name}")
      this.typeLoc = attrs.loc

      // zero or more slots
      list := DocSlot[,]
      map  := Str:DocSlot[:]
      while (true)
      {
        slot := parseSlot
        if (slot == null) break
        list.add(slot)
        map[slot.name] = slot
      }

      // construct DocType from my own fields
      return DocType(pod, attrs, typeRef, list, map)
    }
    finally { if (close) in.close }
  }

  private DocSlot? parseSlot()
  {
    // check if at end of file
    if (cur.isEmpty) return null

    // "-- " <name> <sp> <type> [":=" <expr>]
    // "-- " <name> "(" <nl> [<param> <nl>]* ")" <return>
    if (!cur.startsWith("-- ")) throw Err("Expected -- <name>")
    if (cur[cur.size-1] == '(')
      return parseMethod
    else
      return parseField
  }

  private DocField parseField()
  {
    //  "-- " <name> <sp> <type> [":=" <expr>]
    sp    := cur.index(" ", 4)
    initi := cur.index(":=", sp+1)
    name  := cur[3..<sp]
    type  := cur[sp+1 ..< (initi ?: cur.size)]
    init  := initi == null ? null : cur[initi+2..-1]
    consumeLine
    attrs  := parseAttrs
    return DocField(attrs, typeRef, name, DocTypeRef(type), init)
  }

  private DocMethod parseMethod()
  {
    // "-- " <name> "(" <nl> [<param> <nl>]* ")" <return>

    // tokenize by space
    name := cur[3..-2]
    consumeLine

    // parse params
    params := DocParam[,]
    while (cur[0] != ')')
    {
      sp    := cur.index(" ")
      defi_  := cur.index(":=", sp+1)
      pname := cur[0..<sp]
      type  := cur[sp+1 ..< (defi_ ?: cur.size)]
      def   := defi_ == null ? null : cur[defi_+2..-1]
      params.add(DocParam(DocTypeRef(type), pname, def))
      consumeLine
    }
    returns := DocTypeRef(cur[2..-1])
    consumeLine

    // attrs, facets, and doc
    attrs := parseAttrs
    attrs.flags = attrs.flags.and(DocFlags.Const.not)
    return DocMethod(attrs, typeRef, name, returns, params)
  }

  ** Parse meta name/val pairs, facets, and fandoc section
  private DocAttrs parseAttrs()
  {
    attrs := DocAttrs()
    parseMeta(attrs)
    parseFacets(attrs)
    parseDoc(attrs)
    return attrs
  }

  private Void parseMeta(DocAttrs attrs)
  {
    while (!cur.isEmpty && cur[0].isAlpha)
    {
      eq   := cur.index("=")
      name := cur[0..<eq]
      val  := cur[eq+1..-1]
      switch (name)
      {
        case "loc":    parseLoc(attrs, val)
        case "flags":  attrs.flags = DocFlags.fromNames(val)
        case "base":   attrs.base   = parseTypeList(val)
        case "mixins": attrs.mixins = parseTypeList(val)
        case "set":    attrs.setterFlags = DocFlags.fromNames(val)
      }
      consumeLine
    }
  }

  private Void parseLoc(DocAttrs attrs, Str val)
  {
    colon   := val.index(":")
    slash   := val.indexr("/")
    file    := colon == 0 ? this.typeLoc.file : val[0..<colon]
    line    := val[colon+1 ..< (slash ?: val.size)].toInt
    docLine := slash != null ? val[slash+1..-1].toInt : line
    attrs.loc    = DocLoc(file, line)
    attrs.docLoc = DocLoc(file, docLine)
  }

  private DocTypeRef[] parseTypeList(Str val)
  {
    val.split.map |tok->DocTypeRef| { DocTypeRef(tok) }
  }

  private Void parseFacets(DocAttrs attrs)
  {
    facet := parseFacet
    if (facet == null) return
    acc := [facet]
    while ((facet = parseFacet) != null) acc.add(facet)
    attrs.facets = acc
  }

  private DocFacet? parseFacet()
  {
    if (!cur.startsWith("@")) return null

    complex := cur[cur.size-1] == '{'
    type := DocTypeRef(cur[1..(complex ? -2 : -1)])
    fields := DocFacet.noFields

    consumeLine
    if (complex)
    {
      fields = OrderedMap<Str,Str>()//[:]
      //fields.ordered = true
      while (cur != "}")
      {
        eq := cur.index("=")
        name := cur[0..<eq]
        val  := cur[eq+1..-1]
        fields[name] = val
        consumeLine
      }
      consumeLine  // trailing "}"
    }

    return DocFacet(type, fields)
  }

  private Void parseDoc(DocAttrs attrs)
  {
    if (!cur.isEmpty) throw Err("expecting empty line")
    consumeLine

    s := StrBuf(256)
    while (!eof && !cur.startsWith("-- "))
    {
      s.add(cur).addChar('\n')
      consumeLine
    }
    attrs.doc = DocFandoc(attrs.docLoc, s.toStr)
  }

  private Void consumeLine()
  {
    next := in.readLine
    if (next != null) cur = next
    else { cur = ""; eof = true }
  }

  private InStream in
  private const DocPod pod
  private Str cur := ""
  private DocLoc typeLoc := DocLoc.unknown
  private DocTypeRef? typeRef
  private Bool eof
}

internal class DocAttrs
{
  Int flags
  DocLoc loc := DocLoc.unknown
  DocLoc docLoc := DocLoc.unknown
  Int? setterFlags
  DocTypeRef[] base   := List.defVal//DocTypeRef#.emptyList
  DocTypeRef[] mixins := List.defVal//DocTypeRef#.emptyList
  DocFacet[] facets   := List.defVal//DocFacet#.emptyList
  DocFandoc? doc
}