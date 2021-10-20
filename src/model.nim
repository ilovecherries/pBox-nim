import auth
import norm/[sqlite, model, pragmas]
import options
import std / with
from sequtils import foldl
from sugar import collect

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

type
  DuplicateError* = object of ValueError
    ## An error that is called when there is already a
    ## duplicate item in the database.
  
  User* = ref object of Model
    ## Someone who interacts with the website.
    name* {.unique.}: string
    ## The username assigned to the user.
    auth*: AuthMethod
    ## The authentification method and details that the user has
    ## in order to sign in.
    super*: bool
    ## Whether the user is privileged on the site in order to moderate
    ## or to configure the website.

  Category* = ref object of Model
    ## A category which posts can fit into
    name* {.unique.}: string
    ## The name of the category
    parentID*: Option[int64]
    ## The parent ID of the category

  TagPostRelationship* = ref object of Model
    ## Creates a relationship between the posts and the tags that
    ## are attached to the post
    postID*: int64
    ## The ID of the post that is attached to the tag
    tagID*: int64
    ## The ID of the tag that is attached to the post
    
  Tag* = ref object of Model
    ## Tags which can be attached to a post
    name* {.unique.}: string
    ## The name of the tag
    color*: string
    ## Hex-code formatted for display on the website
  
  Post* = ref object of Model
    ## A Post on the website
    content*: string
    ## The content of the post
    title* {.unique.}: string
    ## The title of the post
    categoryID*: int64
    ## The ID of the category that the post is assigned to
    score*: int64
    ## A cached calculation of the score that is generated using countScore, can
    ## also be increased without calculating the score if using the addVote and
    ## removeVote

  Vote* = ref object of Model
    ## Representation of a vote that affects a Post
    userID*: int64
    ## The ID of the user performing the vote
    postID*: int64
    ## The post which the vote is being performed on
    score*: int
    ## The score leniance of of the vote, an Upvote (1) increases the score
    ## while a Downvote (-1) decreases the score.

func newUser*(
  name = "",
  auth = AuthMethod(),
  super = false
): User =
  User(
    name: name,
    auth: auth,
    super: super
  )

proc registerNewUser*(dbConn: DbConn, username: string, password: string;
                     super = false): User
  {.raises: [NotFoundError, ValueError, DbError, Exception].} =
  ## Registers a new user in the database using the PassAuth method
  # Create a user object and add them to the database
  block:
    let passAuth = newPassAuth(password)
    var user = newUser(username, passAuth, super)
    dbConn.insert(user)
  # Get the user from the database so we can retrieve the ID and
  # return it
  block:
    result = newUser()
    dbConn.select(result, "User.name = ?", username)
  
func newCategory*(
  name = "",
  parentID = none(int64)
): Category =
  Category(
    name: name,
    parentID: parentID
  )
  
func newTag*(
  name = "",
  color = "#000000"
): Tag =
  Tag(
    name: name,
    color: color
  )

func newTagPostRelationship*(
  postID: int64 = 0,
  tagID: int64 = 0
): TagPostRelationship =
  TagPostRelationship(
    postID: postID,
    tagID: tagID
  )

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

func newPost*(
  content = "",
  title = "",
  categoryID: int64 = -1,
): Post =
  Post(
    content: content,
    title: title,
    categoryID: categoryID
  )
  
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
    var tag = newTag()
    for i in tagIDs:
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
  
func newVote*(
  userID: int64 = 0,
  postID: int64 = 0,
  score = 1
): Vote =
  Vote(
    userID: userID,
    postID: postID,
    score: score
  )

proc addVote*(dbConn: DbConn, user: User, post: Post, score: int)
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
  except NotFoundError:
    discard dbConn.create(newVote(user.id, post.id, score))
      
proc removeVote*(dbConn: DbConn, user: User, post: Post)
  {.raises: [NotFoundError, DbError, ValueError].} =
  ## Removes a vote issued from the user if it exists. Raises a
  ## NotFoundError if the vote does not exist.
  var vote = newVote()
  with dbConn:
    select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
    delete vote
        
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
