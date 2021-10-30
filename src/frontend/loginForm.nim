include karax / prelude
import karax / [errors, kajax]
import json

from strformat import fmt

from state import token

const
  usernameField = kstring"login-username"
  passwordField = kstring"login-password"

type
  UserCredentials = object
  LoginForm* = ref object of VComponent
    usernameValue*: kstring
    passwordValue*: kstring

proc render*(x: VComponent): VNode =
  proc validateField(field: kstring, name: kstring): proc () =
    result = proc () =
      let x = getVNodeById(field).getInputText
      if x.isNil or x == "":
        errors.setError(field, name & " must not be empty")
      else:
        errors.setError(field, "")

  proc login() =
    proc completeLogin(httpStatus: int, response: kstring) =
      if httpStatus == 200:
        token = response
      else:
        errors.setError(usernameField, "Invalid username or password")
    let
      username = getVNodeById(usernameField).getInputText
      password = getVNodeById(passwordField).getInputText
    let credentials = "{\"username\":\""&username&"\",\"password\":\""&password&"\"}"
    ajaxPost(
      "/login/",
      @[],
      credentials,
      completeLogin
    )

  result = buildHtml(tdiv):
    tdiv(class = "form-group"):
      label(`for` = usernameField):
        text "Username"
      input(type = "text", class = "form-control", id = usernameField,
            placeholder = "Username",
            onchange = validateField(usernameField, "Username"))
      p:
        text errors.getError(usernameField)
    tdiv(class = "form-group"):
      label(`for` = passwordField):
        text "Password"
      input(type = "password", class = "form-control", id = passwordField,
            placeholder = "Password",
            onchange = validateField(passwordField, "Password"))
      p:
        text errors.getError(passwordField)
    tdiv(class = "form-group form-check"):
      input(type = "checkbox", class = "form-check-input",
          id = "rememberMe")
      label(class = "form-check-label", `for` = "rememberMe"):
        text "Remember me"
    button(type = "submit", class = "btn btn-primary", onclick = login):
      text "Login"
    text "owo"

proc buildLoginForm*(nref: var LoginForm): LoginForm =
  if nref == nil:
    nref = newComponent(LoginForm, render)
    return nref
  else:
    return nref
