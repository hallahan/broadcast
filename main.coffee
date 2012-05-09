express = require('express')

app = module.exports = express.createServer()


# Configuration
app.configure( ->
  app.use(express.bodyParser())
  app.use(express.methodOverride())
  app.use(express.cookieParser())
  app.use(express.session({ secret: 'Zimbabwe', cookie: { maxAge: 2592000000 }}))
  app.use(app.router)
  app.use(express.static(__dirname + '/public'))
)

app.configure('development', ->
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))
)

app.configure('production', ->
  app.use(express.errorHandler())
)

# Routes
app.get('/', (req, res) ->
  res.redirect('/index.html')
)


# Start application.
app.listen(3000, ->
  console.log("Broadcast server listening on port %d in %s mode", app.address().port, app.settings.env)
)