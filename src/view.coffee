# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io


# view is a global variable declared in the html
view.online = (onlineUsers) -> 
  str =     """
    <div class="accordion-heading">
      <a class="accordion-toggle" data-toggle="collapse" data-parent="#onlineAccordion" href="#online-users">
        <strong>Online</strong> ( #{onlineUsers.length}} )
      </a>
    </div>
    <div id="online-users" class="accordion-body collapse in"> """ 
  for user in onlineUsers
    str +=  """
      <div data-uid=#{user.uid} class="accordion-inner-online">
        <strong>#{user.name}}</strong> <span class="broadcast-email">{{user.email}}</span>
      </div>"""
  str +=    """
    </div>  """
  $('#online').html str


view.broadcasts = (log) ->
  str = """
    <div class="accordion-heading">
      <a class="accordion-toggle" data-toggle="collapse" data-parent="#broadcastAccordion" href="#collapse">
        {{today}}
      </a>
    </div>
    <div id="collapse" class="accordion-body collapse in">

      <div id="broadcastsTextBoxActive"></div>
      
      <div id="textBox" class="accordion-inner">
        <textarea id="broadcastTextArea" class="broadcast-text-area" rows="2"></textarea>
      </div>

      
      <div id="broadcastsInAccordion">

      </div>


      {{#loggedBroadcasts}}
        <div class="accordion-inner">
          <strong>{{name}}</strong> <span class="broadcast-time">{{time}}</span>
          <br/>
          {{txt}}
        </div>
      {{/loggedBroadcasts}}
    </div> """