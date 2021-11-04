import norm/[model, sqlite]
import jester, asyncdispatch
import std/[json, tables]
import auth
import macros
import options
import models/[post, category, user, vote, authsession]
import dbhelper
from strutils import strip, parseInt, join, split, parseFloat
import strformat

import
  logging

var consoleLog = newConsoleLogger()
addHandler(consoleLog)

from sugar import collect, dup

const port = 3001

proc createDatabase*(filename = ":memory"): DbConn =
  result = open(filename, "", "", "")
  result.createTables(newUser())
  result.createTables(newCategory())
  result.createTables(newTagPostRelationship())
  result.createTables(newTag())
  result.createTables(newPost())
  result.createTables(newVote())
  result.createTables(newPassAuth())
  result.createTables(newAuthSession())

let dbConn = createDatabase()

proc isNumeric(s: string): bool =
  try:
    discard s.parseFloat()
    result = true
  except ValueError:
    result = false

try:
  let
    category = dbConn.create(newCategory("owo"))
    myTag = dbConn.create(newTag("my tag"))
    myOtherTag = dbConn.create(newTag("my other tag"))
  discard dbConn.createPost("hello", "owo", category, @[myTag])
  discard dbConn.createPost("my post", "uwu", category, @[])
  discard dbConn.createPost("my lost", ">w<", category,
    @[myTag, myOtherTag])
  discard dbConn.createPost("my sauce", "ewe", category, @[myOtherTag])
except DbError:
  echo getCurrentExceptionMsg()
  discard

type AuthError = ValueError

proc authenticate(request: Request): UserModel =
  if not request.headers.hasKey("Authorization"):
    raise AuthError.newException("The authorization field does not exist.")
  let token = request.headers["Authorization"].strip()

  try:
    var auth = newAuthSession()
    dbConn.select auth, "AuthSession.token = ?", token
    result = auth.user
  except NotFoundError:
    raise AuthError.newException("This does not exist and is invalid.")

router pBox:
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

    resp %*(user.toSerialized())

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
      dbConn.select user, "UserModel.name = ?", credentialsJSON["username"].to(string)
      var passAuth = newPassAuth()
      dbConn.select passAuth, "PassAuth.id = ?", user.authMethodId
      # check if the password is correct
      if password == passAuth:
        let session = dbConn.create(generateAuthSession(user))
        resp session.token
      else:
        resp Http400, "The password is incorrect."
    except NotFoundError:
      resp Http400, "User not found."

  get "/users/me":
    try:
      let user = request.authenticate()
      resp %*(user.toSerialized())
    except NotFoundError:
      resp Http401, "You must be authorized to get your user information."

  get "/posts":
    # TODO: im going to filter out things by using sets later
    let params = request.params
    if "tags" in params:
      let tags = params["tags"].split(",")
      for i in tags:
        if not i.isNumeric:
          resp Http400, "Tags must be numbers."

      let tagSQL = fmt"""
        SELECT postID
        FROM TagPostRelationship
        WHERE tagID IN ({tags.join(",")})
      """
      let postIDs = collect(newSeq):
        for i in dbConn.getAllRows(sql tagSQL):
          i[0].to(int64)
      var posts = @[newPost()]
      let joinedPostIDs = postIDs.join(",")
      dbConn.select posts, fmt"PostModel.id IN ({joinedPostIDs})"

      let postOutputs = collect(newSeq):
        for i in posts:
          i.toSerialized(dbConn)
      resp %*postOutputs
    else:
      var posts = @[newPost()]
      dbConn.selectAll posts
      let postOutputs = collect(newSeq):
        for i in posts:
          i.toSerialized(dbConn)
      resp %*postOutputs

  post "/posts":
    try:
      discard request.authenticate()

      var postJSON = parseJson(request.body)
      cond "title" in postJSON
      cond "content" in postJSON
      cond "category" in postJSON
      cond "tags" in postJSON

      try:
        let categoryID = postJSON["category"].to(int64)
        var category = newCategory()
        dbConn.select category, "CategoryModel.id = ?", categoryID
        var tagIDs = postJSON["tags"].to(seq[int64])
        var tags = collect(newSeq):
          for i in tagIDs:
            var tag = newTag()
            dbConn.select tag, "TagModel.id = ?", i
            tag
        let post = dbConn.createPost(
          postJSON["title"].to(string),
          postJSON["content"].to(string),
          category,
          tags
        )

        let output = post.toSerialized(dbConn)

        resp %*output
      except ValueError:
        resp Http400, getCurrentExceptionMsg()
      except DbError:
        resp Http400, getCurrentExceptionMsg()
    except AuthError:
      resp Http401, "You are not authorized to do that."

  post "/posts/@post/vote":
    # check if the user is authorized
    cond @"post" != ""
    let postID = @"post".parseInt()

    try:
      var post = newPost()
      dbConn.select post, "PostModel.id = ?", postID

      try:
        let user = request.authenticate()

        var data = parseJson(request.body)
        cond "score" in data
        let score = data["score"].to(int)

        try:
          discard post.addVote(dbConn, user, score)
          resp %*(post.toSerialized(dbConn))
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
        dbConn.select post, "PostModel.id = ?", postID
        try:
          discard post.removeVote(dbConn, user)
          resp %*(post.toSerialized(dbConn))
        except DbError:
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

proc main() =
  let settings = newSettings(port = Port(port))
  var jester = initJester(pBox, settings = settings)
  jester.serve()

when isMainModule:
  main()
