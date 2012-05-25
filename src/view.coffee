# Broadcast.TheOutpost.io
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

util = broadcast.util
str = ''
onlineCount = 0

# Online Users Accordion
online = (users) -> 
  str =     """ <div class="accordion-heading">
                  <a class="accordion-toggle" data-toggle="collapse" data-parent="#broadcast-online" href="#broadcast-users">
                    <strong>Online</strong> ( <span id="online">#{onlineCount=users.length}</span> )
                  </a>
                </div>
                <div id="broadcast-users" class="accordion-body collapse in">""" 
  for user in users
    str +=  """   <div data-uid=#{user.uid} class="accordion-inner">
                    <strong>#{user.name||util.emptyStr}</strong>
                    <span class="broadcast-email">#{user.email||util.emptyStr}</span>
                  </div>"""
  str +=    """ </div>"""

  $('#broadcast-online-tmpl').html str


userOnline = (user) ->
  str =     """   <div data-uid=#{user.uid} class="accordion-inner">
                    <strong>#{user.name||util.emptyStr}</strong>
                    <span class="broadcast-email">#{user.email||util.emptyStr}</span>
                  </div>"""

  $('#broadcast-users').prepend str
  $('#online').html ++onlineCount


userOffline = (user) ->
  $("div[data-uid=\"#{user.uid}\"]").remove()
  $('#online').html --onlineCount


newInput = ->
  str = """ <div id="input-active"></div>
            <div id="broadcast-input" class="accordion-inner">
              <textarea id="broadcast-text-area" class="broadcast-text-area" rows="2"></textarea>
            </div>
            <div id="input-inactive"></div>"""
  $('#broadcast-today').prepend str


# Entire log of broadcasts
broadcasts = (log, users) ->
  str =      """<div class="accordion-group">
                  <div class="accordion-heading">
                    <a class="accordion-toggle" data-toggle="collapse" data-parent="#broadcasts" href="#broadcast-today">
                      <strong>#{util.todayStr()}</strong>
                    </a>
                  </div>
                  <div id="broadcast-today" class="accordion-body collapse in">
                    <div id="input-active"></div>
                    <div id="broadcast-input" class="accordion-inner">
                      <textarea id="broadcast-text-area" class="broadcast-text-area" rows="2"></textarea>
                    </div>
                    <div id="input-inactive"></div>"""
  while l = log?.pop()
    if util.isToday l.time
      str += """    <div class="accordion-inner">
                      <strong>#{users[l.uid].name||users[l.uid].email}</strong>
                      <span class="broadcast-time">#{util.timeStr(l.time)}</span>
                      <br/>
                      #{l.text}
                    </div>"""
    else
      str += """  </div>
                </div>"""
      broadcastsPast(log, l, users)
  $('#broadcasts').html str


# This function is used privately to recurse through past days
# in the log. The l parameter is the last log entry that was
# popped from the broadcasts call or the parent call of
# broadcastsPast on the recursion stack.
broadcastsPast = (log, l, users) ->
  str +=     """<div class="accordion-group">
                  <div class="accordion-heading">
                    <a class="accordion-toggle" data-toggle="collapse" data-parent="#broadcasts" href="##{l.time}">
                      <strong>#{util.dateStr l.time}</strong>
                    </a>
                  </div>
                  <div id="#{l.time}" class="accordion-body collapse">
                    <div class="accordion-inner">
                      <strong>#{users[l.uid].name||users[l.uid].email}</strong>
                      <span class="broadcast-time">#{util.timeStr(l.time)}</span>
                      <br/>
                      #{l.text}
                    </div>"""
  while next = log?.pop()
    if util.isSameDate l.time, next.time
      str += """    <div class="accordion-inner">
                      <strong>#{users[next.uid].name||users[next.uid].email}</strong>
                      <span class="broadcast-time">#{util.timeStr(next.time)}</span>
                      <br/>
                      #{next.text}
                    </div>"""
    else
      str += """  </div>
                </div>"""
      broadcastsPast(log, next, users)
  null


login = () ->
  str = """ <form class="form-horizontal">
              <div class="control-group">
                <label class="control-label" for="broadcast-name">Who are you? </label>
                <div class="controls">
                  <input id="broadcast-name" type="text">
                </div>
              </div>
              <div class="control-group">
                <label class="control-label" for="broadcast-email">Email <i>(optional)</i></label>
                <div class="controls">
                  <input id="broadcast-email" type="text">
                </div>
              </div>
            </form>"""
  $('#broadcast-input').html str


loginFailed = () ->
  str = """ <form class="form-horizontal">
              <div class="alert alert-error fade in">
                <button class="close" data-dismiss="alert">&times;</button>
                <strong>Login Failed:</strong><br/>You must enter your name and / or email.
              </div>
              <div class="control-group error">
                <label class="control-label" for="broadcast-name">Who are you? </label>
                <div class="controls">
                  <input id="broadcast-name" type="text">
                </div>
              </div>
              <div class="control-group error">
                <label class="control-label" for="broadcast-email">Email <i>(optional)</i></label>
                <div class="controls">
                  <input id="broadcast-email" type="text">
                </div>
              </div>
            </form>"""
  $('#broadcast-input').html(str)


textArea = () ->
  str = """<textarea id="broadcast-text-area" class="broadcast-text-area" rows="2"></textarea>"""
  $('#broadcast-input').html str


# first knowledge of a specific broadcast from server
createBroadcast = (prependDiv, user, broadcast) ->
  str = """ <div id="b#{broadcast.uid}" class="accordion-inner">
              <strong>#{user.name||user.email}</strong>
              <span id="btime#{broadcast.uid}"class="broadcast-time">#{util.timeStr(broadcast.time)}</span>
              <br/>
              <span id="btext#{broadcast.uid}"class="broadcast-text glow">#{broadcast.text}</span>
            </div>"""
  $('#'+prependDiv).prepend str
  $('#btext'+broadcast.uid).removeClass 'glow', 1000 # 1 second


broadcast.view = 
  online            : online
  userOnline        : userOnline
  userOffline       : userOffline
  broadcasts        : broadcasts
  login             : login
  loginFailed       : loginFailed
  textArea          : textArea
  createBroadcast   : createBroadcast
  newInput          : newInput
