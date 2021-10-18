import ../src/model
import norm/[sqlite]
import unittest
import std / with

suite "Database/Models":
  let dbConn = createDatabase()
  suite "Votes":
    var
      user = newUser()
      post = newPost()

    teardown:
      try:
        dbConn.removeVote user, post
      except NotFoundError:
        discard
    
    test "Score that is -1 (Downvote)":
      dbConn.addVote user, post, Downvote
    
    test "Score that is 1 (Upvote)":
      dbConn.addVote user, post, Downvote
    
    test "Score that is invalid should throw error":
      expect(ValueError):
        dbConn.addVote user, post, 0
        
    test "Should throw error is vote with identical copy is made":
      dbConn.addVote user, post, Upvote
      expect(ValueError):
        dbConn.addVote user, post, Upvote
