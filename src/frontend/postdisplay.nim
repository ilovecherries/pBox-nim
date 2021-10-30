include karax / prelude
import karax/kajax
import json
from state import token

from ../models/post import Post
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
    vote: VoteState
    ## The offset of the vote that is used for display
    oldVote: VoteState
    ## The offset of the vote that is used for display
    midRequest: bool
    ## While there is a request happening, the buttons for doing votes on
    ## a post should be disabled

proc render*(x: VComponent): VNode =
  let self = PostDisplay(x)

  proc onVoteResponse(httpStatus: int, response: kstring) =
    if httpStatus != 200:
      self.vote = self.oldVote
    self.midRequest = false
    markDirty(self)
    redraw()

  proc voteHandler(ev: Event; n: VNode) =
    self.oldVote = self.vote
    self.midRequest = true
    case n.index
    of UpvoteIndex:
      self.vote = if self.vote == VoteState.Upvote:
        VoteState.Neutral
      else:
        VoteState.Upvote
    of DownvoteIndex:
      self.vote = if self.vote == VoteState.Downvote:
        VoteState.Neutral
      else:
        VoteState.Downvote
    else: discard
    if self.vote == VoteState.Neutral:
      ajaxDelete(
        "/posts/" & $self.post.id & "/vote",
        @[(cstring"Authorization", cast[cstring](token))],
        onVoteResponse
      )
    else:
      ajaxPost(
        "/posts/" & $self.post.id & "/vote",
        @[(cstring"Authorization", cast[cstring](token))],
        "{\"score\":" & $cast[int](self.vote) & "}",
        onVoteResponse
      )
    markDirty(self)
    redraw()

  result = buildHtml(tdiv(class = "row")):
    tdiv(class = "col-1 fs-4 mx-auto"):
      tdiv(class = "row justify-content=center"):
        let clsup = "btn " & (if self.vote ==
            VoteState.Upvote: "btn-success" else: "btn-outline-success")
        if self.midRequest:
          button(`aria-label` = "Upvote",
            class = clsup,
            disabled = "",
            onclick = voteHandler, index = UpvoteIndex):
            span(class = "bi-arrow-up-short")
        else:
          button(`aria-label` = "Upvote",
            class = clsup,
            onclick = voteHandler, index = UpvoteIndex):
            span(class = "bi-arrow-up-short")
      tdiv(class = "row justify-content-center"):
        text $(self.post.score + cast[int64](self.vote))
      tdiv(class = "row justify-content=center"):
        let clsdown = "btn " & (if self.vote ==
            VoteState.Downvote: "btn-danger" else: "btn-outline-danger")
        if self.midRequest:
          button(`aria-label` = "Downvote",
            class = clsdown,
            disabled = "",
            onclick = voteHandler, index = DownvoteIndex):
            span(class = "bi-arrow-down-short")
        else:
          button(`aria-label` = "Downvote",
            class = clsdown,
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
    tdiv:
      text $self.midRequest

proc buildPostDisplay*(post: Post; nref: var PostDisplay): PostDisplay =
  if nref == nil:
    nref = newComponent(PostDisplay, render)
    nref.post = post
    return nref
  else:
    return nref
