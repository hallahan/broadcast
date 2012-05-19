# UTILITY FUNCTIONS

if !util
  util = {}
  exports.now       = now
  exports.todayStr  = todayStr
  exports.dateStr   = dateStr
  exports.timeStr   = timeStr


# RETURNS seconds since epoch
util.now = ->
  new Date().getTime()


util.todayStr = ->
  d = new Date() # now
  wk = d.getDay().toString().slice(0,3)
  mo = d.getMonth().toString().slice(0,3)
  dy = d.getDate()
  yr = d.getFullYear()
  "#{wk} #{mo} #{dy} #{yr}"


util.dateStr = (time) ->
  d = new Date(time)
  wk = d.getDay().toString().slice(0,3)
  mo = d.getMonth().toString().slice(0,3)
  dy = d.getDate()
  yr = d.getFullYear()
  "#{wk} #{mo} #{dy} #{yr}"


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
