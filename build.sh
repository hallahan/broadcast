#! /bin/bash

echo "Installing dependencies with Node Package Manager..."
npm install 

echo "Compiling server coffeescript to javascript..."
./node_modules/.bin/coffee -c -o lib/ src/*.coffee

echo "Compiling client-side code to a single client.js file..."
./node_modules/.bin/browserify lib/controller.js -o public/client.js

echo "Starting server."
node lib/app.js
