import json
from ../auth import AuthMethod
import norm/[model, pragmas]

type
  User* = object
    id*: int64
    name*: string
    op*: bool

when not defined(js):
  type
    UserModel* = ref object of Model
      name* {.unique.}: string
      op*: bool
      auth*: AuthMethod

  func newUser*(
    name = "",
    auth = AuthMethod(),
    op = false
  ): UserModel =
    UserModel(
      name: name,
      auth: auth,
      op: op
    )

  proc toSerialized*(user: UserModel): string =
    let serialized = User(
      id: user.id,
      name: user.name,
      op: user.op,
    )
    result = $(%*serialized)
