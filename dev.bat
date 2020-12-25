cd coffee

type commonClass.coffee > classes.coffee
type mapClass.coffee >> classes.coffee
type mainClass.coffee >> classes.coffee
cmd /c coffee -o js -c classes.coffee

cd..
type coffee\js\classes.js > js\application.js
type coffee\js\jquery.scrollintoview.min.js >> js\application.js

pause
