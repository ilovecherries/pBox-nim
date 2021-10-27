import norm/[model, pragmas]

type
  Tag* = ref object of Model
    ## Tags which can be attached to a post
    name* {.unique.}: string
    ## The name of the tag
    color*: string
    ## Hex-code formatted for display on the website


func newTag*(
  name = "",
  color = "blue"
): Tag =
  Tag(
    name: name,
    color: color
  )
