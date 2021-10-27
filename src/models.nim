import options

when not defined(js):
  import auth
  import norm/[model, pragmas]
when defined(js):
  type Model = ref object of RootObj
    id*: int64
  template unique* {.pragma.}

type
  User* = ref object of Model
    ## Someone who interacts with the website.
    name* {.unique.}: string
    ## The username assigned to the user.
    super*: bool
    ## Whether the user is privileged on the site in order to moderate
    ## or to configure the website.
    when not defined(js):
      authID*: int64
      ## The authentification method ID for details that the user has
      ## in order to sign in.

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

  Post* = ref object of Model
    ## A Post on the website
    content*: string
    ## The content of the post
    title* {.unique.}: string
    ## The title of the post
    score*: int64
    ## A cached calculation of the score that is generated using countScore, can
    ## also be increased without calculating the score if using the addVote and
    ## removeVote
    when defined(js):
      tags*: seq[Tag]
      ## The tags that are attached to the post
      category*: Category
      ## The category that the post is assigned to
      myScore*: Option[int]
    else:
      categoryID*: int64
      ## The ID of the category that the post is assigned to

  Vote* = ref object of Model
    ## Representation of a vote that affects a Post
    userID*: int64
    ## The ID of the user performing the vote
    postID*: int64
    ## The post which the vote is being performed on
    score*: int
    ## The score leniance of of the vote, an Upvote (1) increases the score
    ## while a Downvote (-1) decreases the score.
    ##

when not defined(js):
  type AuthSession* = ref object of Model
    ## An authentication session for a user
    userID*: int64
    ## The user that the session is for
    token*: string
    ## The token that is used to access the data for the user


when not defined(js):
  func newUser*(
    name = "",
    authID: int64 = 0,
    super = false
  ): User =
    User(
      name: name,
      authID: authID,
      super: super
    )
else:
  func newUser*(
    name = "",
    super = false
  ): User =
    User(
      name: name,
      super: super
    )

func newTag*(
  name = "",
  color = "blue"
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

when not defined(js):
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
else:
  func newPost*(
    content = "",
    title = "",
  ): Post =
    Post(
      content: content,
      title: title,
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

when not defined(js):
  func newAuthSession*(
    userID: int64 = 0,
    token = ""
  ): AuthSession =
    AuthSession(
      userID: userID,
      token: token
    )
