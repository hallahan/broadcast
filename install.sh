#! /bin/bash

echo "Installing dependencies with Node Package Manager..."
npm install 

echo "Compiling client coffeescript to javascript..."
./node_modules/.bin/browserify src/client.coffee -o public/client.js

echo "Compiling server coffeescript to javascript..."
./node_modules/coffee-script/bin/coffee -c -o lib/ src/*.coffee

echo "Starting server."
node lib/app.js
