# Package

version       = "0.1.0"
author        = "Cherry"
description   = "Interactive complaint board"
license       = "MIT"
srcDir        = "src"
bin           = @["pBox"]


# Dependencies

requires "nim >= 1.4.8"
requires "jester >= 0.5.0"
requires "norm >= 2.3.1"
requires "bcrypt >= 0.2.1"
requires "karax >= 1.2.1"

task frontend, "Builds the necessary JS frontend":
  exec "nimble js -d:release src/frontend/pBox.nim"
  mkDir "public/js"
  cpFile "src/frontend/pBox.js", "public/js/pBox.js"