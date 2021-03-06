#! /usr/bin/env fan
//
// Copyright (c) 2011, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Aug 11  Brian Frank  Creation
//

using build

**
** Build: syntax
**
class Build : BuildPod
{
  new make()
  {
    podName    = "syntax"
    summary    = "Syntax styling for programming languages"
    meta       = ["org.name":     "Fantom",
                  "org.uri":      "https://fantom.org/",
                  "proj.name":    "Fantom Core",
                  "proj.uri":     "https://fantom.org/",
                  "license.name": "Academic Free License 3.0",
                  "vcs.name":     "Mercurial",
                  "vcs.uri":      "https://bitbucket.org/fantom/fan-1.0/"]
    depends    = ["sys 2.0", "std 1.0"]
    srcDirs    = [`fan/`, `test/`]
    docSrc     = true
  }
}