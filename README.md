Firebase Index Server
===

Maintain indexes in Firebase.

## The problem

Let's say you're building a blog on Firebase and want to be able to tag posts. If you store the tags inside your `post` documents, it's impossible to query your posts by tag, so we denormalize, and store tags separately:

```coffeescript
  posts/end-of-world =>
    title: "End of the world"
    tags:
      announcement: true
      pessimistic: true
    
  tags =>
    pessimistic:
      my-post: true
    announcement: 
      my-post: true
```

Then, we can query by tag by calling something like firebaseRoot.child("tags/pessimistic") to get the IDs of relevant posts.

But every time we save a post, we need to remember to update the associated tags, adding or removing tags as they change. And if we're exposing an API to developers, we've created a new headache for them, too. It's repetitive and annoying.

`firebase-index-server` is designed to solve this problem by watching `posts` for changes, and updating tags appropriately. In the background, it saves a copy of each post's tags so that when the data changes, we can compare the new tags with the old ones, and know which tags need updating.

This is more of a proof-of-concept than production-grade utility, but if others find this useful, I hope we can improve it.

## Instructions

To use, require the server and pass in an index that looks like this:

```coffeescript

indexServer = require("./server")

indexServer
  FIREBASE_URL: "index-server.firebaseIO.com"
  index:
    type: "tagIndex"
    sourcePath: "/posts/"
    sourceAttribute: "tags"
    indexPath: "/tags/"

```

This index would read posts like this:

```coffeescript
/post/id123 =>
  title: "End of the world"
  tags:
    announcement: true
    pessimistic: true
```

...and create these indexes:

```coffeescript
/tags =>
  pessimistic:
    id123: true
  announcement:
    id123: true
```

(when posts are modified or removed, indexes should be kept in sync)

By default, the priority of the indexes are set to the priority of the source object. You can pass in a `priority` function in the index, which receives the current snapshot of the object and should return the desired priority. 

## Ways to improve

- Pass in multiple indexes instead of just one
- Store the indexes in Firebase itself, and add a GUI to manage indexes on your Firebase
- Add commands to test indexes for consistency and regenerate indexes if necessary
