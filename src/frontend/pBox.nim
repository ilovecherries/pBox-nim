include karax / prelude
import karax/kajax
import json

from ../models/post import Post

from postdisplay import PostDisplay, buildPostDisplay

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
    tdiv(class = "card"):
      tdiv(class = "card-header"):
        text "Account"
      tdiv(class = "card-body"):
        tdiv(class = "card-title"):
          text "Register"
        tdiv(class = "card-text"):
          form:
            tdiv(class = "form-group"):
              label(`for` = "username"):
                text "Username"
              input(type = "text", class = "form-control", id = "username",
                    placeholder = "Username")
            tdiv(class = "form-group"):
              label(`for` = "password"):
                text "Password"
              input(type = "password", class = "form-control", id = "password",
                    placeholder = "Password")
            # tdiv(class = "form-group form-check"):
            #   input(type = "checkbox", class = "form-check-input", id = "rememberMe")
            #   label(class = "form-check-label", for = "rememberMe"):
            #     text "Remember me"
            button(type = "submit", class = "btn btn-primary"):
              text "Register"
        tdiv(class = "card-title"):
          text "Login"
        tdiv(class = "card-text"):
          form:
            tdiv(class = "form-group"):
              label(`for` = "username"):
                text "Username"
              input(type = "text", class = "form-control", id = "username",
                    placeholder = "Username")
            tdiv(class = "form-group"):
              label(`for` = "password"):
                text "Password"
              input(type = "password", class = "form-control", id = "password",
                    placeholder = "Password")
            tdiv(class = "form-group form-check"):
              input(type = "checkbox", class = "form-check-input",
                  id = "rememberMe")
              label(class = "form-check-label", `for` = "rememberMe"):
                text "Remember me"
            button(type = "submit", class = "btn btn-primary"):
              text "Login"
    tdiv(class = "container m-4"):
      for i in postDisplays:
        i

setRenderer createDom

proc postResponseHandler(httpStatus: int, response: kstring) =
  let parsed = parseJson($response)
  echo parsed
  let posts = parsed.to(seq[Post])
  for i in posts:
    var component: PostDisplay
    postDisplays.add buildPostDisplay(i, nref = component)

ajaxGet("/posts/", @[], postResponseHandler, doRedraw = true)
