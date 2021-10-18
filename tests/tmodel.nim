import ../src/model
import unittest
import std / with

suite "Database/Models":
  let dbConn = createDatabase()
  suite "Votes":
    test "Votes should not be added if identical copies exist":
      
