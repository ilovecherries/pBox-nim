import json
import norm/[model, pragmas]
import ../auth

type
  User* = object
    id*: int64
    username*: string
    op*: bool

when not defined(js):
  import ../dbhelper
  import norm/sqlite

  type
    UserModel* = ref object of Model
      name* {.unique.}: string
      op*: bool
      authMethodID*: int64

  func newUser*(
    name = "",
    authMethodID: int64 = 0,
    op = false
  ): UserModel =
    UserModel(
      name: name,
      authMethodID: authMethodID,
      op: op
    )

  proc registerNewUser*(dbConn: DbConn, username: string, password: string;
                      op = false): UserModel
    {.raises: [NotFoundError, ValueError, DbError, Exception].} =
    ## Registers a new user in the database using the PassAuth method
    # Create a user object and add them to the database
    let passAuth = dbConn.create(generatePassAuth(password))
    result = dbConn.create(newUser(username, passAuth.id, op))

  proc toSerialized*(user: UserModel): User =
    User(
      id: user.id,
      username: user.name,
      op: user.op,
    )
