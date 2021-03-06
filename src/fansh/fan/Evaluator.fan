//
// Copyright (c) 2008, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jan 08  Brian Frank  Creation
//

using compiler

**
** Evaluator is responsible for compiling and
** evaluating a statement or expression.
**
class Evaluator
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Shell? shell)
  {
    if (shell != null)
    {
      this.shell = shell
      this.out = shell.out
    }
  }

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Bool eval(Str line)
  {
    // generate source for class which maps
    // local variables to scope map
    s := StrBuf()
    shell.usings.each |u| { s.add("using ").add(u.target).add("\n") }

    s.add(
      """class FanshEval
         {
           new make(Str:Obj s) { _scope = s }
           Str:Obj? _scope
           Obj? _eval()
           {
         """)
    scopeMap := Str:Obj?[:]
    if (shell != null)
    {
      shell.scope.each |Var v|
      {
        sig := typeSig(v.of)
        s.add("    $sig $v.name := _scope[\"$v.name\"];\n")
        scopeMap[v.name] = v.val
      }
    }
    srcPrefix := s.toStr

    // if line has a local variable definition, then we
    // want to capture it as part of the continuing scope
    ctrl := isCtrl(line)
    Var? local := null
    if (line.contains(":=") && !ctrl)
    {
      local = Var.make
      local.name = line[0..line.index(":=")-1].trim.split.last
      compile(srcPrefix + "    $line;\n    return $local.name\n  }\n}")
      if (pod != null)
        local.of = localDefType()
    }

    // if line has a local variable assignment, then we
    // want to capture it as part of the continuing scope
    else if (line.contains("=") && !ctrl)
    {
      eq := line.index("=")
      name := line[0..eq-1].trim
      expr := line[eq+1..-1].trim
      if (!expr.startsWith("="))
      {
        local = shell.findInScope(name)
        if (local != null)
          compile(srcPrefix + "    $expr\n  }\n}")
      }
    }

    // assuming we didn't have anything fishy regarding local variables,
    // then first try - this will fail if line is a Void expression
    if (pod == null)
      compile(srcPrefix + "    return $line\n  }\n}")

    // if that failed, try again assuming line is a void expression
    if (pod == null)
      compile(srcPrefix + "    $line;\n    return \"__void__\"\n  }\n}")

    // if no shell, this is a warmup
    if (shell == null) return false

    // if we still don't have a compile, report errors and bail
    if (pod == null)
    {
      reportCompilerErrs
      return false
    }

    // evaluate by calling eval
    t := pod.types.first
    method := t.method("_eval")
    Obj? result := null
    try
    {
      instance := t.make([scopeMap])
      result = method.callOn(instance, [,])
    }
    catch (Err e)
    {
      reportEvalErr(e)
      return false
    }

    // print result
    if (result != "__void__")
      out.printLine(result)

    // if we had a local def add (or replace) it to our scope
    if (local != null)
    {
      local.val = result
      shell.scope[local.name] = local
    }

    return true
  }

  private Str typeSig(Type t)
  {
    // FFI types aren't qualified
    if (t.pod == null)
    {
      // see if we are FFI using as
      a := shell.usings.find |u| { u.matchAs(t) }
      if (a != null) return a.asTo + (t.isNullable ? "?" : "")

      // use unqualified name
      return "${t.name}" + (t.isNullable ? "?" : "")
    }

    // use qualified type
    return t.signature
  }

  private Void compile(Str source)
  {
    /*
    echo("================================")
    echo(source)
    echo("================================")
    */

    // setup compiler input
    ci := CompilerInput
    {
      podName     = shell == null ? "shWarmup" : "sh${shell.evalCount++}"
      summary     = "eval"
      isScript    = true
      version     = Version.defVal
      log.level   = LogLevel.silent
      output      = CompilerOutputMode.transientPod
      mode        = CompilerInputMode.str
      srcStr      = source
      srcStrLoc   = Loc("fansh")
    }

    // create fresh compiler
    this.compiler = Compiler(ci)

    // try to compile
    try
    {
      this.pod = compiler.compile.transientPod
    }
    catch (CompilerErr e)
    {
      this.pod = null
    }
  }

  private Bool isCtrl(Str line)
  {
    try
    {
      return (line.startsWith("for")    && !line[4].isAlpha) ||
             (line.startsWith("if")     && !line[3].isAlpha) ||
             (line.startsWith("while")  && !line[5].isAlpha) ||
             (line.startsWith("switch") && !line[6].isAlpha) ||
             (line.startsWith("try")    && !line[4].isAlpha)
    }
    catch return false
  }

  private Type? localDefType()
  {
    if (pod == null) return null
    stmt := (LocalDefStmt)compiler.pod.typeDefs["FanshEval"].methodDef("_eval").code.stmts[-2]
    return Type.find(stmt.ctype.signature)
  }

  private Void reportCompilerErrs()
  {
    compiler.errs.each |CompilerErr e|
    {
      out.printLine("ERROR($e.col): $e.msg")
    }
  }

  private Void reportEvalErr(Err e)
  {
    // trace to buffer
    buf := Buf.make
    e.trace(buf.out)
    lines := buf.flip.readAllLines

    // only output until we reach the FanshEval
    br := lines.find |Str line->Bool| { return line.contains("FanshEval") }
    if (br != null) lines = lines[0..lines.index(br)-1]
    lines.each |Str line| { out.printLine(line) }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Shell? shell
  private OutStream? out
  private Compiler? compiler
  private Pod? pod

}