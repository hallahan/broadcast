# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# These are utility functions used both by
# the server and the client.

util = {}

# RETURNS seconds since epoch
util.now = ->
  new Date().getTime()


util.todayStr = ->
  new Date().toDateString()


util.dateStr = (time) ->
  new Date(time).toDateString()


util.timeStr = (time) ->
  d = new Date(time)
  h = d.getHours()
  m = d.getMinutes()
  s = d.getSeconds()
  mer = 'AM'
  if h > 11
    h %= 12
    mer = 'PM' 
  m = '0' + m if m < 10
  s = '0' + s if s < 10
  "#{h}:#{m}:#{s} #{mer}"


if module?.exports?
  module.exports = util
else
  return util