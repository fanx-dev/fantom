#! /usr/bin/env fan
//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Feb 07  Brian Frank  Creation
//

using build

**
** Build: inet
**
class Build : BuildPod
{
  new make()
  {
    podName    = "inet"
    summary    = "IP networking"
    meta       = ["org.name":     "Fantom",
                  "org.uri":      "https://fantom.org/",
                  "proj.name":    "Fantom Core",
                  "proj.uri":     "https://fantom.org/",
                  "license.name": "Academic Free License 3.0",
                  "vcs.name":     "Mercurial",
                  "vcs.uri":      "https://bitbucket.org/fantom/fan-1.0/"]
    depends    = ["sys 2.0", "std 1.0", "concurrent 1.0"]
    srcDirs    = [`fan/`, `test/`]
    javaDirs   = [`java/`]
    dotnetDirs = [`dotnet/`]
    docSrc     = true
  }
}


