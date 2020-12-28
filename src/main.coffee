import "jquery-ui/ui/widgets/draggable"
import "./facybox"
import "./jquery.scrollintoview.min"
import "./commonClass"
import "./mapClass"
import "./mainClass"

uid = (window.location.href.match /[\\?&]uid=([^&#]*)/)?[1]
tp = chrome.extension.getBackgroundPage().window.tp
tp.activity = tp.getActivity(uid)
tp.activity.uid = uid

chrome.tabs.getSelected null, (tab) ->
  chrome.pageAction.show(tab.id)

chrome.runtime.onMessage.addListener (message, sender) ->
  if (message is "restart")
    centerAddress = tp.activity.misc.centerAddress
    tp.activity = tp.getActivity(uid)
    tp.activity.misc.centerAddress = centerAddress
    appView.reset()
    appView = null
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

loadedGoogleMaps = ->
  jQuery -> run()

google.maps.event.addDomListener(window, 'load', loadedGoogleMaps)
