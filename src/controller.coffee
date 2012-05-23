# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the code for the controller which resides
# client side.

view = broadcast.view
socket = io.connect()

#Get initial data from server.
$.getJSON '/data', (data) ->

  # Populate views with data
  view.online(broadcast.test.users)
  view.broadcasts(broadcast.test.log, broadcast.test.users)

socket.emit 'client-test', 'hello from client'

socket.on 'server-test', (data) ->
	console.log 'data from server: ' + data