import ../src/auth
import unittest

suite "Authentification":
  suite "Username/Password authentification":
    const testPassword = "MyThePassword"
    let passAuth = newPassAuth(testPassword)
    
    test "Incorrect passwords are invalid":
      check "WRONG" != passAuth

    test "Correct passwords are valid":
      check testPassword == passAuth
  
