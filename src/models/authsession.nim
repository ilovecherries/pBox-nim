import norm/model
from ../auth import makeSessionKey
import user

type
  AuthSession* = ref object of Model
    user*: UserModel
    token*: string


func newAuthSession*(
  user = newUser(),
  token = ""
): AuthSession =
  AuthSession(
    user: user,
    token: token
  )

proc generateAuthSession*(user: UserModel): AuthSession =
  newAuthSession(user, makeSessionKey())
