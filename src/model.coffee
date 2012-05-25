# Broadcast.TheOutpost.io
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
sidToUid  = {} # hash sid, get uid


# not saved to disk
activeUsers = [] 
savedLen    = 0 # the length of the log at the last save
io          = {} #socket.io instance that we get from express app


class User
  constructor: (@name, @email) ->
    @uid = users.length
    @active = false
    @lastActivity = 0
    @ip = 0
    @logins = []
    @logouts = []
    @socketConnects = []
    @socketDisconnects = []

  # Converts an array that was deserialized and makes
  # it this class again. Static method.
  @proselytize: (array) ->
    faithful = []
    for heathen in array
      kin = new User(heathen.name, heathen.email)
      kin.active = false # when the server starts, we don't want to have anyone be active
      for key in Object.keys(heathen)
        kin[key] = heathen[key]
      faithful.push kin
    faithful

  # Updates the last point in time a user did something.
  # RETURNS the time of the activity, i.e. now.
  activity: (ip) ->
    @ip = ip
    t = util.now()
    @lastActivity = t
    if @active == false
      @active = true
      io.sockets.emit 'active', @uid
    t

  login: (ip) ->
    @logins.push 
      ip: ip
      time: this.activity()

  logout: (ip) ->
    @logouts.push 
      ip: ip
      time: util.now()
    @active = false

  socketConnect: (ip) ->
    @socketConnects.push 
      ip: ip
      time: this.activity()

  socketDisconnect: (ip) ->
    @socketDisconnects.push 
      ip: ip
      time: util.now()
    @active = false


# expose user.activity's functionality to app
userActivity = (ip, uid) ->
  u = users[uid]
  if u?
    u.activity(ip)


# Starts the model and sets up intervals that check for user activity
# as well as periodically save memory to disk. Requires the instance
# of socket.io used in the Express App.
start = (sio) ->
  io = sio
  load()
  # loadTestData(test)
  setInterval checkActivity, 7000     # 7 secs
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
    users = User.proselytize savedData.users
    loadTimes = savedData.loadTimes
    saveTimes = savedData.saveTimes
    anon = savedData.anon
  catch e
    console.log "saved data not loaded"


# Saves to disk the current state in memory. The name is the total number
# of logs previously saved + 1.
# RETURNS data as a string
save = ->
  saveTimes.push util.now()
  data = JSON.stringify { log, users, loadTimes, saveTimes, anon, sidToUid }, null, 2
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
login = (session, name, email) ->
  for u in users
    if u.name is name and u.email is email
      user = u
      break
  if !user
    users.push(user = new User(name, email))
    io.sockets.emit 'new-user', user
  user.login session.ip
  sidToUid[session.id] = user.uid
  user.uid


logout = (session) ->
  if uid = sidToUid[session.id]?
    user = users[uid]
    user.logout session.ip
    io.sockets.emit 'inactive', user.uid
    sidToUid[session.id] = null
    user.uid
  else
    null


# Fetches and logs user associated with the session
# of the socket.
socketConnect = (session) ->
  uid = sidToUid[session.id]
  if uid?
    user = users[uid]
    if user?
      user.socketConnect(session.ip)
      user.uid
    else
      null
  else 
    anon.push
      sid: session.id
      ip: session.ip
      time: util.now()
      type: 'socketConnect'
    null


socketDisconnect = (session) ->
  if uid = sidToUid[session.id]?
    user = users[uid]
    if user?
      user.socketDisconnect(session.ip)
      io.sockets.emit('inactive', user.uid)
      user.uid
    else
      null
  else
    anon.push
      sid: session.sid
      ip: session.ip
      time: util.now()
      type: 'socketDisconnect'
    null


# Goes through all of the users and checks
# if they are still active. 
checkActivity = ->
  t = util.now()
  for user in users
    if user.active is true and t - user.lastActivity > 7000 # 7 secs
      io.sockets.emit('inactive', user.uid)
      user.active = false


# Adds a broadcast to the log.
logBroadcast = (broadcast) ->
  broadcast.lid = log.length
  log.push broadcast
  broadcast


# This gives data that will be exposed to the client.
data = ->
  {users, log}


# only for testing
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
exports.userActivity      = userActivity