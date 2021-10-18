import auth
import norm/[sqlite, model, pragmas]
import options
import std / with
from sequtils import foldl

const
  Upvote* = 1
  Downvote* = -1

type
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
    parentID: Option[int64]
    ## The parent ID of the category
  
  Post* = ref object of Model
    ## A Post on the website
    content*: string
    ## The content of the post
    title* {.unique.}: string
    ## The title of the post
    categoryID*: int64
    ## The ID of the category that the post is assigned to
    
  Tag* = ref object of Model
    ## Tags which can be attached to a post
    name* {.unique.}: string
    ## The name of the tag
    color*: string
    ## Hex-code formatted for display on the website

  TagPostRelationship = ref object of Model
    ## Creates a relationship between the posts and the tags that
    ## are attached to the post
    postID: int64
    ## The ID of the post that is attached to the tag
    tagID: int64
    ## The ID of the tag that is attached to the post

  Vote* = ref object of Model
    ## Representation of a vote that affects a Post
    userID: int64
    ## The ID of the user performing the vote
    postID: int64
    ## The post which the vote is being performed on
    score: int
    ## The score leniance of of the vote, an Upvote increases the score
    ## while a Downvote decreases the score.

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
  {.raises: [NotFoundError, ValueError, DbError].} =
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
      raise ValueError.newException("An identical vote already exists.")
    vote.score = score
    dbConn.update vote
  except NotFoundError:
    var vote = newVote(user.id, post.id, score)
    dbConn.insert vote
      
proc removeVote*(dbConn: DbConn, user: User, post: Post)
  {.raises: [NotFoundError, DbError, ValueError].} =
  ## Removes a vote issued from the user if it exists. Raises a
  ## NotFoundError if the vote does not exist.
  var vote = newVote()
  with dbConn:
    select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
    delete vote
    
func newPost*(
  content = "",
  title = "",
  categoryID = -1,
): Post =
  Post(
    content: content,
    title: title,
    categoryID: categoryID
  )

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
  result.createTables(newTag())
  result.createTables(newVote())
  result.createTables(newPost())      
