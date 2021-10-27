import options
import json
from sugar import collect, dup
import norm/[model, pragmas]
import category, tag

type
  Post* = object
    id: int64
    title: string
    score: int64
    category: Category
    tags: seq[Tag]
    myScore: Option[int]

when not defined(js):
  import norm/sqlite

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
      tag*: Tag
      ## The tag
      post*: Post
      ## The post

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
    post: Post = Post(),
    tag: Tag = Tag()
  ): TagPostRelationship =
    TagPostRelationship(
      post: post,
      tag: tag
    )

  proc tags*(post: PostModel, dbConn: DbConn): seq[Tag] =
    ## Returns the tags attached to the post
    let relationships = @[newTagPostRelationship()].dup:
      dbConn.select("TagPostRelationship.post.id = ?", post.id)
    result = collect(newSeq):
      for i in relationships:
        var tag = newTag()
        dbConn.select tag, "Tag.id = ?", i.tag.id
        tag

  proc toSerialized*(post: PostModel, dbConn: DbConn;
      authorizedUser = ""): string =
    ## Returns a serialized version of the post
    let serialized = Post(
      id: post.id,
      title: post.title,
      score: post.score,
      category: post.category,
      tags: post.tags(dbConn),
      myScore: none int,
    )
    result = $(%*serialized)
