# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the in-memory model that persists to disk all of the broadcasts
# that are entered. It does not deal with broadcasts as they are being 
# typed, only the ones where the user pressed enter. This module also
# manages the users and their sessions.


# Constants
LAST_LOG_PATH = "#{__dirname}/data/last-log.json" # determines which saved log is loaded.
LOG_PATH = "#{__dirname}/data/#{lastLogPath}.json"


# Requirements
fs = require('fs') #file system


# In-memory data structures.
log = []
users = []
loadTimes = []
saveTimes = []
activeUsers = [] # not saved to disk


# Loads into memory the log that is specified in 'last-log.json'.
load = ->
  loadTimes push now()
  try
    lastLog = JSON.parse fs.readFileSync LAST_LOG_PATH, "utf8"
    [log, users, loadTimes, saveTimes] = JSON.parse fs.readFileSync LOG_PATH, "utf8"
  catch e
    console.log "saved data not loaded"


# Saves to disk the current state in memory. The name is the total number
# of logs previously saved + 1.
# RETURNS data as a string
save = -> 
  data = JSON.stringify { log, users, loadTimes, saveTimes: saveTimes.push now() }
  fs.writeFile "#{__dirname}/data/#{saveTimes.length}.json", data, (err) ->
    console.log 'unable to save memory to disk: '+err if err
  fs.writeFile LAST_LOG_PATH, JSON.stringify(saveTimes.length), (err) ->
    console.log 'unable to save last log number to disk: '+err if err
  data


# Logs a user in or creates a user if that name/email
# combo does not yet exist.
login = (name, email, sessionId) ->
  user = u if u.name is name and u.email is email for u in users
  users.push user = { id: users.length, name, email } if !user
  userActivity(user.id)
  user.sessionId = sessionId
  user.loginTimes.push userActivity(user.id) #userActivity returns now
  user


# Goes through all of the active users and checks
# if they are still active.
activeUsers = ->
  activeUsers = activeUsers.filter isActive


# PRIVATE
# User is active only if the last activity happened less than 10 seconds ago.
isActive = (uid, index, array) ->
  if now() - users[uid].lastActivity < 10000
    true
  else
    io.sockets.emit('inactive', uid)
    users[uid].active = false


# Updates the last point in time a user did something.
# RETURNS the time of the activity, i.e. now.
userActivity = (uid) ->
  t = now()
  if u = users[uid]
    u.lastActivity = t
    if u.active is false
      u.active = true
      activeUsers.push uid 
  t


# Adds a broadcast to the log.
log = (broadcast) ->
  broadcast.time = now()
  log.push broadcast
  io.sockets.emit('log', broadcast)
  broadcast

# UTILITY FUNCTION
# RETURNS seconds since epoch
now = ->
  new Date().getTime()


# Exports
exports.load = load
exports.save = save
exports.login = login
exports.activeUsers = activeUsers
exports.userActivity = userActivity
exports.log = log