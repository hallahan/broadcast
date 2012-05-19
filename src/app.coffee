# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the entry point into the application that server.js loads.
# This is where we do NodeJS Express specific operations, specifically
# the routes and setting up sessions and socket.io


# Constants
PORT = 3002


# Requirements
express = require 'express'
sio     = require 'socket.io'
model   = require './model'


# Configuration
app = module.exports = express.createServer()
app.configure ->
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  # We want a cookie to be valid forever.
  app.use express.session({ secret: 'Zimbabwe', cookie: { maxAge: Infinity }})
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', ->
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', ->
  app.use express.errorHandler()


# Start socket.io
io = sio.listen app


# Start the model.
model.start io


# Should be called any time we get something from a user with socket.io
activity = (broadcast) ->
  broadcast.time = model.userActivity broadcast.uid


# socket.io listeners
io.sockets.on 'connection', (socket) ->
  socket.on 'client-keyup', (broadcast) ->
    activity broadcast
    socket.broadcast.emit 'server-keyup', broadcast  # broadcast emits to everyone but sender
  socket.on 'client-enter', (broadcast) ->
    activity broadcast 
    socket.broadcast.emit 'log', model.log broadcast 




# Checks if the requester has a valid session.
auth = (req, res, next) ->
  if req.session?.auth
    next()
  else
    res.redirect('/login.html')


# Routes
app.get '/', (req, res) ->
  res.sendfile('/index.html')


app.post '/login', (req, res) ->
  if req.body.name or req.body.email
    req.session.auth = true
    req.session.user = model.login req.body.name, req.body.email, req.sessionID
    res.redirect '/'


app.get '/logout', (req, res) ->
  if req.session.user
    req.session.destroy()
  res.redirect '/'


# Save to disk and show what was saved.
app.get '/save', (req, res) ->
  res.end model.save()


# Start application.
app.listen PORT, ->
  console.log "Broadcast server listening on port %d in %s mode", app.address().port, app.settings.env
