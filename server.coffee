###

  Firebase Index Server
  ===

  A small node.js server that will maintain indexes on Firebase paths.
  
  Based on this discussion:
  https://groups.google.com/forum/#!topic/firebase-talk/ZSkIBC9FhOQ

###

# Eventually we can dynamically create indexes, possibly
# using a web UI.

Firebase = require("firebase")
_ = require("underscore")

blankSnapshot =
  val: -> null
  child: -> blankSnapshot
  getPriority: -> null

module.exports = IndexServer = (options) ->
  
  # connect to Firebase
  {FIREBASE_URL} = options
  rootRef = options.ref || new Firebase(FIREBASE_URL)

  for index in options.indexes
    uid = ""
    for key, value of index
      if typeof key == 'string' and typeof value == 'string' and key != 'type'
        uid+=key+"_" unless key == 'type'
        uid+= value+"_" if typeof value == 'string'
        uid = uid.replace /\//g, "_"
    Handlers[index.type](rootRef, index, uid)

Handlers = {}
Handlers.manyToMany = (rootRef, index, uid) ->
  updateTags = (event) ->
    (currentSnap) ->
      id = currentSnap.name()

      # Get previous version of element
      previousPath = "previous/#{index.sourcePath}/#{id}/#{index.sourceAttribute}"
      rootRef.child(previousPath).once "value", (prevSnap) ->
        # console.log "-- #{event} --"

        # child_removed passes the *old* version of the snapshot.
        # Use a blank snapshot instead.
        if event == "child_removed" then currentSnap = blankSnapshot
        
        # Diff current and previous tags 
        prevTags = _.keys(prevSnap.val() || {})
        currentTags = _.keys(currentSnap.child(index.sourceAttribute).val() || {})
        newTagList = _(currentTags).difference prevTags
        removedTagList = _(prevTags).difference currentTags

        # Compare current priority with previous priority.
        # If the priority has changed, update all tags.
        priority = index.priority?(currentSnap) || currentSnap.getPriority()
        if index.priority and (priority != prevSnap.getPriority())
          newTagList = currentTags

        # We can provide a function that will modify the key before
        # using it as an index
        keyTransform = index.keyTransform || (key) -> key



        # Update indexes
        for tag in newTagList
          # console.log keyTransform(tag)
          rootRef.child("#{index.indexPath}/#{keyTransform(tag)}/#{id}").setWithPriority true, priority
        for tag in removedTagList
          # console.log keyTransform(tag)
          rootRef.child("#{index.indexPath}/#{keyTransform(tag)}/#{id}").set null
        
        # Save previous version, with priority
        rootRef.child(previousPath).setWithPriority currentSnap.child(index.sourceAttribute).val(), priority

  # Listen for changes
  rootRef.child("#{index.sourcePath}").on "child_changed", updateTags("child_changed")
  rootRef.child("#{index.sourcePath}").on "child_added", updateTags("child_added")
  rootRef.child("#{index.sourcePath}").on "child_removed", updateTags("child_removed")
Handlers.oneToOne = (rootRef, index, uid) ->
  updateTags = (event) ->
    (currentSnap) ->
      id = currentSnap.name()

      # Get previous version of element
      previousPath = "previous/#{index.sourcePath}/#{id}/#{index.sourceAttribute}"
      rootRef.child(previousPath).once "value", (prevSnap) ->
        # console.log "-- #{event} --"

        # child_removed passes the *old* version of the snapshot.
        # Use a blank snapshot instead.
        if event == "child_removed" then currentSnap = blankSnapshot
        
        prevTag = prevSnap.val()
        currentTag = currentSnap.child(index.sourceAttribute).val()

        keyTransform = index.keyTransform || (key) -> key

        priority = index.priority?(currentSnap) || currentSnap.getPriority()

        # Update indexes
        if prevTag != currentTag
          rootRef.child("#{index.indexPath}/#{keyTransform(prevTag)}/#{id}").set null
        if currentTag != null
          rootRef.child("#{index.indexPath}/#{keyTransform(currentTag)}/#{id}").setWithPriority true, priority
          
        # Save previous version, with priority
        rootRef.child(previousPath).setWithPriority currentSnap.child(index.sourceAttribute).val(), priority

  # Listen for changes
  rootRef.child("#{index.sourcePath}").on "child_changed", updateTags("child_changed")
  rootRef.child("#{index.sourcePath}").on "child_added", updateTags("child_added")
  rootRef.child("#{index.sourcePath}").on "child_removed", updateTags("child_removed")
Handlers.permalink = (rootRef, index) ->
  updatePermalink = (event) ->
    (currentSnap) ->

      id = currentSnap.name()

      # Get previous version of element
      previousPath = "previous/#{index.sourcePath}/#{id}/#{index.sourceAttribute}"
      rootRef.child(previousPath).once "value", (prevSnap) ->

        

        permalink = currentSnap.child(index.sourceAttribute).val()
        redirect = index.getRedirect(currentSnap)

        if permalink != prevSnap.val()
          rootRef.child(index.indexPath+"/"+prevSnap.val()).set(null)
        
        if event == "child_removed" or permalink == null
          return

        rootRef.child("#{index.indexPath}/#{permalink}").set redirect
        
        # Save previous version, with priority
        rootRef.child(previousPath).set currentSnap.child(index.sourceAttribute).val()

  # Listen for changes
  rootRef.child("#{index.sourcePath}").on "child_changed", updatePermalink("child_changed")
  rootRef.child("#{index.sourcePath}").on "child_added", updatePermalink("child_added")
  rootRef.child("#{index.sourcePath}").on "child_removed", updatePermalink("child_removed")
Handlers.derivedPriority = (rootRef, index, uid) ->
  updatePriority = (event) ->
    (currentSnap) ->
      id = currentSnap.name()
      console.log "checking priority"
      priority = index.priority?(currentSnap)
      if priority != currentSnap.getPriority()
        console.log "set priority #{priority}"
        currentSnap.ref().setPriority priority
        

  # Listen for changes
  rootRef.child("#{index.sourcePath}").on "child_changed", updatePriority("child_changed")
  rootRef.child("#{index.sourcePath}").on "child_added", updatePriority("child_added")