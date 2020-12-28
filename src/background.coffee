favorites = {}
selectDate = {}
selectHour = {}

chrome.extension.onConnect.addListener (port) ->
  if (port.name is "CtoB")
    portCtoB = port
    portCtoB.onMessage.addListener(onMessageHandler)
    portCtoB.onDisconnect.addListener ->
      portCtoB.onMessage.removeListener(onMessageHandler)

onMessageHandler = (msg) ->
  switch msg.command
    when "sendFavorites"
      # アイコン表示
      chrome.tabs.getSelected null, (tab) ->
        tabId = tab.id
        chrome.pageAction.show(tabId)
      favorites = msg.favorites
      $.ajax
        method: "GET"
        url: "https://share.timescar.jp/view/station/search.jsp"
      .done (resp) ->
        resp$ = $(resp)
        selectDate = resp$.find("#takeDate")
          .find("option:first").remove().end()
          .find("option:first").attr("selected", "selected").end()
        selectHour = resp$.find("#takeHour")
          .find("option:first").remove().end()
          .find("option:first").attr("selected", "selected").end()
        Array.prototype.forEach.call selectHour.find("option"), (option) ->
          text = (option$ = $(option)).text()
          option$.text(text + ":00")

activities = {}
tabUidList = {}
localDB =
  if (localStorage.tpstations)
    JSON.parse localStorage.tpstations
  else
    {}

window.tp =

  mapView: {}
  # タブ定数
  tabidScdSeach: 0
  tabidFavorite: 1
  
  createNewTab: (activity) ->
    # 新規タブ作成準備
    uid = (new Date()).getTime().toString()
    url = "newtab.html?uid=" + uid
    activities[uid] = activity
    # 新規タブ作成 → 編集SCDリストは、新規タブが起動時にbackground.htmから取得する
    chrome.tabs.getSelected null, (tab) ->
      chrome.tabs.create
        index: tab.index + 1
        url: url
        (tab) ->
          tabUidList[tab.id] = uid
          chrome.pageAction.show(tab.id)
  
    # タブクローズ処理
    chrome.tabs.onRemoved.addListener (tabId) ->
      uid = tabUidList[tabId]
      if (uid)
        delete activities[uid]
  
  bgCloseTab: (uid) ->
    for key, value of tabUidList
      chrome.tabs.remove(parseInt(key, 10)) if (value is uid)
  
  getFavorites: ->
    favorites
  
  setActivity: (uid, activity) ->
    activities[uid] = activity
  
  getActivity: (uid) ->
    if (uid)
      activities[uid]
    else
      favorites
  
  getLocalDB: (scd) ->
    if scd
      localDB[scd]
    else
      localDB
  
  setLocalDB: (scd, stations) ->
    localDB[scd] = stations
  
  saveLocalDB: (misc) ->
    localDB.misc = misc
    localStorage.tpstations = JSON.stringify localDB
  
  getSelectDateHour: (container) ->
    container.selectDate = selectDate
    container.selectHour = selectHour
