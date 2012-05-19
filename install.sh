#! /bin/bash

echo "Compiling client coffeescript to javascript..."
coffee -c -o public/ src/util.coffee
coffee -c -o public/ src/view.coffee
coffee -c -o public/ src/controller.coffee

echo "Compiling server coffeescript to javascript..."
coffee -c -o lib/ src/model.coffee
coffee -c -o lib/ src/app.coffee

echo "Installing dependencies with Node Package Manager..."
npm install 

echo "Starting server."
node lib/app.js
