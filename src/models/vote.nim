from sugar import dup
from sequtils import foldl
import norm/[sqlite, model, pragmas]
import post, user

type
  Vote* = ref object of Model
    user*: UserModel
    post*: PostModel
    score*: int


func newVote*(
  user = UserModel(),
  post = PostModel(),
  score = 1
): Vote =
  Vote(
    user: user,
    post: post,
    score: score
  )

proc calculateVotes*(post: PostModel, dbConn: DbConn): int =
  let votes = @[newVote()].dup:
    dbConn.select "Vote.post.id = ?", post.id
  result = foldl(votes, a + b.score, 0)
