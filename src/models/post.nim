import options
from sugar import collect, dup
import norm/[model, pragmas]
import category

type
  Tag* = ref object of Model
    ## Tags which can be attached to a post
    name* {.unique.}: string
    ## The name of the tag
    color*: string
    ## Hex-code formatted for display on the website

  Post* = object
    id*: int64
    title*: string
    content*: string
    score*: int64
    category*: Category
    tags*: seq[Tag]
    myScore*: Option[int]

func newTag*(
  name = "",
  color = "blue"
): Tag =
  Tag(
    name: name,
    color: color
  )

when not defined(js):
  import norm/sqlite
  from ../dbhelper import create

  type
    PostModel* = ref object of Model
      ## A Post on the website
      content*: string
      ## The content of the post
      title* {.unique.}: string
      ## The title of the post
      score*: int64
      ## A cached calculation of the score that is generated using countScore, can
      ## also be increased without calculating the score if using the addVote and
      ## removeVote
      category*: Category
      ## The category that the post is listed under

    TagPostRelationship* = ref object of Model
      ## A relationship between a tag and a post
      tagID*: int64
      tag*: Tag
      ## The tag
      post*: PostModel
      ## The post
      postID*: int64

  func newPost*(
    title: string = "",
    content: string = "",
    category: Category = Category()
  ): PostModel =
    ## Creates a new post
    PostModel(
      title: title,
      content: content,
      category: category,
      score: 0,
    )

  func newTagPostRelationship*(
    post: PostModel = newPost(),
    tag: Tag = newTag()
  ): TagPostRelationship =
    TagPostRelationship(
        post: post,
        postID: post.id,
        tag: tag,
        tagID: tag.id
    )

  proc delete*(dbConn: DbConn, tag: var Tag) =
    ## A modified version of DbConn.delete for removing all
    ## tag-post relationships associated with the tag.
    # delete all of the TagPostRelationships associated with the tag
    var relationships = @[newTagPostRelationship()]
    dbConn.select relationships, "TagPostRelationship.tagID = ?", tag.id
    for i in relationships:
      var model = i
      dbConn.delete model
    sqlite.delete(dbConn, tag)

  proc delete*(dbConn: DbConn, post: var PostModel) =
    ## A modified version of DbConn.delete for removing all
    ## tag-post relationships associated with the post.
    # delete all of the TagPostRelationships associated with the post
    var relationships = @[newTagPostRelationship()]
    dbConn.select relationships, "TagPostRelationship.postID = ?", post.id
    for i in relationships:
      var model = i
      dbConn.delete model
    sqlite.delete(dbConn, post)

  proc tags*(post: PostModel, dbConn: DbConn): seq[Tag] =
    ## Returns the tags attached to the post
    let relationships = @[newTagPostRelationship()].dup:
      dbConn.select("TagPostRelationship.postID = ?", post.id)
    result = collect(newSeq):
      for i in relationships:
        var tag = newTag()
        dbConn.select tag, "Tag.id = ?", i.tag.id
        tag

  proc toSerialized*(post: PostModel, dbConn: DbConn;
      authorizedUser = ""): Post =
    ## Returns a serialized version of the post
    Post(
      id: post.id,
      title: post.title,
      score: post.score,
      category: post.category,
      tags: post.tags(dbConn),
      myScore: none int,
    )

  proc createPost*(dbConn: DbConn, title: string, content: string,
                   category: Category, tags: seq[Tag]): PostModel =
    ## Creates a new post
    # check if a post with the same title already exists
    try:
      var post = newPost()
      dbConn.select post, "PostModel.title = ?", title
      raise DbError.newException("A post with the same title already exists")
    except NotFoundError:
      discard
    # create the post and add it to the database
    result = dbConn.create(newPost(title, content, category))
    # add all of the tags to the post
    dbConn.transaction:
      for i in tags:
        var rel = newTagPostRelationship(result, i)
        dbConn.insert rel
