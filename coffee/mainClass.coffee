WindowView = Backbone.View.extend

  initialize: (options) ->
    $(window).on "resize", @onResize.bind(@)
    $(window).on "unload", @onWindowUnload.bind(@)
    timer = false

  render: ->
    $("#map_block").before $('<div id="stations_block"></div>')
    @

  ### on DOM event ###
  onResize: ->
    if (timer)
      clearTimeout(timer)
    timer = setTimeout((=> @resizeContainer(resize: true)), 200)

  resizeContainer: (options) ->
    windowHeight = $(window).height()
    frameWidth   = $("div.mainframe").width()
    frameHeight  = $("div.mainframe").height()
    formInputAddress = $("#map_block form.inputForm").height()
    $("#map_canvas").height(windowHeight - formInputAddress - (windowHeight - frameHeight))
    divInputSelectHeight = $("#stations_block .divInputSelect").height()
    # $("#stations_block div.stations").height(windowHeight - divInputSelectHeight - (windowHeight - frameHeight) - 11)
    if options?.resize
      @trigger "doneResizeContainer"

  onWindowUnload: ->
    @trigger "windowUnload"


### コントローラー基底クラス（マップなし） ###
ControllerBase = Backbone.View.extend

  initialize: (options) ->

    @windowView = new WindowView().render()
    @collection = new tp.StationCollection()
    @stationSetView = new tp[options.stationSetViewClassName] _.extend
      model: new tp.PlainModel()
      collection: @collection
      options
    @stationSetView
      .on("getSelectDateHour", @onGetSelectDateHour, @)
      .render()
    @localDB = tp.getLocalDB()
    @listener = @chromeTabsMessageListener.bind(@)
    chrome.runtime.onMessage.addListener @listener

  ### instance method ###
  # ステーションズ読込み開始 #マップモードのときオーバーライドされる
  run: ->

    # ステーションコレクション／モデル作成
    $.each @stations, (i, station) =>

      model = @collection.get(station.scd)

      unless (model)
        # ステーション名セット
        unless (station.name)
          stationName = @getStationName(station.scd)
          if (stationName)
            station.name  = stationName.name
            station.alias = stationName.alias
          else
            station.name = station.alias = "Station " + (i + 1)

        # Collectionへmodelの追加 -> フレーム, StationView, MarkerView作成
        model = @collection.push station

      model.set {deferred: deferred = $.Deferred()}
      deferred.promise()

    @startLoad()

  startLoad: (options) ->
    if !options?.changeTimetable && @stations.length is 0
      @trigger "doneLoads", options
      return

    $.when.apply(null, @collection.pluck("deferred"))
      .done =>
        @trigger "doneLoads", options
      .fail =>

    @trigger "doneReadyLoads", options

  getStationName: (scd) ->
    if (@localDB[scd])
      name:  @localDB[scd].name
      alias: @localDB[scd].alias || @localDB[scd].name

  onGetSelectDateHour: (container) ->
    tp.getSelectDateHour container

  chromeTabsMessageListener: (message, sender, sendResponse) ->
    if (message is "requestStartTrigger")
      @trigger "requestSendDfdWait", container = {}
      container.dfdWaitSearch
        .done ->
          sendResponse "ok"

  saveDB: ->
    @trigger "getStationWidth", container = {}
    @localDB.misc = _.extend @localDB.misc || {}, container
    tp.saveLocalDB @localDB.misc

  reset: ->
    @saveDB()
    while model = @collection.at(0)
      @collection.remove(model)
    @collection.off null, null, null
    delete @mapView.collection
    @stationSetView.model.off null, null, null
    @stationSetView.off null, null, null
    @stationSetView.remove()
    @windowView.off null, null, null
    @windowView.remove()
    $(window).off "resize"
    $(window).off "unload"
    @off null, null, null
    @remove()
    chrome.runtime.onMessage.removeListener @listener
    tp.mapView[tp.activity.uid] = @mapView.off null, null, null

### コントローラー基底クラス（マップあり） ###
class ControllerMapBase extends ControllerBase

  constructor: (options) ->
    super(options)

    if (tp.mapView[tp.activity.uid]?.dfdPresetStations?.state() is "resolved")
      @mapView = tp.mapView[tp.activity.uid].reset _.extend
        collection: @collection
        options
    else
      @mapView = new tp.MapView _.extend
        model: new tp.PlainModel()
        collection: @collection
        options
      @mapView.render()

    # like pub/sub pattern (gathered Backbone events)
    @on                "requestPrsetStations", @mapView.presetStations           , @mapView
    @on                "requestSendDfdWait"  , @mapView.sendDfdWaitSearch        , @mapView
    @on                "doneLoads"           , @mapView.onDoneLoads              , @mapView
    @on                "doneLoads"           , @stationSetView.onDoneLoads       , @stationSetView
    @on                "doneLoads"           , @windowView.resizeContainer       , @windowView
    @on                "doneReadyLoads"      , @stationSetView.onDoneReadyLoads  , @stationSetView
    @on                "setStationWidth"     , @stationSetView.onSetStationWidth , @stationSetView
    @on                "getStationWidth"     , @stationSetView.onGetStationWidth , @stationSetView
    @stationSetView.on "changeTimetable"     , @onChangeTimetable                , @
    @stationSetView.on "getLocalDB"          , @onGetLocalDB                     , @
    @stationSetView.on "updateLocalDB"       , @onUpdateLocalDB                  , @
    @stationSetView.on "getCenterLatLng"     , @mapView.sendCenterLatLng         , @mapView
    @stationSetView.on "setDirectionWaitIcon", @mapView.setDirectionWaitIcon     , @mapView
    @stationSetView.on "doneDragSplitter"    , @mapView.resetCenter              , @mapView
    @stationSetView.on "addStations"         , @mapView.addStations              , @mapView
    @mapView.on        "changeAddress"       , @stationSetView.refreshDivs       , @stationSetView
    @mapView.on        "changeAddress"       , @run                              , @
    @mapView.on        "addStations"         , @run                              , @
    @mapView.on        "getLocalDB"          , @onGetLocalDB                     , @
    @mapView.on        "sendStations"        , @onSendStations                   , @
    @mapView.on        "readyNextStation"    , @stationSetView.enableNextSta     , @stationSetView
    @windowView.on     "windowUnload"        , @onWindowUnload                   , @
    @windowView.on     "doneResizeContainer" , @mapView.resetCenter              , @mapView
    @stationSetView.collection.on "requestStartTrigger", @mapView.sendDfdWaitSearch, @mapView

    @trigger "setStationWidth",
      tdPaddingEm:      @localDB.misc?.tdPaddingEm || 0.2
      divStationsWidth: @localDB.misc?.divStationsWidth || 483

    @mapView.dfdRenderGMap
      .done =>
        @trigger "requestPrsetStations"
      .fail =>
        tp.alert "Google mapsを初期化できませんでした。"

  ### instance method ###
  run: (options) ->
    @mapView.dfdPresetStations
      .done =>
        super(options)

  onSendStations: (@stations) ->

  onChangeTimetable: (options) ->
    $.each @collection.models, (i, model) =>
      if (!model.get("disabled") || _.find @stations, (station) -> station.scd is model.id)
        model.set {deferred: deferred = $.Deferred()}
        deferred.promise()
    @startLoad(options)

  onGetLocalDB: (container) ->
    container.localDB = @localDB

  onUpdateLocalDB: (scd, station) ->
    tp.setLocalDB scd, @localDB[scd] = station

  onWindowUnload: ->
    tp.mapView[tp.activity.uid]?.off null, null, null
    tp.mapView[tp.activity.uid] = null
    @saveDB()


### インスタンス化クラス ###

# お気に入りモードマップなし
class tp.FavNomapController extends ControllerBase

  constructor: (options) ->
    super _.extend
      stationViewClassName:    "StationNomapView"
      stationSetViewClassName: "StationSetNomapView"
      options

    @stations = []
    $.each tp.activity.favs, (i, station) =>
      if (station.checked)
        @stations.push station

# お気に入りモードマップあり
class tp.FavMapController extends ControllerMapBase

  constructor: (options) ->

    super _.extend
      stationViewClassName:    "SortableStationView"
      stationSetViewClassName: "StationSetView"
      markerViewClassName:     "MarkerWoRouteView"
      waitMSec:                0
      searchMargin:            0
      searchStations:          tp.setFavStationLatLngs
      options

# マップ検索モード 徒歩距離順
class tp.SearchStaController extends ControllerMapBase

  constructor: (options) ->

    super _.extend
      stationViewClassName:    "SortableStationView"
      stationSetViewClassName: "SortableStationSetView"
      markerViewClassName:     "MarkerWoRouteView"
      waitMSec:                0
      searchMargin:            0
      checkSearchRange:        tp.checkSearchRangeS
      searchStations:          tp.searchStations
      options

# マップ検索モード 徒歩距離順
class tp.SearchStaOrderWalkController extends ControllerMapBase

  constructor: (options) ->

    super _.extend
      stationViewClassName:    "SortableRouteStationView"
      stationSetViewClassName: "SortableRouteStationSetView"
      markerViewClassName:     "MarkerView"
      waitMSec:                0
      searchMargin:            4
      checkSearchRange:        tp.checkSearchRangeW
      searchStations:          tp.searchStations
      options
