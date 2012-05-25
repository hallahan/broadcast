# Broadcast.TheOutpost.io
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


# Not used, but availible for controlling standard http requests.
io.set 'authorization', (data, accept) ->
  if data.headers.cookie
    data.cookie = parseCookie data.headers.cookie
    data.sid = data.cookie['sid']
    sessionStore.load data.sid, (err, session) ->
      if err or !session
        accept 'No Session', false
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
  sid = socket.handshake.sid

  # finds the user in the model if there is a uid in sesh, broadcasts user activity
  uid = model.socketConnect(sesh)


  # event sent by client on every key-up
  # relays broadcast message, but does not record it
  socket.on 'client-keyup', (broadcast) ->
    console.log 'client-keyup', broadcast
    if uid?
      broadcast.time = model.userActivity(sesh.ip, uid)
      broadcast.uid = uid
      socket.broadcast.emit 'server-keyup', broadcast  # broadcast emits to everyone but sender
    else # we want to have identity associated with all clients
      socket.emit 'needs-login', null


  # records broadcast message to the data model
  socket.on 'client-enter', (broadcast) ->
    if uid?
      broadcast.time = model.userActivity(sesh.ip, uid)
      broadcast.uid = uid
      io.sockets.emit 'server-enter', model.logBroadcast broadcast 
    else
      socket.emit 'needs-login', null


  # log-in credentials that make or retrieve a user from model
  socket.on 'login', (login) ->
    if login.name or login.email
      uid = model.login sesh, login.name, login.email
      sesh.reload ->
        sesh.uid = uid # session now knows what user it is
        sesh.save()
      socket.emit 'iam', uid
    else
      socket.emit 'bad-login', null

  
  # destroys session, model makes user inactive, broadcast inactivity
  socket.on 'logout', (logout) ->
    model.logout sesh
    sesh.destroy() # deletes session from sessionStore


  # model deems user inactive and broadcasts inactive user
  socket.on 'disconnect', ->
    model.socketDisconnect sesh


  # says hello
  socket.on 'client-test', (data) ->
    console.log data
    socket.emit 'server-test', 'hi ' + util.timeStr(util.now())


# Checks if the requester has a valid session. 
# To be used as http route middleware.
auth = (req, res, next) ->
  if req.session?.uid?
    next()
  else
    res.redirect('/')


# Routes
app.get '/', (req, res) ->
  req.session.ip = req.connection.remoteAddress
  res.sendfile('/index.html')


# The data that is exposed to the client in http request.
app.get '/data', (req, res) ->
  req.session?.ip = req.connection.remoteAddress
  data = model.data()
  if uid = req.session?.uid?
    data.iam = uid
  else
    data.iam = null
  res.end JSON.stringify data, null, 2


# Save to disk and show what was saved.
app.get '/save', (req, res) ->
  req.session.ip = req.connection.remoteAddress
  res.end model.save()


# Start application.
app.listen PORT, ->
  console.log "Broadcast server listening on port %d in %s mode", app.address().port, app.settings.env





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
