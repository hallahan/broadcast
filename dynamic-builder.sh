#! /bin/bash

echo "Coffee-script compiler in watch mode for server and client..."
./node_modules/.bin/coffee -cw -o lib/ src/utility.coffee src/model.coffee src/app.coffee & ./node_modules/.bin/browserify src/controller.coffee -wo public/broadcast.js