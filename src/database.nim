import std / with
import norm/[sqlite, model]
import auth
from sequtils import foldl
from sugar import collect
import models

type DuplicateError* = object of ValueError
  ## An error that is called when there is already a
  ## duplicate item in the database.

proc create*[T: Model](dbConn: DbConn, model: T): T
  {.raises: [DbError, ValueError].} =
  ## Inserts the model with the properties and returns it with the newly
  ## inserted ID
  var m = model
  dbConn.insert m
  let id = dbConn.count(T)
  m.id = id
  result = m

const
  Upvote* = 1
  Downvote* = -1

proc addTag*(dbConn: DbConn, post: Post, tag: Tag)
  {.raises: [DuplicateError, DbError, ValueError].} =
  ## Creates an association between a post and a tag and adds it to the
  ## database.
  # check if a tag association for the post already exists
  try:
    var tagPostRelationship = newTagPostRelationship()
    dbConn.select(
      tagPostRelationship,
      "TagPostRelationship.postID = ? AND TagPostRelationship.tagID = ?",
      post.id,
      tag.id
    )
    raise DuplicateError.newException(
      "A TagPostRelationship for this post and tag already exist."
    )
  except NotFoundError:
    discard
  # now create a tag-post relationship and add it to the database
  discard dbConn.create(newTagPostRelationship(post.id, tag.id))

proc getTags*(dbConn: DbConn, post: Post): seq[Tag]
  {.raises: [NotFoundError, DbError, ValueError].} =
  ## Gets all of the tags that are attached to a post
  var relationships = @[newTagPostRelationship()]
  dbConn.select relationships, "TagPostRelationship.postID = ?", post.id
  result = collect(newSeq):
    for i in relationships:
      var tag = newTag()
      dbConn.select tag, "Tag.id = ?", i.tagID
      tag

proc delete*(dbConn: DbConn, tag: var Tag) =
  ## A modified version of DbConn.delete for removing all
  ## tag-post relationships associated with the tag.
  # delete all of the TagPostRelationships associated with the tag
  var relationships = @[newTagPostRelationship()]
  dbConn.select relationships, "TagPostRelationship.tagID = ?", tag.id
  for i in relationships:
    var model = i
    dbConn.delete model
  sqlite.delete(dbConn, tag)


proc createPost*(dbConn: DbConn, content: string, title: string,
                 categoryID: int64, tagIDs: seq[int64]): Post
  {.raises: [DuplicateError, NotFoundError, DbError, ValueError].} =
  ## Creates a post with the given properties and adds it to the database,
  ## then returns the created post with the associated ID
  # the category should exist in the database, this will throw an error
  # and exit the function if it cannot find the category
  var category = newCategory()
  dbConn.select category, "Category.id = ?", categoryID
  # we should check if a post with the same title already exists
  try:
    var post = newPost()
    dbConn.select post, "Post.title = ?", title
    raise DuplicateError.newException(
      "A post with the title, \"" & title & "\", already exists."
    )
  except NotFoundError:
    discard
  # now, check if all of the tags listed exist
  # TODO: DbConn.transaction may help optimize this?
  var tags = newSeq[Tag]()
  block:
    for i in tagIDs:
      var tag = newTag()
      try:
        dbConn.select tag, "Tag.id = ?", i
        tags.add(tag)
      except NotFoundError:
        raise ValueError.newException(
          "A tag with the ID " & $i & " does not exist."
        )
  # create the post and add it to the database
  var post = dbConn.create(newPost(content, title, categoryID))
  # now attach all of the tags to the post
  for tag in tags:
    dbConn.addTag(post, tag)
  return post

proc delete*(dbConn: DbConn, post: var Post) =
  ## A modified version of DbConn.delete for removing all
  ## tag-post relationships associated with the post.
  # delete all of the TagPostRelationships associated with the post
  var relationships = @[newTagPostRelationship()]
  dbConn.select relationships, "TagPostRelationship.postID = ?", post.id
  for i in relationships:
    var model = i
    dbConn.delete model
  sqlite.delete(dbConn, post)


proc addVote*(dbConn: DbConn, user: User, post: var Post, score: int)
  {.raises: [NotFoundError, ValueError, DbError, DuplicateError].} =
  ## Adds a vote to a post that's attached to a user.
  # check if the score is valid
  if (score != -1) and (score != 1):
    raise ValueError.newException(
      "This is an invalid score given, must be 1 (upvote) or -1 (downvote)."
    )
  # see if a vote that already matches this exists
  try:
    var vote = newVote()
    dbConn.select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
    # create an exception if this has the same score
    if vote.score == score:
      raise DuplicateError.newException("An identical vote already exists.")
    vote.score = score
    dbConn.update vote
    post.score += score
    dbConn.update post
  except NotFoundError:
    discard dbConn.create(newVote(user.id, post.id, score))
    post.score += score
    dbConn.update post

proc removeVote*(dbConn: DbConn, user: User, post: var Post)
  {.raises: [NotFoundError, DbError, ValueError].} =
  ## Removes a vote issued from the user if it exists. Raises a
  ## NotFoundError if the vote does not exist.
  var vote = newVote()
  dbConn.select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
  post.score -= vote.score
  dbConn.delete vote
  dbConn.update post

proc countScore*(dbConn: DbConn, post: Post): int =
  ## Measures the score in the post by adding all of the votes that have
  ## been created for it.
  var votes = @[newVote()]
  dbConn.select votes, "Vote.postID = ?", post.id
  result = foldl(votes, a + b.score, 0)

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


proc registerNewUser*(dbConn: DbConn, username: string, password: string;
                     super = false): User
  {.raises: [NotFoundError, ValueError, DbError, Exception].} =
  ## Registers a new user in the database using the PassAuth method
  # Create a user object and add them to the database
  let passAuth = dbConn.create(generatePassAuth(password))
  result = dbConn.create(newUser(username, passAuth.id, super))

proc createUserAuthKey*(dbConn: DbConn, user: User): AuthSession =
  let token = makeSessionKey()
  return dbConn.create(newAuthSession(user.id, token))

proc getUserByAuthKey(dbConn: DbConn, token: string): User =
  var session = newAuthSession()
  dbConn.select session, "AuthSession.token = ?", token
  result = newUser()
  dbConn.select result, "User.id = ?", session.userID
