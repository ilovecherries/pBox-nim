include karax / prelude

from ../models import Post
const
  UpvoteIndex = 0
  DownvoteIndex = 1

type
  VoteState = enum
    ## Symbols that represent different states of the vote
    Downvote = -1
    ## A negative "down" vote
    Neutral = 0
    ## An undecided "neutral" vote
    Upvote = 1
    ## A positive "up" vote

  PostDisplay* = ref object of VComponent
    post: Post
    ## The post that is being displayed by the component
    myVote: VoteState
    ## The offset of the vote that is used for display
    oldVote: VoteState
    ## The offset of the vote that is used for display

proc render*(x: VComponent): VNode =
  let self = PostDisplay(x)

  proc voteHandler(ev: Event; n: VNode) =
    case n.index
    of UpvoteIndex:
      self.myVote = if self.myVote == VoteState.Upvote:
        VoteState.Neutral
      else:
        VoteState.Upvote
    of DownvoteIndex:
      self.myVote = if self.myVote == VoteState.Downvote:
        VoteState.Neutral
      else:
        VoteState.Downvote
    else: discard
    markDirty(self)
    redraw()

  result = buildHtml(tdiv(class = "row")):
    tdiv(class = "col-1 fs-4 mx-auto"):
      tdiv(class = "row justify-content=center"):
        button(`aria-label` = "Upvote",
          class = "btn " & (if self.myVote ==
            VoteState.Upvote: "btn-success" else: "btn-outline-success"),
          onclick = voteHandler, index = UpvoteIndex):
          span(class = "bi-arrow-up-short")
      tdiv(class = "row justify-content-center"):
        text $(self.post.score + cast[int64](self.myVote))
      tdiv(class = "row justify-content=center"):
        button(`aria-label` = "Downvote",
          class = "btn " & (if self.myVote ==
            VoteState.Downvote: "btn-danger" else: "btn-outline-danger"),
          onclick = voteHandler, index = DownvoteIndex):
          span(class = "bi-arrow-down-short")
    tdiv(class = "col-11"):
      tdiv(class = "text-secondary px-2 row"):
        text self.post.category.name
      tdiv(class = "text-primary row fs-2 px-2"):
        text self.post.title
      tdiv(class = "text-primary d-flex flex-row"):
        for i in self.post.tags:
          tdiv(class = "badge bg-secondary m-1 rounded-pill"):
            text i.name
      tdiv(class = "px-2 row"):
        text self.post.content

proc buildPostDisplay*(post: Post; nref: var PostDisplay): PostDisplay =
  if nref == nil:
    nref = newComponent(PostDisplay, render)
    nref.post = post
    return nref
  else:
    return nref
