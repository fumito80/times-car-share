cmd /c coffee -o js -c coffee\background.coffee coffee\script.coffee
cd coffee
cmd /c coffee -o js -c popup.coffee jsload.coffee
type commonClass.coffee > classes.coffee
type mapClass.coffee >> classes.coffee
type mainClass.coffee >> classes.coffee
cmd /c coffee -o js -c classes.coffee

rem cd coffee & coffee -j js/classes.js -c commonClass.coffee mapClass.coffee mainClass.coffee

cd..

cmd /c uglifyjs coffee\js\classes.js > js\application.js
type coffee\js\jquery.scrollintoview.min.js >> js\application.js
type coffee\js\LAB.min.js > js\jsload.js
cmd /c uglifyjs coffee\js\jsload.js >> js\jsload.js
cmd /c uglifyjs coffee\js\popup.js > js\popup.js
type coffee\js\jquery.balloon.min.js >> js\popup.js

pause
