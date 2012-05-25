# Broadcast.TheOutpost.io
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# These are utility functions used both by
# the server and the client. The util object
# is declared in index.html.

# RETURNS seconds since epoch
now = ->
  new Date().getTime()


todayStr = ->
  new Date().toDateString()


dateStr = (time) ->
  new Date(time).toDateString()


timeStr = (time) ->
  d = new Date(time)
  h = d.getHours()
  m = d.getMinutes()
  s = d.getSeconds()
  mer = 'AM'
  if h > 11
    h %= 12
    mer = 'PM'
  if h is 0 then h=12
  m = '0' + m if m < 10
  s = '0' + s if s < 10
  "#{h}:#{m}:#{s} #{mer}"


isToday = (time) ->
  today = new Date().toDateString()
  predicate = new Date(time).toDateString()
  today == predicate


isSameDate = (time1, time2) ->
  date1 = new Date(time1).toDateString()
  date2 = new Date(time2).toDateString()
  date1 == date2


emptyStr = ''


if module?.exports?
  module.exports = {now, todayStr, dateStr, timeStr, isToday, isSameDate, emptyStr}
else
  broadcast.util = {now, todayStr, dateStr, timeStr, isToday, isSameDate, emptyStr}
