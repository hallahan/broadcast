# The Outpost Broadcast for The Smallest Federated Wiki
# by Nicholas Hallahan
# http://broadcast.theoutpost.io

# This is the code for the controller which resides
# client side.

view = broadcast.view


view.online(broadcast.test.users)
view.broadcasts(broadcast.test.log, broadcast.test.users)