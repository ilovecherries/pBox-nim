include karax / prelude
import karax/kajax
import json

from ../models import Post, newPost

from post import PostDisplay, buildPostDisplay

var postDisplays = newSeq[PostDisplay]()

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = "container"):
      tdiv(class = "navbar navbar-expand-lg navbar-light bg-light"):
        tdiv(class = "container-fluid"):
          tdiv(class = "navbar-brand"):
            text "pBox"
          tdiv(class = "nav-item"):
            text "hello"
    tdiv(class = "container m-4"):
      for i in postDisplays:
        i

setRenderer createDom

proc postResponseHandler(httpStatus: int, response: kstring) =
  let parsed = parseJson($response)
  let posts = parsed.to(seq[Post])
  for i in posts:
    var component: PostDisplay
    postDisplays.add buildPostDisplay(i, nref = component)

ajaxGet("/posts/", @[], postResponseHandler, doRedraw = true)
