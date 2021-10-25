import norm/[sqlite]
import models
import database
import jester
import std/[json, marshal]
import auth

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

    var auth = newPassAuth()
    dbConn.select auth, "PassAuth.id = ?", user.authID
    # var myUser = newUser()
    # dbConn.select myUser, "User.name = ?", credentialsJSON["username"].to(string)

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
    var user = newUser()
    dbConn.select user, "User.name = ?", credentialsJSON["username"].to(string)
    # check if the password is correct
    var passAuth = newPassAuth()
    dbConn.select passAuth, "PassAuth.id = ?", user.authID
    if password == passAuth:
      let session = dbConn.create(newAuthSession(user.id, makeSessionKey()))
      resp session.token
    else:
      resp "NAY"

  get "/posts/":
    type PostOutput = object
      id: int64
      content: string
      title: string
      score: int64
      tags: seq[Tag]
      category: Category
    var posts = @[newPost()]
    dbConn.selectAll posts
    let postOutputs = collect(newSeq):
      for i in posts:
        postToPostOutput(i)
    resp %*postOutputs
