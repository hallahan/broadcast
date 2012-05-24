# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the code for the controller which resides
# client side.


util    = broadcast.util
view    = broadcast.view
socket  = broadcast.socket

# pack with data structures for the controller to use
broadcast.model = model = {}


#Get initial data from server.
$.getJSON '/data', (data) ->
  # Make data availible in the model.
  model = data

  if model.iam?
    needsLogin = false

  # Populate views with data
  view.online(data.users)
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
  $('#broadcast-text-area').bind 'keyup click', ->
      text = $('#broadcast-text-area').val()
      pos = getSelectionPos('broadcast-text-area')
      socket.emit 'client-keyup', {text, pos}
      

loginFormEventHandler = (event) ->
  if event.which == 13
    name = $('#broadcast-name').val()
    email = $('#broadcast-email').val()
    if name?.length > 0 or email?.length > 0
      socket.emit 'login', {name, email}
    else
      view.loginFailed()


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

  socket.on 'server-keyup', (payload) ->
    console.log ['server-keyup', payload]
    pos = payload.pos
    text = payload.text
    if pos.start == pos.end # no selection, just caret
        console.log 'no selection, just caret'
    else # selection
      console.log 'there is a selection'

  socket.on 'server-log', (payload) ->
    console.log ['server-log', payload]

  socket.on 'iam', (uid) ->
    console.log ['iam', uid]
    model.iam = uid
    view.textArea()

  socket.on 'active', (uid) ->
    console.log ['active', uid]

  socket.on 'active', (uid) ->
    console.log ['active', uid]
    
  socket.on 'new-user', (user) ->
    console.log ['new-user', user]  


login = (predicate) ->
  switch predicate
    when 'on'
      console.log 'login view'
    when 'off'
      console.log 'login view'
    when 'bad'
      console.log 'login failed'


# if the start and the end are the same, that is the caret position
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

