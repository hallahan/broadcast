#! /bin/bash

echo "Turning on coffeescript compiler in watch mode..."
coffee -cw -o public/ src/util.coffee src/view.coffee src/controller.coffee & coffee -cw -o lib/ src/model.coffee src/app.coffee
