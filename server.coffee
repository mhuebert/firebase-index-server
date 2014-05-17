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

module.exports = IndexServer = (options) ->
  
  # connect to Firebase
  {FIREBASE_URL, index} = options
  rootRef = new Firebase(FIREBASE_URL)

  blankSnapshot =
    val: -> {}
    child: -> blankSnapshot
    getPriority: -> null

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
          console.log "Priority changed"
          newTagList = currentTags

        # Update indexes
        for tag in newTagList
          rootRef.child("#{index.indexPath}/#{tag}/#{id}").setWithPriority true, priority
        for tag in removedTagList
          rootRef.child("#{index.indexPath}/#{tag}/#{id}").set null
        
        # Save previous version, with priority
        rootRef.child(previousPath).setWithPriority currentSnap.child(index.sourceAttribute).val(), priority


  # Listen for changes
  rootRef.child("#{index.sourcePath}").on "child_changed", updateTags("child_changed")
  rootRef.child("#{index.sourcePath}").on "child_added", updateTags("child_added")
  rootRef.child("#{index.sourcePath}").on "child_removed", updateTags("child_removed")