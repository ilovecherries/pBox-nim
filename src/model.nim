import auth
import norm/[sqlite, model, pragmas]
import options
import std / with

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
    childrenIDs*: Option[seq[int64]]
    ## When there are children to the category, the category is
    ## considered a Parent category and should not be able to be
    ## assigned to directly. (maybe? should consult)

  Tag* = ref object of Model
    ## Tags which can be attached to a post
    name* {.unique.}: string
    ## The name of the tag
    color*: string
    ## Hex-code formatted for display on the website

  VoteType* {.pure.} = enum
    Upvote = 1
    Downvote = -1

  Vote* = ref object of Model
    ## Representation of a vote that affects a Post
    userID: int64
    ## The ID of the user performing the vote
    postID: int64
    ## The post which the vote is being performed on
    score: VoteType
    ## The score leniance of of the vote, an Upvote increases the score
    ## while a Downvote decreases the score.

  Post* = ref object of Model
    ## A Post on the website
    content*: string
    ## The content of the post
    title* {.unique.}: string
    ## The title of the post
    categoryID*: int64
    ## The ID of the category that the post is assigned to
    tagIDs*: seq[int64]
    ## The IDs of the tags that the post has attached to itself

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
  childrenIDs = none(seq[int64])
): Category =
  Category(
    name: name,
    childrenIDs: childrenIDs
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
  userID: int64,
  postID: int64,
  score = VoteType.Upvote
): Vote =
  Vote(
    userID: int64,
    postID: int64,
    score
  )

proc addVote(dbConn: DbConn, user: User, post: Post, score: VoteType)
  {.raises: [NotFoundError, ValueError, DbError].} =
  # see if a vote that already matches this exists
  try:
    var vote()
    dbConn.select vote, "Vote.userID = ? AND Vote.postID", user.id, post.id
    # create an exception if this has the same score
    if vote.score
  except NotFoundError:
    discard
      
proc removeVote(dbConn: DbConn, user: User, post: Post)
  {.raises: [NotFoundError, DbError].} =
  var vote = newVote()
  with dbConn:
    select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
    delete vote
    
func newPost*(
  content = "",
  title = "",
  categoryID = -1,
  tagIDs = newSeq[int64]()
): Post =
  Post(
    content: content,
    title: title,
    categoryID: categoryID,
    tagIDs: tagIDs
  )
  
proc createDatabase*(filename = ":memory"): DbConn =
  result = open(filename, "", "", "")
  result.createTables(newUser())
  result.createTables(newCategory())
  result.createTables(newTag())
  result.createTables(newVote())
  result.createTables(newPost())      
