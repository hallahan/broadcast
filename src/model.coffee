# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the in-memory model that persists to disk all of the broadcasts
# that are entered. It does not deal with broadcasts as they are being 
# typed, only the ones where the user pressed enter. This module also
# manages the users and their sessions.


# Constants
LAST_LOG_PATH   = "#{__dirname}/../data/last-log.json" # determines which saved log is loaded.

# Requirements
util  = require('./util')
# test  = require('../test/test-model')
fs    = require('fs') #file system


# In-memory data structures.
log       = []
users     = []
loadTimes = []
saveTimes = []


# not saved to disk
activeUsers = [] 
savedLen    = 0 # the length of the log at the last save
io          = {} #socket.io instance that we get from express app


class User
  constructor: (@name, @email) ->
    @uid = users.length

  # Updates the last point in time a user did something.
  # RETURNS the time of the activity, i.e. now.
  activity: ->
    t = util.now()
    @lastActivity = t
    if @active is false
      @active = true
      activeUsers.push @uid 
    t

  loginTimes: []
  socketLoginTimes: []


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
    logPath = "#{__dirname}/../data/#{lastLog}.json"
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
  data = JSON.stringify { log, users, loadTimes, saveTimes }, null, 2
  fs.writeFile "#{__dirname}/../data/#{saveTimes.length}.json", data, (err) ->
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
login = (name, email, sessionId) ->
  user = u if u.name is name and u.email is email for u in users
  users.push(user = new User(name, email)) if !user
  user.loginTimes.push user.activity() #activity returns now
  user


# Fetches and logs user associated with the session
# of the socket.
socketLogin = (session) ->
  user = users[session.uid?]
  if user?
    user.socketLoginTimes.push user.activity()
    user
  else
    null


# Goes through all of the active users and checks
# if they are still active. 
# RETURNS the active users.
checkActivity = ->
  for uid, idx in activeUsers
    if t - users[uid].lastActivity > 10000
      io.sockets.emit('inactive', user.uid)
      user.active = false
      activeUsers.splice idx, 1
  activeUsers


# Adds a broadcast to the log.
logBroadcast = (broadcast) ->
  broadcast.lid = log.length
  broadcast.user = users[broadcast.lid]
  log.push broadcast
  broadcast


# This gives data that will be exposed to the client.
data = ->
  JSON.stringify {users, activeUsers, log}, null, 2


loadTestData = (testData) ->
  users = testData.users
  log = testData.log


# Exports
exports.users         = users
exports.start         = start
exports.save          = save
exports.login         = login
exports.checkActivity = checkActivity
exports.logBroadcast  = logBroadcast
exports.data          = data
exports.socketLogin   = socketLogin