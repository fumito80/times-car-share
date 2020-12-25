uid = (window.location.href.match /[\\?&]uid=([^&#]*)/)?[1]
tp = chrome.extension.getBackgroundPage().window.tp
tp.activity = tp.getActivity(uid)
tp.activity.uid = uid

if (tp.activity.startClassName isnt "FavoriteNomapView")
  $LAB
    .script("js/underscore-min.js")
    .script("js/jquery-2.0.0.min.js").wait()
    .script("js/backbone-min.js")
    .script("js/jquery-ui-1.9.2.custom.min.js")
    .script("css/facybox.js")
    .script("js/application.js")
    .script("https://maps.googleapis.com/maps/api/js?key=AIzaSyApuorSOF_bs5SLCz2IdhokQFZlC_ZoibM&callback=doneScriptLoad")
else
  $LAB
    .script("js/underscore-min.js")
    .script("js/jquery-2.0.0.min.js").wait()
    .script("js/backbone-min.js")
    .script("css/facybox.js")
    .script("js/classesNomap.js").wait -> doneScriptLoad()

chrome.tabs.getSelected null, (tab) ->
  chrome.pageAction.show(tab.id)

chrome.runtime.onMessage.addListener (message, sender) ->
  if (message is "restart")
    centerAddress = tp.activity.misc.centerAddress
    tp.activity = tp.getActivity(uid)
    tp.activity.misc.centerAddress = centerAddress
    appView.reset()
    delete appView
    run()

run = ->
  # Main page view作成
  startClassName =
    switch tp.activity.misc.tabid
      when tp.tabidScdSeach
        if (tp.activity.misc.selectListOrder isnt "S")
          "SearchStaOrderWalkController"
        else
          "SearchStaController"
      when tp.tabidFavorite
        if (tp.activity.misc.checkMap)
          "FavMapController"
        else
          "FavNomapController"
  
  window.appView = new tp[startClassName] {}
  window.appView.run()

doneScriptLoad = ->
  jQuery -> run()
