//
// Copyright (c) 2009, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 09  Andy Frank  Creation
//

using compiler

**
** JsNode translates a compiler::Node into the equivalent JavaScript
** source code.
**
abstract class JsNode
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(CompilerSupport support)
  {
    this.support = support
  }

//////////////////////////////////////////////////////////////////////////
// Write
//////////////////////////////////////////////////////////////////////////

  **
  ** Write the JavaScript source code for this node.
  **
  abstract Void write(JsWriter out)

//////////////////////////////////////////////////////////////////////////
// JavaScript
//////////////////////////////////////////////////////////////////////////

  **
  ** Return the JavaScript qname for this CType.
  **
  Str qnameToJs(CType ctype)
  {
    // use this method as a hook to look for synthentic types
    // used in compiled types that we need to emit
    if (ctype.isSynthetic)
    {
      if (ctype.qname.contains("Curry\$"))
      {
        list := (support.compiler as JsCompiler).synth
        if (!list.contains(ctype)) list.add(ctype)
      }
    }
    /*
    else
    {
      // also use this method to verify referenced types
      // have been configured to be compiled to js as well
      if (!Type.find(ctype.qname).facet(@js, false))
        support.err("Type not available in JavaScript: $ctype.qname")
    }
    */

    return "fan.${ctype.pod.name}.$ctype.name"
  }

  **
  ** Return the JavaScript variable name for the given Fan
  ** variable name.
  **
  Str vnameToJs(Str name)
  {
    if (vnames.get(name, false)) return "\$$name";
    return name;
  }

  private const Str:Bool vnames :=
  [
    "char":   true,
    "delete": true,
    "import": true,
    "in":     true,
    "var":    true,
    "with":   true
  ].toImmutable


  Str unique()
  {
    Int id := Actor.locals["compilerJs.lastId"] ?: 0
    Actor.locals["compilerJs.lastId"] = id + 1
    return "\$_u$id"
  }

  CompilerSupport support

}