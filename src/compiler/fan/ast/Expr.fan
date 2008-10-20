//
// Copyright (c) 2006, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Jul 06  Brian Frank  Creation
//

**
** Expr
**
abstract class Expr : Node
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(Location location, ExprId id)
    : super(location)
  {
    this.id = id
  }

//////////////////////////////////////////////////////////////////////////
// Expr
//////////////////////////////////////////////////////////////////////////

  **
  ** Return this expression as an Int literal usable in a tableswitch,
  ** or null if this Expr doesn't represent a constant Int.  Expressions
  ** which work as table switch cases: int literals and enum constants
  **
  virtual Int? asTableSwitchCase() { return null }

  **
  ** Get this expression's type as a string for error reporting.
  **
  Str toTypeStr()
  {
    if (id == ExprId.nullLiteral) return "null"
    return ctype.toStr
  }

  **
  ** Return if this expression can be used as the
  ** left hand side of an assignment expression.
  **
  virtual Bool isAssignable()
  {
    return false
  }

  **
  ** Is this a boolean conditional (boolOr/boolAnd)
  **
  virtual Bool isCond()
  {
    return false
  }

  **
  ** Does this expression make up a complete statement.
  ** If you override this to true, then you must make sure
  ** the expr is popped in CodeAsm.
  **
  virtual Bool isStmt()
  {
    return false
  }

  **
  ** Assignments to instance fields require a temporary local variable.
  **
  virtual Bool assignRequiresTempVar()
  {
    return false
  }

  **
  ** Map the list of expressions into their list of types
  **
  static CType[] ctypes(Expr[] exprs)
  {
    return (CType[])exprs.map(CType[,]) |Expr e->Obj| { return e.ctype }
  }

  **
  ** Given a list of Expr instances, find the common base type
  ** they all share.  This method does not take into account
  ** the null literal.  It is used for type inference for lists
  ** and maps.
  **
  static CType commonType(CNamespace ns, Expr[] exprs)
  {
    hasNull := false
    exprs = exprs.exclude |Expr e->Bool|
    {
      if (e.id !== ExprId.nullLiteral) return false
      hasNull = true
      return true
    }
    t := CType.common(ns, ctypes(exprs))
    if (hasNull) t = t.toNullable
    return t
  }

  **
  ** Return this expression as an ExprStmt
  **
  ExprStmt toStmt()
  {
    return ExprStmt.make(this)
  }

  **
  ** Return this expression as serialization text or
  ** throw exception if not serializable.
  **
  virtual Str serialize()
  {
    throw CompilerErr.make("'$id' not serializable", location)
  }

  **
  ** Set this expression to not be left on the stack.
  **
  Expr noLeave()
  {
    // if the expression is prefixed with a synthetic cast by
    // CallResolver, it is unnecessary at the top level and must
    // be stripped
    result := this
    if (result.id === ExprId.coerce)
    {
      coerce := (TypeCheckExpr)result
      if (coerce.synthetic) result = coerce.target
    }
    result.leave = false
    return result
  }

//////////////////////////////////////////////////////////////////////////
// Doc
//////////////////////////////////////////////////////////////////////////

  **
  ** Get this expression as a string suitable for documentation.
  **
  Str toDocStr()
  {
    // not perfect, but better than what we had previously which
    // was nothing; we might want to grab the actual text from the
    // actual source file - but with the current design we've freed
    // the buffer by the time the tokens are passed to the parser
    try
    {
      // remove extra parens with binary ops
      s := toStr
      if (s[0] == '(' && s[-1] == ')') s = s[1..-2]

      if (s.contains("{"))
      {
        // with blocks
        s = s.replace("with.", "")
      }
      else
      {
        // hide implicit assignments
        if (s.contains("=")) s = s[s.index("=")+1..-1].trim
      }

      // remove extra parens with binary ops
      if (s[0] == '(' && s[-1] == ')') s = s[1..-2]

      // hide storage operator
      s = s.replace(".@", ".")

      // hide safe nav construction
      s = s.replace(".?(", "(")

      // use unqualified names
      while (true)
      {
        qcolon := s.index("::")
        if (qcolon == null) break
        i := qcolon-1
        for (; i>=0; --i) if (!s[i].isAlphaNum && s[i] != '_') break
        s = (i < 0) ? s[qcolon+2..-1] : s[0..i] + s[qcolon+2..-1]
      }

      if (s.size > 40) s = "..."
      return s
    }
    catch (Err e)
    {
      e.trace
      return toStr
    }
  }

//////////////////////////////////////////////////////////////////////////
// Tree
//////////////////////////////////////////////////////////////////////////

  Expr walk(Visitor v)
  {
    walkChildren(v)
    return v.visitExpr(this)
  }

  virtual Void walkChildren(Visitor v)
  {
  }

  static Expr? walkExpr(Visitor v, Expr? expr)
  {
    if (expr == null) return null
    return expr.walk(v)
  }

  static Expr[] walkExprs(Visitor v, Expr?[] exprs)
  {
    for (i:=0; i<exprs.size; ++i)
    {
      expr := exprs[i]
      if (expr != null)
      {
        replace := expr.walk(v)
        if (expr !== replace)
          exprs[i] = replace
      }
    }
    return exprs
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  override abstract Str toStr()

  override Void print(AstWriter out)
  {
    out.w(toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  readonly ExprId id      // expression type identifier
  CType ctype             // type expression resolves to
  Bool leave := true { protected set } // leave this expression on the stack
}

**************************************************************************
** LiteralExpr
**************************************************************************

**
** LiteralExpr puts an Bool, Int, Float, Str, Duration, Uri,
** or null constant onto the stack.
**
class LiteralExpr : Expr
{
  static LiteralExpr makeFor(Location loc, CNamespace ns, Obj val)
  {
    switch (val.type)
    {
      case Bool#:
        return val == true ?
          make(loc, ExprId.trueLiteral, ns.boolType, true) :
          make(loc, ExprId.falseLiteral, ns.boolType, false)
      case Str#:
        return make(loc, ExprId.strLiteral, ns.strType, val)
      default:
        throw Err.make("Unsupported literal type $val.type")
    }
  }

  new make(Location location, ExprId id, CType ctype, Obj? val)
    : super(location, id)
  {
    this.ctype = ctype
    this.val   = val
    if (val == null && !ctype.isNullable)
      throw Err("null literal must typed as nullable!")
  }

  new makeNullLiteral(Location location, CNamespace ns)
    : this.make(location, ExprId.nullLiteral, ns.objType.toNullable, null)
  {
  }

  override Int? asTableSwitchCase()
  {
    return val as Int
  }

  override Str serialize()
  {
    switch (id)
    {
      case ExprId.falseLiteral:    return "false"
      case ExprId.trueLiteral:     return "true"
      case ExprId.intLiteral:      return val.toStr
      case ExprId.floatLiteral:    return val.toStr + "f"
      case ExprId.decimalLiteral:  return val.toStr + "d"
      case ExprId.strLiteral:      return val.toStr.toCode
      case ExprId.uriLiteral:      return val.toStr.toCode('`')
      case ExprId.typeLiteral:     return "${val->signature}#"
      case ExprId.durationLiteral: return val.toStr
      default:                     return super.serialize
    }
  }

  override Str toStr()
  {
    switch (id)
    {
      case ExprId.nullLiteral: return "null"
      case ExprId.strLiteral:  return "\"" + val.toStr.replace("\n", "\\n") + "\""
      case ExprId.typeLiteral: return "${val}#"
      case ExprId.uriLiteral:  return "`$val`"
      default: return val.toStr
    }
  }

  Obj? val // Bool, Int, Float, Str (for Str/Uri), Duration, CType, or null
}

**************************************************************************
** LiteralExpr
**************************************************************************

**
** SlotLiteralExpr
**
class SlotLiteralExpr : Expr
{
  new make(Location loc, CType parent, Str name)
    : super(loc, ExprId.slotLiteral)
  {
    this.parent = parent
    this.name = name
  }

  override Str serialize()
  {
    return "$parent.signature#name"
  }

  override Str toStr()
  {
    return "$parent.signature#name"
  }

  CType parent
  Str name
  CSlot slot
}

**************************************************************************
** RangeLiteralExpr
**************************************************************************

**
** RangeLiteralExpr creates a Range instance
**
class RangeLiteralExpr : Expr
{
  new make(Location location, CType ctype)
    : super(location, ExprId.rangeLiteral)
  {
    this.ctype = ctype
  }

  override Void walkChildren(Visitor v)
  {
    start = start.walk(v)
    end   = end.walk(v)
  }

  override Str toStr()
  {
    if (exclusive)
      return "${start}...${end}"
    else
      return "${start}..${end}"
  }

  Expr start
  Expr end
  Bool exclusive
}

**************************************************************************
** ListLiteralExpr
**************************************************************************

**
** ListLiteralExpr creates a List instance
**
class ListLiteralExpr : Expr
{
  new make(Location location, ListType? explicitType := null)
    : super(location, ExprId.listLiteral)
  {
    this.explicitType = explicitType
  }

  new makeFor(Location location, CType ctype, Expr[] vals)
    : super.make(location, ExprId.listLiteral)
  {
    this.ctype = ctype
    this.vals  = vals
  }

  override Void walkChildren(Visitor v)
  {
    vals = walkExprs(v, vals)
  }

  override Str serialize()
  {
    return format |Expr e->Str| { return e.serialize }
  }

  override Str toStr()
  {
    return format |Expr e->Str| { return e.toStr }
  }

  Str format(|Expr e->Str| f)
  {
    s := StrBuf.make
    if (explicitType != null) s.add(explicitType.v)
    s.add("[")
    if (vals.isEmpty) s.add(",")
    else vals.each |Expr v, Int i|
    {
      if (i > 0) s.add(",")
      s.add(f(v))
    }
    s.add("]")
    return s.toStr
  }

  ListType? explicitType
  Expr[] vals := Expr[,]
}

**************************************************************************
** MapLiteralExpr
**************************************************************************

**
** MapLiteralExpr creates a List instance
**
class MapLiteralExpr : Expr
{
  new make(Location location, MapType? explicitType := null)
    : super(location, ExprId.mapLiteral)
  {
    this.explicitType = explicitType
  }

  override Void walkChildren(Visitor v)
  {
    keys = walkExprs(v, keys)
    vals = walkExprs(v, vals)
  }

  override Str serialize()
  {
    return format |Expr e->Str| { return e.serialize }
  }

  override Str toStr()
  {
    return format |Expr e->Str| { return e.toStr }
  }

  Str format(|Expr e->Str| f)
  {
    s := StrBuf.make
    if (explicitType != null) s.add(explicitType)
    s.add("[")
    if (vals.isEmpty) s.add(":")
    else
    {
      keys.size.times |Int i|
      {
        if (i > 0) s.add(",")
        s.add(f(keys[i])).add(":").add(f(vals[i]))
      }
    }
    s.add("]")
    return s.toStr
  }

  MapType? explicitType
  Expr[] keys := Expr[,]
  Expr[] vals := Expr[,]
}

**************************************************************************
** UnaryExpr
**************************************************************************

**
** UnaryExpr is used for unary expressions including !, +.
** Note that - is mapped to negate() as a shortcut method.
**
class UnaryExpr : Expr
{
  new make(Location location, ExprId id, Token opToken, Expr operand)
    : super(location, id)
  {
    this.opToken = opToken
    this.operand = operand
  }

  override Void walkChildren(Visitor v)
  {
    operand = operand.walk(v)
  }

  override Str toStr()
  {
    if (id == ExprId.cmpNull)
      return operand.toStr + " == null"
    else if (id == ExprId.cmpNotNull)
      return operand.toStr + " != null"
    else
      return opToken.toStr + operand.toStr
  }

  Token opToken   // operator token type (Token.bang, etc)
  Expr operand    // operand expression

}

**************************************************************************
** BinaryExpr
**************************************************************************

**
** BinaryExpr is used for binary expressions with a left hand side and a
** right hand side including assignment.  Note that many common binary
** operations are actually modeled as ShortcutExpr to enable method based
** operator overloading.
**
class BinaryExpr : Expr
{
  new make(Expr lhs, Token opToken, Expr rhs)
    : super(lhs.location, opToken.toExprId)
  {
    this.lhs = lhs
    this.opToken = opToken
    this.rhs = rhs
  }

  new makeAssign(Expr lhs, Expr rhs, Bool leave := false)
    : this.make(lhs, Token.assign, rhs)
  {
    this.ctype = lhs.ctype
    this.leave = leave
  }

  override Bool isStmt() { return id === ExprId.assign }

  override Void walkChildren(Visitor v)
  {
    lhs = lhs.walk(v)
    rhs = rhs.walk(v)
  }

  override Str serialize()
  {
    if (id === ExprId.assign)
      return "${lhs.serialize}=${rhs.serialize}"
    else
      return super.serialize
  }

  override Str toStr()
  {
    return "($lhs $opToken $rhs)"
  }

  Token opToken      // operator token type (Token.and, etc)
  Expr lhs           // left hand side
  Expr rhs           // right hand side
  MethodVar tempVar  // temp local var to store field assignment leaves

}

**************************************************************************
** CondExpr
**************************************************************************

**
** CondExpr is used for || and && short-circuit boolean conditionals.
**
class CondExpr : Expr
{
  new make(Expr first, Token opToken)
    : super(first.location, opToken.toExprId)
  {
    this.opToken = opToken
    this.operands = [first]
  }

  override Bool isCond() { return true }

  override Void walkChildren(Visitor v)
  {
    operands = walkExprs(v, operands)
  }

  override Str toStr()
  {
    return operands.join(" $opToken ")
  }

  Token opToken      // operator token type (Token.and, etc)
  Expr[] operands    // list of operands

}

**************************************************************************
** NameExpr
**************************************************************************

**
** NameExpr is the base class for an identifier expression which has
** an optional base expression.  NameExpr is the base class for
** UnknownVarExpr and CallExpr which are resolved via CallResolver
**
abstract class NameExpr : Expr
{
  new make(Location location, ExprId id, Expr? target, Str? name)
    : super(location, id)
  {
    this.target = target
    this.name   = name
    this.isSafe = false
  }

  override Void walkChildren(Visitor v)
  {
    target = walkExpr(v, target)
  }

  override Str toStr()
  {
    if (target != null)
      return target.toStr + (isSafe ? "?." : ".") + name
    else
      return name
  }

  Expr? target  // base target expression or null
  Str? name     // name of variable (local/field/method)
  Bool isSafe   // if ?. operator
}

**************************************************************************
** UnknownVarExpr
**************************************************************************

**
** UnknownVarExpr is a place holder in the AST for a variable until
** we can figure out what it references: local or slot.  We also use
** this class for storage operators before they are resolved to a field.
**
class UnknownVarExpr : NameExpr
{
  new make(Location location, Expr? target, Str name)
    : super(location, ExprId.unknownVar, target, name)
  {
  }

  new makeStorage(Location location, Expr? target, Str name)
    : super.make(location, ExprId.storage, target, name)
  {
  }

}

**************************************************************************
** CallExpr
**************************************************************************

**
** CallExpr is a method call.
**
class CallExpr : NameExpr
{
  new make(Location location, Expr? target := null, Str? name := null, ExprId id := ExprId.call)
    : super(location, id, target, name)
  {
    args = Expr[,]
    isDynamic = false
    isSafe = false
    isCtorChain = false
  }

  new makeWithMethod(Location location, Expr? target, CMethod method, Expr[]? args := null)
    : this.make(location, target, method.name, ExprId.call)
  {
    this.method = method

    if (args != null)
      this.args = args

    if (method.isCtor)
      ctype = method.parent
    else
      ctype = method.returnType
  }

  override Str toStr()
  {
    return toCallStr(true)
  }

  override Bool isStmt() { return true }

  virtual Bool isCompare() { return false }

  override Void walkChildren(Visitor v)
  {
    target = walkExpr(v, target)
    args = walkExprs(v, args)
  }

  override Str serialize()
  {
    // only serialize a true Type("xx") expr which maps to Type.fromStr
    if (id != ExprId.construction || method.name != "fromStr")
      return super.serialize

    argSer := args.join(",") |Expr e->Str| { return e.serialize }
    return "$target($argSer)"
  }

  override Void print(AstWriter out)
  {
    out.w(toCallStr(false))
    if (args.size > 0 && args.last is ClosureExpr)
      args.last.print(out)
  }

  private Str toCallStr(Bool isToStr)
  {
    s := StrBuf.make

    if (target != null)
    {
      s.add(target).add(isSafe ? "?" : "").add(isDynamic ? "->" : ".")
    }
    else if (method != null && (method.isStatic || method.isCtor))
      s.add(method.parent.qname).add(".")

    s.add(name).add("(")
    if (args.last is ClosureExpr)
    {
      s.add(args[0..-2].join(", ")).add(") ");
      if (isToStr) s.add(args.last)
    }
    else
    {
      s.add(args.join(", ")).add(")")
    }
    return s.toStr
  }

  Expr[] args         // Expr[] arguments to pass
  Bool isDynamic      // true if this is a -> dynamic call
  Bool isCtorChain    // true if this is MethodDef.ctorChain call
  CMethod? method     // resolved method
}

**************************************************************************
** ShortcutExpr
**************************************************************************

**
** ShortcutExpr is used for operator expressions which are a shortcut
** to a method call:
**   a + b    => a.plus(b)
**   a - b    => a.minus(b)
**   a * b    => a.mult(b)
**   a / b    => a.div(b)
**   a % b    => a.mod(b)
**   a[b]     => a.get(b)
**   a[b] = c => a.set(b, c)
**   a[b]     => a.slice(b) if b is Range
**   a[b] = c => a.splice(b, c) if b is Range
**   a << b   => a.lshift(b)
**   a >> b   => a.rshift(b)
**   a & b    => a.and(b)
**   a | b    => a.or(b)
**   a ^ b    => a.xor(b)
**   ~a       => a.inverse()
**   -a       => a.negate()
**   ++a, a++ => a.increment()
**   --a, a-- => a.decrement()
**   a == b   => a.equals(b)
**   a != b   => ! a.equals(b)
**   a <=>    => a.compare(b)
**   a > b    => a.compare(b) > 0
**   a >= b   => a.compare(b) >= 0
**   a < b    => a.compare(b) < 0
**   a <= b   => a.compare(b) <= 0
**
class ShortcutExpr : CallExpr
{
  new makeUnary(Location loc, Token opToken, Expr operand)
    : super.make(loc, null, null, ExprId.shortcut)
  {
    this.op      = opToken.toShortcutOp(1)
    this.opToken = opToken
    this.name    = op.methodName
    this.target  = operand
  }

  new makeBinary(Expr lhs, Token opToken, Expr rhs)
    : super.make(lhs.location, null, null, ExprId.shortcut)
  {
    this.op      = opToken.toShortcutOp(2)
    this.opToken = opToken
    this.name    = op.methodName
    this.target  = lhs
    this.args.add(rhs)
  }

  new makeGet(Location loc, Expr target, Expr index)
    : super.make(loc, null, null, ExprId.shortcut)
  {
    this.op      = ShortcutOp.get
    this.opToken = Token.lbracket
    this.name    = op.methodName
    this.target  = target
    this.args.add(index)
  }

  new makeFrom(ShortcutExpr from)
    : super.make(from.location, null, null, ExprId.shortcut)
  {
    this.op      = from.op
    this.opToken = from.opToken
    this.name    = from.name
    this.target  = from.target
    this.args    = from.args
    this.isPostfixLeave = from.isPostfixLeave
  }

  override Bool assignRequiresTempVar()
  {
    return isAssignable
  }

  override Bool isAssignable()
  {
    return op === ShortcutOp.get
  }

  override Bool isCompare()
  {
    return op === ShortcutOp.eq || op === ShortcutOp.cmp
  }

  override Bool isStmt() { return isAssign || op === ShortcutOp.set }

  Bool isAssign() { return opToken.isAssign }

  Bool isStrConcat()
  {
    return opToken == Token.plus && (target.ctype.isStr || args.first.ctype.isStr)
  }

  override Str toStr()
  {
    if (op == ShortcutOp.get) return "${target}[$args.first]"
    if (op == ShortcutOp.increment) return isPostfixLeave ? "${target}++" : "++${target}"
    if (op == ShortcutOp.decrement) return isPostfixLeave ? "${target}--" : "--${target}"
    if (isAssign) return "${target} ${opToken} ${args.first}"
    if (op.degree == 1) return "${opToken}${target}"
    if (op.degree == 2) return "(${target} ${opToken} ${args.first})"
    return super.toStr
  }

  override Void print(AstWriter out)
  {
    out.w(toStr())
  }

  ShortcutOp op
  Token opToken
  Bool isPostfixLeave := false  // x++ or x-- (must have Expr.leave set too)
  MethodVar tempVar    // temp local var to store += to field/indexed
}

**
** IndexedAssignExpr is a subclass of ShortcutExpr used
** in situations like x[y] += z where we need keep of two
** extra scratch variables and the get's matching set method.
** Note this class models the top x[y] += z, NOT the get target
** which is x[y].
**
** In this example, IndexedAssignExpr shortcuts Int.plus and
** its target shortcuts List.get:
**   x := [2]
**   x[0] += 3
**
class IndexedAssignExpr : ShortcutExpr
{
  new makeFrom(ShortcutExpr from)
    : super.makeFrom(from)
  {
  }

  MethodVar scratchA
  MethodVar scratchB
  CMethod setMethod
}

**************************************************************************
** FieldExpr
**************************************************************************

**
** FieldExpr is used for a field variable access.
**
class FieldExpr : NameExpr
{
  new make(Location location, Expr? target := null, CField? field := null, Bool useAccessor := true)
    : super(location, ExprId.field, target, null)
  {
    this.useAccessor = useAccessor
    this.isSafe = false
    if (field != null)
    {
      this.name  = field.name
      this.field = field
      this.ctype = field.fieldType
    }
  }

  override Bool isAssignable() { return true }

  override Bool assignRequiresTempVar() { return !field.isStatic }

  override Int? asTableSwitchCase()
  {
    // TODO - this should probably be tightened up if we switch to const
    if (field.isStatic && field.parent.isEnum && ctype.isEnum)
    {
      switch (field.type)
      {
        case ReflectField#:
          ifield := field as ReflectField
          return ((Enum)ifield.f.get).ordinal
        case FieldDef#:
          fieldDef := field as FieldDef
          enumDef := fieldDef.parentDef.enumDef(field.name)
          if (enumDef != null) return enumDef.ordinal
        default:
          throw CompilerErr.make("Invalid field for tableswitch: " + field.type, location)
      }
    }
    return null
  }

  override Str serialize()
  {
    if (target != null && target.id === ExprId.withBase)
      return "$name"

    if (field.isStatic)
    {
      if (field.parent.isFloat)
      {
        switch (name)
        {
          case "nan":    return "sys::Float(\"NaN\")"
          case "posInf": return "sys::Float(\"INF\")"
          case "negInf": return "sys::Float(\"-INF\")"
        }
      }

      if (field.isEnum)
        return "${field.parent.qname}(\"$name\")"
    }

    return super.serialize
  }

  override Str toStr()
  {
    s := StrBuf.make
    if (target != null) s.add(target).add(".");
    if (!useAccessor) s.add("@")
    s.add(name)
    return s.toStr
  }

  CField field        // resolved field
  Bool useAccessor    // false if access using '@' storage operator
}

**************************************************************************
** LocalVarExpr
**************************************************************************

**
** LocalVarExpr is used to access a local variable stored in a register.
**
class LocalVarExpr : Expr
{
  new make(Location location, MethodVar? var, ExprId id := ExprId.localVar)
    : super(location, id)
  {
    if (var != null)
    {
      this.var = var
      this.ctype = var.ctype
    }
  }

  override Bool isAssignable() { return true }

  override Bool assignRequiresTempVar() { return var.usedInClosure }

  virtual Int register() { return var.register }

  override Str toStr()
  {
    if (var == null) return "???"
    return var.name
  }

  MethodVar? var   // bound variable

  // used to mark a local var access that should not be
  // pulled out into cvars, even if var.usedInClosure is true
  Bool noRemapToCvars := false
}

**************************************************************************
** ThisExpr
**************************************************************************

**
** ThisExpr models the "this" keyword to access the implicit this
** local variable always stored in register zero.
**
class ThisExpr : LocalVarExpr
{
  new make(Location location, CType? ctype := null)
    : super(location, null, ExprId.thisExpr)
  {
    this.ctype = ctype
  }

  override Bool isAssignable() { return false }

  override Int register() { return 0 }

  override Str toStr()
  {
    return "this"
  }
}

**************************************************************************
** SuperExpr
**************************************************************************

**
** SuperExpr is used to access super class slots.  It always references
** the implicit this local variable stored in register zero, but the
** super class's slot definitions.
**
class SuperExpr : LocalVarExpr
{
  new make(Location location, CType? explicitType := null)
    : super(location, null, ExprId.superExpr)
  {
    this.explicitType = explicitType
  }

  override Bool isAssignable() { return false }

  override Int register() { return 0 }

  override Str toStr()
  {
    if (explicitType != null)
      return "${explicitType}.super"
    else
      return "super"
  }

  CType? explicitType   // if "named super"
}

**************************************************************************
** StaticTargetExpr
**************************************************************************

**
** StaticTargetExpr wraps a type reference as an Expr for use as
** a target in a static field access or method call
**
class StaticTargetExpr : Expr
{
  new make(Location location, CType ctype)
    : super(location, ExprId.staticTarget)
  {
    this.ctype = ctype
  }

  override Str toStr()
  {
    return ctype.signature
  }
}

**************************************************************************
** TypeCheckExpr
**************************************************************************

**
** TypeCheckExpr is an expression which is composed of an arbitrary
** expression and a type - is, as, coerce
**
class TypeCheckExpr : Expr
{
  new make(Location location, ExprId id, Expr target, CType check)
    : super(location, id)
  {
    this.target = target
    this.check  = check
    this.ctype  = check
  }

  new coerce(Expr target, CType to)
    : super.make(target.location, ExprId.coerce)
  {
    if (to.isGenericParameter) to = to.ns.objType // TODO: not sure about this
    this.target = target
    this.check  = to
    this.ctype  = to
  }

  override Void walkChildren(Visitor v)
  {
    target = walkExpr(v, target)
  }

  override Bool isStmt()
  {
    return id === ExprId.coerce && target.isStmt
  }

  override Str serialize()
  {
    if (id == ExprId.coerce)
      return target.serialize
    else
      return super.serialize
  }

  Str opStr()
  {
    switch (id)
    {
      case ExprId.isExpr:    return "is"
      case ExprId.isnotExpr: return "isnot"
      case ExprId.asExpr:    return "as"
      default:               throw Err.make(id.toStr)
    }
  }

  override Str toStr()
  {
    switch (id)
    {
      case ExprId.isExpr:    return "($target is $check)"
      case ExprId.isnotExpr: return "($target isnot $check)"
      case ExprId.asExpr:    return "($target as $check)"
      case ExprId.coerce:    return "(($check)$target)"
      default:               throw Err.make(id.toStr)
    }
  }

  Expr target
  CType check
  Bool synthetic := false
}

**************************************************************************
** TernaryExpr
**************************************************************************

**
** TernaryExpr is used for the ternary expression <cond> ? <true> : <false>
**
class TernaryExpr : Expr
{
  new make(Expr condition, Expr trueExpr, Expr falseExpr)
    : super(condition.location, ExprId.ternary)
  {
    this.condition = condition
    this.trueExpr  = trueExpr
    this.falseExpr = falseExpr
  }

  override Void walkChildren(Visitor v)
  {
    condition = condition.walk(v)
    trueExpr  = trueExpr.walk(v)
    falseExpr = falseExpr.walk(v)
  }

  override Str toStr()
  {
    return "$condition ? $trueExpr : $falseExpr"
  }

  Expr condition     // boolean test
  Expr trueExpr      // result of expression if condition is true
  Expr falseExpr     // result of expression if condition is false
}

**************************************************************************
** WithBlockExpr
**************************************************************************

**
** WithBlockExpr is used enclose a series of sub-expressions
** against a base expression:
**   base { a = b; c() }
** Translates to:
**   temp := base
**   temp.a = b
**   temp.c()
**
class WithBlockExpr : Expr
{
  new make(Expr base)
    : super(base.location, ExprId.withBlock)
  {
    this.base = base
    this.subs = WithSubExpr[,]
  }

  override Void walkChildren(Visitor v)
  {
    base  = base.walk(v)
    ctype = base.ctype
    subs  = (WithSubExpr[])walkExprs(v, subs)
  }

  override Bool isStmt() { return true }

  Bool isCtorWithBlock()
  {
    return (base.id == ExprId.call || base.id == ExprId.construction) && base->method->isCtor
  }

  override Str serialize()
  {
    if (base.id != ExprId.call || base->method->isCtor != true ||
        base->name != "make" || base->args->size != 0)
      return super.serialize

    s := StrBuf.make
    s.add("${base->target}{")
    subs.each |Expr sub| { s.add("$sub.serialize;") }
    s.add("}")
    return s.toStr
  }

  override Str toStr()
  {
    s := StrBuf.make
    s.add("$base { ")
    subs.each |Expr sub| { s.add("$sub; ") }
    s.add("}")
    return s.toStr
  }

  Expr base           // base expression
  WithSubExpr[] subs  // sub-expressions applied to base
}

**
** WithSubExpr wraps each sub-expr within a with-block.
**
class WithSubExpr : Expr
{
  new make(WithBlockExpr withBlock, Expr expr)
    : super(expr.location, ExprId.withSub)
  {
    this.withBlock = withBlock
    this.expr = expr
  }

  override Void walkChildren(Visitor v)
  {
    expr = expr.walk(v)
  }

  override Bool isStmt() { return expr.isStmt }
  override Str serialize() { return expr.serialize }
  override Str toStr() { return expr.toStr }

  WithBlockExpr withBlock
  Expr expr
  CMethod? add   // if 'with.add(expr)'
}

**
** WithBaseExpr is a place holder used as the target of
** sub-expressions within a with block typed to the with base.
**
class WithBaseExpr : Expr
{
  new make(WithBlockExpr withBlock, WithSubExpr? withSub := null)
    : super(withBlock.location, ExprId.withBase)
  {
    this.ctype = withBlock.ctype
    this.withBlock = withBlock
    this.withSub = withSub
  }

  Bool isCtorWithBlock()
  {
    return withBlock.isCtorWithBlock
  }

  override Str toStr()
  {
    return "with"
  }

  override Void walkChildren(Visitor v)
  {
    // this node never has children, but whenever the
    // tree is walked update its ctype from the withBlock
    ctype = withBlock.ctype
  }

  WithBlockExpr withBlock
  WithSubExpr withSub
}

**************************************************************************
** CurryExpr
**************************************************************************

**
** CurryExpr is used to "curry" a function into another
** function thru partially evaluation
**
class CurryExpr : Expr
{
  new make(Location location, Expr operand)
    : super(location, ExprId.curry)
  {
    this.operand = operand
  }

  override Void walkChildren(Visitor v)
  {
    operand = operand.walk(v)
  }

  override Str toStr()
  {
    return "&$operand"
  }

  Expr operand
}

**************************************************************************
** ClosureExpr
**************************************************************************

**
** ClosureExpr is an "inlined anonymous method" which closes over it's
** lexical scope.  ClosureExpr is placed into the AST by the parser
** with the code field containing the method implementation.  In
** InitClosures we remap a ClosureExpr to an anonymous class TypeDef
** which extends Func.  The function implementation is moved to the
** anonymous class's doCall() method.  However we leave ClosureExpr
** in the AST in it's original location with a substitute expression.
** The substitute expr just creates an instance of the anonymous class.
** But by leaving the ClosureExpr in the tree, we can keep track of
** the original lexical scope of the closure.
**
class ClosureExpr : Expr
{
  new make(Location location, TypeDef enclosingType,
           MethodDef enclosingMethod, ClosureExpr enclosingClosure,
           FuncType signature, Str name)
    : super(location, ExprId.closure)
  {
    this.ctype            = signature
    this.enclosingType    = enclosingType
    this.enclosingMethod  = enclosingMethod
    this.enclosingClosure = enclosingClosure
    this.signature        = signature
    this.name             = name
    this.code             = code
    this.usesCvars        = false
  }

  once CField outerThisField()
  {
    if (enclosingMethod.isStatic) throw Err.make("Internal error: $location.toLocationStr")
    return ClosureVars.makeOuterThisField(this)
  }

  override Str toStr()
  {
    return "$signature { ... }"
  }

  override Void print(AstWriter out)
  {
    out.w(signature.toStr)
    if (substitute != null)
    {
      out.w(" { substitute: ")
      substitute.print(out)
      out.w(" }").nl
    }
    else
    {
      out.nl
      code.print(out)
    }
  }

  // Parse
  TypeDef enclosingType         // enclosing class
  MethodDef enclosingMethod     // enclosing method
  ClosureExpr? enclosingClosure // if nested closure
  FuncType signature            // parameter and return signature
  Block? code                   // moved into a MethodDef in InitClosures
  Str name                      // anonymous class name

  // InitClosures
  CallExpr? substitute          // expression to substitute during assembly
  TypeDef? cls                  // anonymous class which implements the closure
  MethodDef? doCall             // anonymous class's doCall() with code

  // ResolveExpr
  [Str:MethodVar]? enclosingLocals // locals in scope
  Bool usesCvars                // does this guy use vars from outer scope
}

**************************************************************************
** ExprId
**************************************************************************

**
** ExprId uniquely identifies the type of expr
**
enum ExprId
{
  nullLiteral,      // LiteralExpr
  trueLiteral,
  falseLiteral,
  intLiteral,
  floatLiteral,
  decimalLiteral,
  strLiteral,
  durationLiteral,
  uriLiteral,
  typeLiteral,
  slotLiteral,      // SlotLiteralExpr
  rangeLiteral,     // RangeLiteralExpr
  listLiteral,      // ListLiteralExpr
  mapLiteral,       // MapLiteralExpr
  boolNot,          // UnaryExpr
  cmpNull,
  cmpNotNull,
  elvis,
  assign,           // BinaryExpr
  same,
  notSame,
  boolOr,           // CondExpr
  boolAnd,
  isExpr,           // TypeCheckExpr
  isnotExpr,
  asExpr,
  coerce,
  call,             // CallExpr
  construction,
  shortcut,         // ShortcutExpr (has ShortcutOp)
  field,            // FieldExpr
  localVar,         // LocalVarExpr
  thisExpr,         // ThisExpr
  superExpr,        // SuperExpr
  staticTarget,     // StaticTargetExpr
  unknownVar,       // UnknownVarExpr
  storage,
  ternary,          // TernaryExpr
  withBlock,        // WithBlockExpr
  withSub,          // WithSubExpr
  withBase,         // WithBaseExpr
  curry,            // CurryExpr
  closure           // ClosureExpr
}

**************************************************************************
** ShortcutId
**************************************************************************

**
** ShortcutOp is a sub-id for ExprId.shortcut which identifies the
** an shortuct operation and it's method call
**
enum ShortcutOp
{
  plus(2),
  minus(2),
  mult(2),
  div(2),
  mod(2),
  lshift(2),
  rshift(2),
  and(2),
  or(2),
  xor(2),
  inverse(1),
  negate(1),
  increment(1),
  decrement(1),
  eq(2, "equals"),
  cmp(2, "compare"),
  get(2),
  set(2),
  slice(2)

  private new make(Int degree, Str? methodName := null)
  {
    this.degree = degree
    this.methodName = methodName == null ? name : methodName
  }

  const Int degree
  const Str methodName
}