# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the in-memory model that persists to disk all of the broadcasts
# that are entered. It does not deal with broadcasts as they are being 
# typed, only the ones where the user pressed enter. This module also
# manages the users and their sessions.


# Paths
projDir = __dirname.split('/')
projDir.pop()
PROJ_DIR = projDir.join('/')
LAST_LOG_PATH = PROJ_DIR + '/data/last-log.json' # determines which saved log is loaded


# Requirements
util  = require('./util')
# test  = require('../test/test-model')
fs    = require('fs') #file system


# In-memory data structures.
log       = []
users     = []
loadTimes = []
saveTimes = []
anon      = [] 


# not saved to disk
activeUsers = [] 
savedLen    = 0 # the length of the log at the last save
io          = {} #socket.io instance that we get from express app


class User
  constructor: (@name, @email) ->
    @uid = users.length
    @active = false
    @lastActivity = 0
    @loginTimes = []
    @logoutTimes = []
    @socketConnectTimes = []
    @socketDisconnectTimes = []

  # Updates the last point in time a user did something.
  # RETURNS the time of the activity, i.e. now.
  activity: ->
    t = util.now()
    @lastActivity = t
    @active = true
    t

  login: ->
    @loginTimes.push this.activity()

  logout: ->
    @logoutTimes.push util.now()
    @active = false

  socketConnect:->
    @socketConnectTimes.push this.activity()

  socketDisconnect: ->
    @socketDisconnectTimes.push util.now()
    @active = false


# Starts the model and sets up intervals that check for user activity
# as well as periodically save memory to disk. Requires the instance
# of socket.io used in the Express App.
start = (sio) ->
  io = sio
  load()
  
  # loadTestData(test)

  setInterval checkActivity, 10000    # 10 secs
  setInterval considerSaving, 600000  # 10 mins


# PRIVATE
# Loads into memory the log that is specified in 'last-log.json'.
load = ->
  loadTimes.push util.now()
  try
    lastLog = JSON.parse fs.readFileSync LAST_LOG_PATH, "utf8"
    logPath = "#{PROJ_DIR}/data/#{lastLog}.json"
    savedData = JSON.parse fs.readFileSync logPath, "utf8"
    log = savedData.log
    users = savedData.users
    loadTimes = savedData.loadTimes
    saveTimes = savedData.saveTimes
  catch e
    console.log "saved data not loaded"


# Saves to disk the current state in memory. The name is the total number
# of logs previously saved + 1.
# RETURNS data as a string
save = ->
  saveTimes.push util.now()
  data = JSON.stringify { log, users, loadTimes, saveTimes, anon }, null, 2
  fs.writeFile "#{PROJ_DIR}/data/#{saveTimes.length}.json", data, (err) ->
    console.log 'unable to save memory to disk: '+err if err
  fs.writeFile LAST_LOG_PATH, JSON.stringify(saveTimes.length), (err) ->
    console.log 'unable to save last log number to disk: '+err if err
  savedLen = log.length
  data


# If the log has not changed state, there is no reason to save again
# when the timer suggests saving to disk.
considerSaving = ->
  if log.length > savedLen
    save()


# Logs a user in or creates a user if that name/email
# combo does not yet exist.
login = (name, email) ->
  user = u if u.name is name and u.email is email for u in users
  users.push(user = new User(name, email)) if !user
  user.login()
  user


logout = (session) ->
  if session.uid?
    user = users[session.uid]
    user.logout()
    io.sockets.emit('inactive', user.uid)


# Fetches and logs user associated with the session
# of the socket.
socketConnect = (session) ->
  if session.uid?
    user = users[session.uid]
    user.socketConnect()
    io.sockets.emit('active', user.uid)
  else 
    anon.push
      sid: session.sid
      time: util.now()
      type: 'socketConnect'
    null


socketDisconnect = (session) ->
  if session.uid?
    user = users[session.uid]
    user.socketDisconnect()
    io.sockets.emit('inactive', user.uid)
  else
    anon.push
      sid: session.sid
      time: util.now()
      type: 'socketDisconnect'


# Goes through all of the users and checks
# if they are still active. 
checkActivity = ->
  t = util.now()
  for user in users
    if t - user.lastActivity > 60000 # 1 min
      io.sockets.emit('inactive', user.uid)
      user.active = false


# Adds a broadcast to the log.
logBroadcast = (broadcast) ->
  broadcast.lid = log.length
  log.push broadcast
  broadcast


# This gives data that will be exposed to the client.
data = ->
  JSON.stringify {users, activeUsers, log}, null, 2


loadTestData = (testData) ->
  users = testData.users
  log = testData.log


# Exports
exports.users             = users
exports.start             = start
exports.save              = save
exports.login             = login
exports.logout            = logout
exports.checkActivity     = checkActivity
exports.logBroadcast      = logBroadcast
exports.data              = data
exports.socketConnect     = socketConnect
exports.socketDisconnect  = socketDisconnect