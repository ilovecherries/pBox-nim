import ../src/model
import norm/[sqlite]
import unittest
import std / with

suite "Database/Models":
  let dbConn = createDatabase()
  suite "Tags":
    const testTitle = "title"
    const testTagName = "testtag"
    var
      category = dbConn.create(newCategory("Test Category"))
      post: Post
      tag = dbConn.create(newTag(testTagName))

    setup:
      post = dbConn.create(
        newPost("my content", testTitle, category.id)
      )

    teardown:
      dbConn.delete post

    test "Creating a post with a single tag and checking the tag is attached":
      var
        post = dbConn.createPost(
          "the content",
          "the super cool title",
          category.id,
          @[tag.id]
        )
        tags = dbConn.getTags(post)
      dbConn.delete post
      check tags[0].name == testTagName

    test "Adding a tag to an existing post and checking if it is attached":
      dbConn.addTag(post, tag)
      let tags = dbConn.getTags(post)
      check tags[0].name == testTagName
      
    test "Adding a single to a post multiple times should error":
      dbConn.addTag(post, tag)
      expect(DuplicateError):
        dbConn.addTag(post, tag)

    with dbConn:
      delete tag
      delete category
  
  suite "Votes":
    var
      user = newUser()
      post = newPost()

    teardown:
      try:
        dbConn.removeVote user, post
      except NotFoundError:
        discard
    
    test "Score that is -1 (Downvote) should be valid":
      dbConn.addVote user, post, Downvote
    
    test "Score that is 1 (Upvote) should be valid":
      dbConn.addVote user, post, Downvote
    
    test "Score that is invalid should throw error":
      expect(ValueError):
        dbConn.addVote user, post, 0
        
    test "Should throw error is vote with identical copy is made":
      dbConn.addVote user, post, Upvote
      expect(DuplicateError):
        dbConn.addVote user, post, Upvote

    test "Removing vote that doesn't exist should throw error":
      expect(NotFoundError):
        dbConn.removeVote user, post
      
    test "Adding positive votes should increase score":
      var
        user1 = User(id: 1)
        user2 = User(id: 2)
        user3 = User(id: 3)
      with dbConn:
        addVote user1, post, Upvote
        addVote user2, post, Upvote
        addVote user3, post, Upvote
      let voteCount = dbConn.countScore(post)
      with dbConn:
        removeVote user1, post
        removeVote user2, post
        removeVote user3, post
      check voteCount == 3
            
    test "Adding negative votes should decrease score":
      var
        user1 = User(id: 1)
        user2 = User(id: 2)
        user3 = User(id: 3)
      with dbConn:
        addVote user1, post, Downvote
        addVote user2, post, Downvote
        addVote user3, post, Downvote
      let voteCount = dbConn.countScore(post)
      with dbConn:
        removeVote user1, post
        removeVote user2, post
        removeVote user3, post
      check voteCount == -3
