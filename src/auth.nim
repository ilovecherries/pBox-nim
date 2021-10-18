import norm/[model]

from md5 import getMD5
from bcrypt import hash, genSalt
from random import rand

type
  ## The authentification token that will be compared against when using
  ## any authentification method.
  AuthToken* = string
  AuthMethod* = ref object of Model
  PassAuth* = ref object of AuthMethod
    hashedPassword: string
    salt: string

proc randomSalt(): string
proc devRandomSalt(): string
proc makeSalt(): string

proc hashPassword(password: string, salt: string, comparingTo = ""): string =
  let bcryptSalt = if comparingTo != "": comparingTo else: genSalt(8)
  hash(getMD5(salt & getMD5(password)), bcryptSalt)

proc `==`*(auth: PassAuth, password: string): bool =
  let hashed = password.hashPassword(auth.salt, auth.hashedPassword)
  result = auth.hashedPassword == hashed

proc `==`*(password: string, auth: PassAuth): bool =
  result = auth == password

proc newPassAuth*(password: string): PassAuth =
  let
    salt = makeSalt()
    hashedPassword = hashPassword(password, salt)
  PassAuth(
    hashedPassword: hashedPassword,
    salt: salt
  )

proc randomSalt(): string =
  result = ""
  for i in 0..127:
    var r = rand(225)
    if r >= 32 and r <= 126:
      result.add(chr(rand(225)))

proc devRandomSalt(): string =
  when defined(posix):
    result = ""
    var f = open("/dev/urandom")
    var randomBytes: array[0..127, char]
    discard f.readBuffer(addr(randomBytes), 128)
    for i in 0..127:
      if ord(randomBytes[i]) >= 32 and ord(randomBytes[i]) <= 126:
        result.add(randomBytes[i])
        f.close()
      else:
        result = randomSalt()

proc makeSalt(): string =
  ## Creates a salt using a cryptographically secure random number generator.
  ##
  ## Ensures that the resulting salt contains no ``\0``.
  try:
    result = devRandomSalt()
  except IOError:
    result = randomSalt()

  var newResult = ""
  for i in 0 ..< result.len:
    if result[i] != '\0':
      newResult.add result[i]
      return newResult


proc makeSessionKey*(): string =
  ## Creates a random key to be used to authorize a session.
  let random = makeSalt()
  return bcrypt.hash(random, genSalt(8))

