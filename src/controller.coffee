# Broadcast.TheOutpost.io
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the code for the controller which executes
# client side.


utility = require './utility'
view    = require './view'
url     = 'http://localhost:1986'
socket  = {}

# Pack with data structures for the controller to use.
# This is not synchronized with the model on the server.
# it is just a data structure for use by the individual
# client.
model = {}

textAreaActive = false


# No callback is needed, because everything else will load
# fine if this library isn't here yet.
$.getScript "#{url}/lib/bootstrap/js/bootstrap-collapse.js"
$.getScript "#{url}/lib/jquery-ui-1.8.20.custom.min.js"

# Get Socket.io libraries, jQuery puts that in the global namespace.
$.getScript "#{url}/socket.io/socket.io.js", () ->

  #Get initial data from server.
  $.getJSON "#{url}/data", (data) ->

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
  socket = io.connect(url)
  socket.emit 'client-test', "hi: #{utility.timeStr utility.now()}"
  if model?.iam? then imHere(true)
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
  # This happens after the client successfully logs in.
  # We need a new text area on top of the stack.
  socket.on 'iam', (uid) ->
    console.log ['iam', uid]
    model.iam = uid
    imHere(true)
    view.textArea() # actually have text area
    freshTextArea() # puts that text area on top
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
    if broadcast.uid is model.iam
      view.createBroadcast 'old', model.users[broadcast.uid], broadcast
      $('#old').replaceWith($('#old').children())
    else if textAreaActive
      view.createBroadcast 'input-active', model.users[broadcast.uid], broadcast
    else
      view.createBroadcast 'input-inactive', model.users[broadcast.uid], broadcast
  else
    glow broadcast


broadcastEnter = (broadcast) ->
  broadcastKeyup broadcast
  $('#b'+broadcast.uid).removeAttr 'id'


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
    freshTextArea()
    socket.emit 'client-enter', broadcast
  else
    socket.emit 'client-keyup', broadcast


freshTextArea = ->
  $('#input-active').replaceWith $('#input-active').children()
  $('#input-inactive').attr('id','old')
  input = $('#broadcast-input')
  input.prependTo('#broadcast-today')
  input.before """<div id="input-active"></div>"""
  input.after  """<div id="input-inactive"></div>"""
  $('#broadcast-text-area').val('').focus()
  textAreaActive = false


loginFormEventHandler = (event) ->
  if event.which == 13 # enter key
    name = $('#broadcast-name').val()
    email = $('#broadcast-email').val()
    if name?.length > 0 or email?.length > 0
      socket.emit 'login', {name, email}
    else
      view.loginFailed()
    textAreaActive = false


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
  newCharIdx = selStart-1
  glowText = text.charAt newCharIdx
  if glowText == '\n' then return
  if selStart == selEnd # just caret position, no selected text
    beforeText = text.slice(0,newCharIdx)
    afterText = text.slice(selEnd)
  else # there is selected text
    beforeText = text.slice(0,selStart)
    glowText = text.slice(selStart,selEnd)
    afterText = text.slice(selEnd)

  # apply to view
  html = """#{beforeText}<span class="glow" id="g#{glowId}">#{glowText}</span>#{afterText}"""
  $('#btime'+broadcast.uid).html utility.timeStr(broadcast.time) # time element
  $('#btext'+broadcast.uid).html html # glowing text

  # animate
  $('#g'+glowId).removeClass 'glow', 1000 # 1 second

  glowId++


# keep telling server of prescence to stay online
alreadyOn = false
intervalId = 0
imHere = (boolean) ->
  if boolean is true and alreadyOn is false
    intervalId = setInterval ->
      console.log """I'm here! ( #{model.iam} )"""
      socket.emit 'here', model.iam
    , 6543
    alreadyOn = true
  else
    clearInterval intervalId
    alreadyOn = false

