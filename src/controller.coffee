# Broadcast.TheOutpost.io
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the code for the controller which resides
# client side.


util    = broadcast.util
view    = broadcast.view
socket  = broadcast.socket

# pack with data structures for the controller to use
broadcast.model = model = {}
textAreaActive = false


#Get initial data from server.
$.getJSON '/data', (data) ->

  # Make data availible in the client model.
  model = data

  # Populate views with data
  view.online(determineActiveUsers())
  view.broadcasts(data.log, data.users)

  # Allow real-time activity via socket.io
  live()


# socket.io functionality
# We only want to initiate a connection once we have
# gotten our initial data from the data http response.
live = ->
  # Good to give this to broadcast so we can talk in console.
  broadcast.socket = socket = io.connect()
  socket.emit 'client-test', "hi: #{util.timeStr util.now()}"
  listen()


  # Listen to text area to broadcast glowing text.
  $('#broadcast-text-area').bind 'keyup click', textAreaEventHandler


# Recieve all of the events broadcast from server
listen = ->

  socket.on 'server-test', (data) ->
    console.log 'server-test: ' + data


  socket.on 'needs-login', (nothing) ->
    console.log 'needs-login'
    view.login()
    $('#broadcast-name').keyup(loginFormEventHandler)
    $('#broadcast-email').keyup(loginFormEventHandler)


  socket.on 'bad-login', (nothing) ->
    console.log 'bad-login'
    view.loginFailed()


  socket.on 'server-keyup', (broadcast) ->
    console.log ['server-keyup', broadcast]
    broadcastKeyup broadcast


  # broadcast was recorded on the server's log
  socket.on 'server-enter', (broadcast) ->
    console.log ['server-enter', broadcast]
    broadcastEnter broadcast


  # for when the user presses enter and there is no text in
  # the text area
  socket.on 'server-delete', (broadcast) ->
    console.log 'todo delete'


  # the user id of the client, null if not logged in
  socket.on 'iam', (uid) ->
    console.log ['iam', uid]
    model.iam = uid
    view.textArea()
    $('#broadcast-text-area').bind 'keyup click', textAreaEventHandler

    # TODO: Indicate which user I am in Online List.


  # some user has become active
  socket.on 'active', (uid) ->
    console.log ['active', uid]
    user = model.users[uid]
    if user.active is false
      user.active = true
      view.userOnline(user)


  # some user has become inactive
  socket.on 'inactive', (uid) ->
    console.log ['inactive', uid]
    user = model.users[uid]
    user.active = false
    view.userOffline(user)
    

  # There is a new user. Another signal of it being
  # active should come this way via 'active'
  socket.on 'new-user', (user) ->
    console.log ['new-user', user]
    model.users[user.uid] = user


determineActiveUsers = () ->
  activeUsers = []
  for user in model.users
    if user.active is true
      activeUsers.push user
  # sort users by most recent activity
  activeUsers.sort (a, b) ->
    b.lastActivity - a.lastActivity


broadcastKeyup = (broadcast) ->
  bid = 'b'+broadcast.uid
  if !document.getElementById bid
    if textAreaActive
      view.createBroadcast 'input-active', model.users[broadcast.uid], broadcast
    else
      view.createBroadcast 'input-inactive', model.users[broadcast.uid], broadcast
  else
    glow broadcast


broadcastEnter = (broadcast) ->
  broadcastKeyup broadcast
  $('#'+broadcast.uid).removeAttr 'id'


textAreaEventHandler = (event) ->
  textAreaActive = true
  text = $('#broadcast-text-area').val()
  broadcast =
    uid  : model.iam
    text : text
    pos  : getSelectionPos('broadcast-text-area')
  if event.which == 13 # enter key
    # Get rid of the '\n' at the end.
    broadcast.text = text.substring(0,text.length-1)
    $('#input-active').removeAttr('id')
    $('#input-inactive').removeAttr('id')
    input = $('#broadcast-input')
    input.prependTo('#broadcast-today')
    input.before """<div id="input-active"></div>"""
    input.after  """<div id="input-inactive"></div>"""
    $('#broadcast-text-area').val('').focus()
    textAreaActive = false
    socket.emit 'client-enter', broadcast
  socket.emit 'client-keyup', broadcast


loginFormEventHandler = (event) ->
  if event.which == 13 # enter key
    name = $('#broadcast-name').val()
    email = $('#broadcast-email').val()
    if name?.length > 0 or email?.length > 0
      socket.emit 'login', {name, email}
    else
      view.loginFailed()


# If the start and the end are the same, that is the caret position.
# This is dealing with the text area  you typing in, not the text
# other users are typing.
getSelectionPos = (id) -> 
  el = document.getElementById id
  if document.selection # IE
    el.focus()
    sel = document.selection.createRange()
    sel.moveStart 'character', -el.value.length
    iePos = sel.text.length
    {start: iePos, end: iePos}
  else
    {start: el.selectionStart, end: el.selectionEnd}


# Animiation is applied to a specific glow element,
# so it's identity needs to be unique.
glowId = 0 

# This is dealing with the text that other users are typing.
glow = (broadcast) ->
  text = broadcast.text
  selStart = broadcast.pos.start
  selEnd = broadcast.pos.end
  if selStart == selEnd # just caret position, no selected text
    newCharIdx = selStart-1
    beforeText = text.slice(0,newCharIdx)
    glowText = text[newCharIdx]
    afterText = text.slice(selEnd)
  else # there is selected text
    beforeText = text.slice(0,selStart)
    glowText = text.slice(selStart,selEnd)
    afterText = text.slice(selEnd)

  # apply to view
  html = """#{beforeText}<span class="glow" id="g#{glowId}">#{glowText}</span>#{afterText}"""
  $('#btime'+broadcast.uid).html util.timeStr(broadcast.time) # time element
  $('#btext'+broadcast.uid).html html # glowing text

  # animate
  $('#g'+glowId).removeClass 'glow', 1000 # 1 second

  glowId++
