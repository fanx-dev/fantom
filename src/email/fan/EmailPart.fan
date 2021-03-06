//
// Copyright (c) 2008, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 May 08  Brian Frank  Creation
//

**
** EmailPart is the base class for parts within a multipart MIME document.
**
** See [pod doc]`pod-doc` and [examples]`examples::email-sending`.
**
@Serializable
abstract class EmailPart
{

  **
  ** Map of headers.  The header map is case insensitive.
  **
  Str:Str headers := CaseInsensitiveMap<Str,Str>()// { caseInsensitive = true }

  **
  ** Validate this part - throw Err if not configured correctly.
  **
  virtual Void validate()
  {
  }

  **
  ** Encode as a MIME message according to RFC 822.  The base
  ** class encodes the headers - subclasses should override
  ** to call super and then encode the part's content.
  **
  virtual Void encode(OutStream out)
  {
    headers.each |val, name| { MimeUtil.encodeHeader(out, name, val) }
    out.print("\r\n")
  }

}