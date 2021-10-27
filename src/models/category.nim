import options
import norm/[model, pragmas]

type
  Category* = ref object of Model
    ## A category which posts can fit into
    name* {.unique.}: string
    ## The name of the category
    parentID*: Option[int64]
    ## The parent ID of the category

func newCategory*(
  name = "",
  parentID = none(int64)
): Category =
  Category(
    name: name,
    parentID: parentID
  )
