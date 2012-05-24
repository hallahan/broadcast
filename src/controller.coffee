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


# Recieve all of the events broadcast from server
listen = ->
  socket.on 'server-test', (data) ->
    console.log 'server-test: ' + data

  socket.on 'needs-login', (nothing) ->
    console.log 'needs-login'
    view.login()

  socket.on 'bad-login', (nothing) ->
    console.log 'bad-login'
    view.loginFailed()

  socket.on 'server-keyup', (payload) ->
    console.log ['server-keyup', payload]

  socket.on 'server-log', (payload) ->
    console.log ['server-log', payload]

  socket.on 'iam', (uid) ->
    console.log ['iam', uid]
    model.iam = uid
    view.textArea()


login = (predicate) ->
  switch predicate
    when 'on'
      console.log 'login view'
    when 'off'
      console.log 'login view'
    when 'bad'
      console.log 'login failed'

