# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the entry point into the application that server.js loads.
# This is where we do NodeJS Express specific operations, specifically
# the routes and setting up sessions and socket.io


# Constants
PORT = 1986
PUBLIC = __dirname + '/../public'

# Requirements
express     = require 'express'
sio         = require 'socket.io'
model       = require './model'
util        = require './util'

# Session Memory Store
sessionStore = new express.session.MemoryStore()

# Is there a better way to get a hold of this function?
parseCookie = require('../node_modules/express/node_modules/connect/lib/utils.js').parseCookie

# Possible fix for MemoryStore's memory leak.
# It leaks because when a session is destroyed, the
# session is deleted, but the sessionStore hash then
# points to null. So, it leaks by having a bunch of
# hashes in the table pointing to null.

# setInterval cleanMemory, 86400000 # 24 hrs
# cleanMemory = -> 
#   process.nextTick -> # keeps it async
#     clean = {}
#     dirty = sessionStore.sessions
#     for session, sid in dirty
#       clean[sid] = session
#     sessionStore.sessions = clean
#     delete dirty


# Configuration
app = module.exports = express.createServer()
app.configure ->
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  app.use express.session
    key: 'sid'
    store: sessionStore
    secret: 'Zimbabwe'
    cookie: { maxAge: Infinity } # cookie valid forever
  app.use app.router
  app.use express.static(PUBLIC)

app.configure 'development', ->
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', ->
  app.use express.errorHandler()


# Start socket.io
io = sio.listen app


io.set 'authorization', (data, accept) ->
  if data.headers.cookie
    data.cookie = parseCookie data.headers.cookie
    data.sid = data.cookie['sid']
    sessionStore.load data.sid, (err, session) ->
      if err or !session
        accept 'Error or no session', false
      else
        data.session = session
        accept null, true
  else
    accept 'No cookie transmitted.', false


# Start the model. Model needs access to socket.io instance.
model.start io


# socket.io setup
io.sockets.on 'connection', (socket) ->

  # Session object for specific client
  sesh = socket.handshake.session

  # Session ID for specific client
  sesh.sid = sid = socket.handshake.sid

  # finds the user in the model if there is a uid
  user = model.socketConnect(sesh)


  # event sent by client on every key-up
  # relays broadcast message, but does not record it
  socket.on 'client-keyup', (broadcast) ->
    if user
      broadcast.time = user.activity()
      broadcast.uid = sesh.uid
      socket.broadcast.emit 'server-keyup', broadcast  # broadcast emits to everyone but sender
    else # we want to have identity associated with all clients
      socket.emit 'needs-login', null


  # records broadcast message to the data model
  socket.on 'client-enter', (broadcast) ->
    if user
      broadcast.time = user.activity()
      broadcast.uid = sesh.uid
      socket.broadcast.emit 'server-log', model.logBroadcast broadcast 
    else
      socket.emit 'needs-login', null


  # log-in credentials that make or retrieve a user from model
  socket.on 'login', (login) ->
    if login.name or login.email
      user = model.login login.name, login.email
      sesh.reload ->
        sesh.uid = user.uid # session knows what user it is
        sesh.save()
    else
      socket.emit 'bad-login', null

  
  socket.on 'logout', (logout) ->
    sesh.destroy() # deletes session from sessionStore
    model.logout session

  # Tell model about client disconnecting (to make user inactive)
  socket.on 'disconnect', ->
    model.socketDisconnect(sesh)


  socket.on 'client-test', (data) ->
    console.log data
    socket.emit 'server-test', 'hello' + util.timeStr(util.now())


# Checks if the requester has a valid session.
auth = (req, res, next) ->
  if req.session?.uid
    next()
  else
    res.redirect('/')


# Routes
app.get '/', (req, res) ->
  res.sendfile('/index.html')


app.get '/data', (req, res) ->
  res.end model.data()


# Save to disk and show what was saved.
app.get '/save', (req, res) ->
  res.end model.save()


# Start application.
app.listen PORT, ->
  console.log "Broadcast server listening on port %d in %s mode", app.address().port, app.settings.env
