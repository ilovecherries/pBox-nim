import json
import norm/[model, pragmas]
import ../auth

type
  User* = object
    id*: int64
    name*: string
    op*: bool

when not defined(js):
  import ../dbhelper
  import norm/sqlite

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

  proc registerNewUser*(dbConn: DbConn, username: string, password: string;
                      op = false): UserModel
    {.raises: [NotFoundError, ValueError, DbError, Exception].} =
    ## Registers a new user in the database using the PassAuth method
    # Create a user object and add them to the database
    let passAuth = dbConn.create(generatePassAuth(password))
    result = dbConn.create(newUser(username, passAuth, op))

  proc toSerialized*(user: UserModel): User =
    User(
      id: user.id,
      name: user.name,
      op: user.op,
    )
