#! /bin/bash

echo "Turning on coffeescript compiler in watch mode..."
./node_modules/.bin/browserify src/client.coffee --watch -o public/client.js & ./node_modules/coffee-script/bin/coffee -cw -o lib/ src/*.coffee
