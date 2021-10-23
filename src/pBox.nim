import norm/[sqlite]
import models
import database
import jester
import std/json

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

type PostOutput = object
  id: int64
  content: string
  title: string
  score: int64
  tags: seq[Tag]
  category: Category

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
