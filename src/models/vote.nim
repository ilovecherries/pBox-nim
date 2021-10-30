from sequtils import foldl
import norm/[sqlite, model]
import post, user

const
  Upvote* = 1
  Downvote* = -1


type
  Vote* = ref object of Model
    user*: UserModel
    userID*: int64
    post*: PostModel
    postID*: int64
    score*: int


func newVote*(
  user = newUser(),
  post = newPost(),
  score = 1
): Vote =
  Vote(
    user: user,
    userID: user.id,
    post: post,
    postID: post.id,
    score: score
  )

proc calculateVotes*(post: PostModel, dbConn: DbConn): int =
  var votes = @[newVote()]
  dbConn.select votes, "Vote.post.id = ?", post.id
  foldl(votes, a + b.score, 0)

proc addVote*(post: var PostModel, dbConn: DbConn, user: UserModel,
    score: int): Vote =
  # check if the score is valid
  if score != Upvote and score != Downvote:
    raise ValueError.newException "Invalid vote score"
  # check if thie vote already exists
  try:
    var vote = newVote()
    dbConn.select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
    if vote.score == score:
      raise DbError.newException "Vote with this score already exists"
    vote.score = score
    dbConn.update vote
    post.score += score * 2
    dbConn.update post
    vote
  # if it doesn't create a new vote
  except NotFoundError:
    var vote = newVote(user, post, score)
    dbConn.insert vote
    vote

proc removeVote*(post: var PostModel, dbConn: DbConn, user: UserModel): Vote =
  var vote = newVote(user, post, Upvote)
  dbConn.select vote, "Vote.userID = ? AND Vote.postID = ?", user.id, post.id
  post.score -= vote.score
  dbConn.delete vote
  dbConn.update post
