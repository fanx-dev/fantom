#! /usr/bin/env fan
//
// Copyright (c) 2008, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jan 08  Brian Frank  Creation
//

using build

**
** Build: fansh
**
class Build : BuildPod
{
  new make()
  {
    podName = "fansh"
    summary = "Interactive Fantom Shell"
    meta    = ["org.name":     "Fantom",
               "org.uri":      "https://fantom.org/",
               "proj.name":    "Fantom Core",
               "proj.uri":     "https://fantom.org/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/fantom-lang/fantom"]
    depends = ["sys 1.0", "compiler 1.0", "concurrent 1.0"]
    srcDirs = [`fan/`]
    docSrc  = true
  }
}