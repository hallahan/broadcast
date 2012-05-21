#! /bin/bash

echo "Coffee-script compiler in watch mode for server and client..."
./node_modules/.bin/coffee -cw -o lib/ src/util.coffee src/model.coffee src/app.coffee & ./node_modules/.bin/coffee -cw -o public/ src/util.coffee src/view.coffee src/controller.coffee
