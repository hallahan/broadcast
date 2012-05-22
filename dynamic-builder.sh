#! /bin/bash

echo "Coffee-script compiler in watch mode for server and client..."
./node_modules/.bin/coffee -cw -o lib/ src/util.coffee src/model.coffee src/app.coffee & ./node_modules/.bin/coffee -cw -o public/ src/util.coffee src/view.coffee src/controller.coffee & ./node_modules/.bin/coffee -cw -o public/ test/test-client.coffee & ./node_modules/.bin/coffee -cw -o test/ test/test-model.coffee
