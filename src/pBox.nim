import norm/[sqlite]
import models
import database
import jester
import std/json
import auth
import macros
import options
from strutils import strip, parseInt

from sugar import collect

let dbConn = createDatabase()

try:
  let
    category = dbConn.create(newCategory("owo"))
    myTag = dbConn.create(newTag("my tag"))
    myOtherTag = dbConn.create(newTag("my other tag"))
  discard dbConn.createPost("hello", "owo", category.id, @[myTag.id])
  discard dbConn.createPost("my post", "uwu", category.id, @[])
  discard dbConn.createPost("my lost", ">w<", category.id,
    @[myTag.id, myOtherTag.id])
  discard dbConn.createPost("my sauce", "ewe", category.id, @[myOtherTag.id])
except DbError:
  discard
except DuplicateError:
  echo getCurrentExceptionMsg()

type
  Output = object of RootObj
    id: int64
  PostOutput = object of Output
    content: string
    title: string
    score: int64
    tags: seq[Tag]
    category: Category
  UserOutput = object of Output
    name: string
    super: bool

type AuthError = ValueError

proc authenticate(request: Request): User =
  if not request.headers.hasKey("Authorization"):
    raise AuthError.newException("The authorization field does not exist.")
  let token = request.headers["Authorization"].strip()

  try:
    result = dbConn.getUserByAuthKey(token)
  except NotFoundError:
    raise AuthError.newException("This does not exist and is invalid.")

proc postToPostOutput(post: Post): PostOutput =
  var category = newCategory()
  dbConn.select category, "Category.id = ?", post.categoryID
  var relationships = @[newTagPostRelationship()]
  dbConn.select relationships, "TagPostRelationship.postID = ?", post.id
  var tags = collect(newSeq):
    for j in relationships:
      var tag = newTag()
      dbConn.select tag, "Tag.id = ?", j.tagID
      tag
  PostOutput(
    id: post.id,
    content: post.content,
    title: post.title,
    score: post.score,
    tags: tags,
    category: category
  )

routes:
  post "/register/":
    ## Registers a new user in the database and returns the newly
    ## created User object. For now, it assumes that you are using only the
    ## PassAuth authentication method so therefore you must pass a
    ## "username" and a "password" in JSON
    var credentialsJSON = parseJson(request.body)

    cond "username" in credentialsJSON
    cond "password" in credentialsJSON

    let user = dbConn.registerNewUser(
      credentialsJSON["username"].to(string),
      credentialsJSON["password"].to(string)
    )

    let output = UserOutput(
      id: user.id,
      name: user.name,
      super: user.super
    )

    resp %*output

  post "/login/":
    ## Registers a new user in the database and returns the newly
    ## created User object. For now, it assumes that you are using only the
    ## PassAuth authentication method so therefore you must pass a
    ## "username" and a "password" in JSON
    var credentialsJSON = parseJson(request.body)

    cond "username" in credentialsJSON
    cond "password" in credentialsJSON

    let password = credentialsJSON["password"].to(string)

    # get the user by username
    try:
      var user = newUser()
      dbConn.select user, "User.name = ?", credentialsJSON["username"].to(string)
      # check if the password is correct
      var passAuth = newPassAuth()
      dbConn.select passAuth, "PassAuth.id = ?", user.authID
      if password == passAuth:
        let session = dbConn.create(newAuthSession(user.id, makeSessionKey()))
        resp session.token
      else:
        resp Http400, "The password is incorrect."
    except NotFoundError:
      resp Http400, "User not found."

  get "/posts/":
    var posts = @[newPost()]
    dbConn.selectAll posts
    let postOutputs = collect(newSeq):
      for i in posts:
        postToPostOutput(i)
    resp %*postOutputs

  post "/posts/":
    try:
      discard request.authenticate()

      var postJSON = parseJson(request.body)
      cond "title" in postJSON
      cond "content" in postJSON
      cond "category" in postJSON
      cond "tags" in postJSON

      try:
        let post = dbConn.createPost(
          postJSON["content"].to(string),
          postJSON["title"].to(string),
          postJSON["category"].to(int64),
          postJSON["tags"].to(seq[int64])
        )

        let output = postToPostOutput(post)

        resp %*output
      except ValueError:
        resp Http400, getCurrentExceptionMsg()
      except DuplicateError:
        resp Http400, getCurrentExceptionMsg()
    except AuthError:
      resp Http401, "You are not authorized to do that."

  post "/posts/@post/vote":
    # check if the user is authorized
    cond @"post" != ""
    let postID = @"post".parseInt()

    try:
      var post = newPost()
      dbConn.select post, "Post.id = ?", postID

      cond request.headers.hasKey("Authorization")
      let token = request.headers["Authorization"].strip()

      try:
        var authSession = newAuthSession()
        dbConn.select authSession, "AuthSession.token = ?", token

        var data = parseJson(request.body)
        cond "score" in data
        let score = data["score"].to(int)

        var user = newUser()
        dbConn.select user, "User.id = ?", authSession.userID

        try:
          dbConn.addVote user, post, score
          resp %*postToPostOutput(post)
        except DuplicateError:
          resp Http400, getCurrentExceptionMsg()
        except ValueError:
          resp Http400, getCurrentExceptionMsg()

      except NotFoundError:
        resp Http401, "You are not authorized to do that."
    except NotFoundError:
      resp Http400, "A post with ID " & $postID & " does not exist"

  delete "/posts/@post/vote":
    try:
      let user = request.authenticate()
      let postID = @"post".parseInt()

      try:
        cond @"post" != ""

        var post = newPost()
        dbConn.select post, "Post.id = ?", postID
        try:
          dbConn.removeVote user, post
          resp %*postToPostOutput(post)
        except DuplicateError:
          resp Http400, getCurrentExceptionMsg()
        except ValueError:
          resp Http400, getCurrentExceptionMsg()

      except NotFoundError:
        resp Http400, "A post with ID " & $postID & " does not exist"
    except NotFoundError:
      resp Http401, "You are not authorized to do that."


  get "/sessions/":
    var sessions = @[newAuthSession()]
    dbConn.selectAll sessions
    resp %*sessions
