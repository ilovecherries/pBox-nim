include karax / prelude
import karax/kajax
import json

from state import token

from ../models/post import Post

from postdisplay import PostDisplay, buildPostDisplay
from loginForm import LoginForm, buildLoginForm

var postDisplays = newSeq[PostDisplay]()
var lForm: LoginForm = nil

type
  UserCreadentials = object
    username*: string
    password*: string

proc createDom(): VNode =
  result = buildHtml(tdiv):
    tdiv(class = "container"):
      tdiv(class = "navbar navbar-expand-lg navbar-light bg-light"):
        tdiv(class = "container-fluid"):
          tdiv(class = "navbar-brand"):
            text "pBox"
          tdiv(class = "nav-item"):
            text "hello"
    if token == "":
      buildLoginForm(lForm)
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
