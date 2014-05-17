# Example usage:

IndexServer = require("../server")
FIREBASE_URL = "index-server.firebaseIO.com"
_ = require("underscore")


# Index a post's tags (located in /posts/$postId/tags/$tagId)
# to /tags/$postId/$tagId/
exampleIndex =
  type: "tagIndex"
  sourcePath: "/posts/"
  sourceAttribute: "tags"
  indexPath: "/tags/"

server = IndexServer
  index: exampleIndex
  FIREBASE_URL: FIREBASE_URL

# Add a random post, with a tag:

Firebase = require("firebase")
rootRef = new Firebase(FIREBASE_URL)

randomPost = ->

  tagWords = ["schools", "ought", "to", "function", "more", "like", "schools", "and", "less", "like", "prison"]

  randomElement = (array, remove=false) ->
    desiredIndex = Math.floor(Math.random() * array.length)
    element = array[desiredIndex]
    array.splice(desiredIndex, 1) if remove == true
    element

  randomWords = (list, number) ->
    list = _.clone list
    words = []
    for n in [0..number-1]
      words.push randomElement(list, true)
    words.join(" ")

  randomTag = ->
    length = Math.floor(Math.random() * 3 + 1)
    words = randomWords(tagWords, length)
    slugify(words)

  slugify = (string) -> 
    string.toLowerCase().replace(/\W/g, "-")

  capitalize = (string) ->
    string.charAt(0).toUpperCase() + string.slice(1)

  tags = {}
  tags[randomTag()] = true
  tags[randomTag()] = true
  title = capitalize(randomWords(tagWords, 3))

  { 
    title: title
    tags: tags
  }
rootRef.child("posts").push randomPost()
