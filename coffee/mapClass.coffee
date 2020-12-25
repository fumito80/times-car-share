### const ###
tp.ptAdjust  = 0.0032 # TimesPlus地図とGoogleMaps地図との補正値
### end const ###

# Backbone グーグルマップ マーカー View
MarkerBaseView = Backbone.View.extend

  initialize: ->
    @model.on
      "change:contents": @renderMarker
      "change:selected": @renderSelectedIcon
      "change:disabled": @onChangeDisabled
      "remove":          @onRemove
      @
    @model.collection.on
      "clearRoute":      @onClearRoute
      "selectStation":   @onSelectStation
      "hoverStation":    @onHoverStation
      "closeInfoWindow": @onCloseInfoWindow
      @
    @icon =
      norm: new google.maps.MarkerImage "images/marker_car_sprite.png", new google.maps.Size(32, 37),
        new google.maps.Point(164, 0)
      hover: new google.maps.MarkerImage "images/marker_car_sprite.png", new google.maps.Size(32, 37),
        new google.maps.Point(246, 0)
      sel: new google.maps.MarkerImage "images/marker_car_sprite.png", new google.maps.Size(32, 37),
        new google.maps.Point(0, 0)
      sel_hover: new google.maps.MarkerImage "images/marker_car_sprite.png", new google.maps.Size(32, 37),
        new google.maps.Point(82, 0)

  ### on Model event ###
  renderMarker: ->
    @marker = new google.maps.Marker
      map: @options.map
      position: @model.get("latlng")
      title: @model.get("alias")
      icon: @icon.norm
      visible: !@model.get("disabled")
    google.maps.event.addListener @marker, "click", (event) =>
      @model.collection.trigger "selectStation", @model.id, "marker"
    google.maps.event.addListener @marker, "mouseover", =>
      @model.collection.trigger "hoverStation", true, @model.id, "marker"
    google.maps.event.addListener @marker, "mouseout", =>
      @model.collection.trigger "hoverStation", false, @model.id, "marker"
    content = $(@infoWindowTempl {title: @model.get("alias")})
    content.find("button.reserv").on "click", =>
      @model.trigger "requestReservePage"
    content.find("button.svp").on "click", =>
      @trigger "requestStreetView", @model
    @infowindow = new google.maps.InfoWindow
      content: content[0]
    google.maps.event.addListener @marker, "rightclick", =>
      @model.collection.trigger "closeInfoWindow", @model.id
      @infowindow.open @options.map, @marker
      @model.collection.trigger "selectStation", @model.id, "marker"

  renderSelectedIcon: ->
    if (@marker)
      @marker.setIcon if @model.get("selected") then @icon.sel else @icon.norm

  renderHoveredIcon: ->
    if (@marker)
      @marker.setIcon if (@model.get("selected")) then @icon.sel_hover else @icon.hover

  # マーカーの表示切り替え
  onChangeDisabled: ->
    if (@marker)
      @marker.setVisible(!@model.get("disabled"))

  onChangeDistance: ->
    @model.collection.trigger "doneRenderDistance"

  # マーカーの削除 & ビューの削除
  onRemove: ->
    google.maps.event.clearInstanceListeners @marker
    @marker.setMap null
    delete @marker
    @infowindow.close()
    $(@infowindow.content).find("button").off "click"
    delete @infowindow
    @model.collection.off null, null, @
    @off null, null, null
    @remove()

  ### on Collection event ###
  onClearRoute: ->
    @model.unset "distanceS"
    @model.unset "distanceW"
    @model.unset "route"


  onSelectStation: (id, whichSelect) ->
    if (id is @model.id)
      @model.set {selected: true}
      @marker.setIcon @icon.sel_hover
      if (@model.has("route"))
        @trigger "setDirections", @model.get("route")
      else
        @trigger "setRoute", @model, {direction: true}
      if (whichSelect is "listItem")
        @trigger "setCenter", @model.get("latlng")
    else
      @model.set {selected: false}

  onHoverStation: (hovered, id, whichSelect) ->
    if (id is @model.id)
      if (hovered)
        @renderHoveredIcon()
      else
        @renderSelectedIcon()
    else
      @renderSelectedIcon()

  onCloseInfoWindow: (scd) ->
    if (scd isnt @model.id)
      @infowindow.close()

  ### instance method ###
  doneGetLatLngByScd: (resp) ->
    if (resp.status isnt google.maps.GeocoderStatus.OK)
      return @alertFailure(resp.status)
    @model.set {latlng: resp.latlng}

  # ルート, 距離セット
  setRoute: ->
    unless (@model.has("distanceS"))
      @trigger "setDistanceS", @model
    @trigger "setRoute", @model

  infoWindowTempl: _.template """
    <div class="gmapinfownd">
      <h7 style="margin:0"><%= title %></h7><br><br>
      <button class="svp small">ストリートビュー<i class="icon-zoom-in"></i></button>
      <button class="reserv small">予約 »<i class=""></i></button>
    <div>
    """

class tp.MarkerWoRouteView extends MarkerBaseView

  initialize: (options) ->
    super(options)
    @model.on "change:distanceS", @onChangeDistance, @

  renderMarker: ->
    if (@marker)
      unless (@model.has("distanceS"))
        @trigger "setDistanceS", @model
      return
    else
      super()
    if (@model.has("distanceS"))
      @model.trigger "change:distanceS"
    else
      @trigger "setDistanceS", @model

class tp.MarkerView extends MarkerBaseView

  initialize: (options) ->
    super(options)
    @model.on "change:distanceW", @onChangeDistance, @

  renderMarker: ->
    if (@marker)
      unless (@model.has("route"))
        @setRoute()
      return
    else
      super()
    @setRoute()


# マップView
tp.MapView = Backbone.View.extend {

  ### Backbone property ###
  el: "#map_block"

  events:
    "submit form.inputForm":              "onChangeAddress" # センター位置住所を移動
    "click form.inputForm i.icon-search": "onChangeAddress" # センター位置住所を移動
    "focus form.inputForm input:text":    "onFocusInput"
    "blur form.inputForm input:text":     "onBlurInput"

  initialize: (options) ->
    {@collection, @markerViewClassName, @waitMSec, @searchMargin, @checkSearchRange, @searchStations} = options
    @model.on
      "change:address": @changeCenterAddress
      @
    @collection.on
      "add":       @onAddRender
      "hideRoute": @onHideRoute
      @
    (@dfdRenderGMap = $.Deferred()).promise()
    (@dfdPresetStations = $.Deferred()).promise()
    (@dfdWaitSearch = $.Deferred()).promise()
    tp.atwith tp.activity.misc, @

  ### instance method ###
  reset: (options) ->
    @setDirectionWaitIcon(false)
    @setDirectionWaitIcon(true)
    @model.off null, null, @
    @initialize(options)
    @dfdRenderGMap.resolve()
    @

  render: ->
    (@dfdPresetStations = $.Deferred()).promise()
    @$el.html(@template)
    @$("#address").val tp.activity.misc.centerAddress
    # google.load "maps", "3",
    #   "other_params": "sensor=false"
    #   "callback": @mapsLoaded.bind(@)
    # @
    # mapsLoaded: ->
    @geocoder = new google.maps.Geocoder()
    if (address = tp.activity.misc.centerAddress)
      @getLatLngByAddress(address)
        .done (latlng) =>
          @renderGMap
            address: address
            latlng:  latlng
    else
      # 現在地モードのとき
      @getAddressFromCurrentPos()
        .done (resp) =>
          @$("#address").val resp.address
          @renderGMap resp
    @

  # グーグルマップ初期化
  renderGMap: (addressInfo) ->
    @model.set
      address: addressInfo.address
      latlng:  addressInfo.latlng
      {silent: true}
    @map = new google.maps.Map @$("#map_canvas")[0],
      zoom: 15,
      center: @model.get("latlng")
      mapTypeId: google.maps.MapTypeId.ROADMAP
      scaleControl: true
    @directionsService = new google.maps.DirectionsService() # Google maps route service
    @directionsDisplay = new google.maps.DirectionsRenderer
      draggable: true
      preserveViewport: true
      suppressMarkers : true
      suppressInfoWindows: true
    @directionsDisplay.setMap(@map)
    google.maps.event.addListener @directionsDisplay, "directions_changed", =>
      if (@directionsDisplay.directions.modelId)
        return
      if (model = @collection.where({selected: true})[0])
        directionsResult = @directionsDisplay.getDirections()
        route = directionsResult.routes[0]
        distance = 0
        $.each route.legs, (i, leg) ->
          distance += leg.distance.value
        directionsResult.modelId = model.id
        model.set
          route: directionsResult
          distanceW: Math.round(distance * 1000) / 1000
    @renderCenterMarker()
    @dfdRenderGMap.resolve()

  # センターマーカー設置
  renderCenterMarker: ->
    if (@markerAddress)
      @markerAddress.setMap(null)
    @markerAddress = new google.maps.Marker
      map:      @map
      position: @model.get("latlng")
      title:    @model.get("address")
      draggable: true
    @map.panTo @model.get("latlng")
    google.maps.event.addListener @markerAddress, "dblclick", =>
      model = @collection.where({selected: true})[0]
      @onSetRoute model, {direction: true}
    google.maps.event.addListener @markerAddress, "dragstart", =>
      @onHideRoute()
    google.maps.event.addListener @markerAddress, "dragend", =>
      @changeAddressByLatLng(@markerAddress.position)

  # マーカードラッグで移動
  changeAddressByLatLng: (latLng) ->
    @geocoder.geocode {location: latLng},
      (results, status) =>
        if (status is google.maps.GeocoderStatus.OK && results[0])
          newAddress = results[0].formatted_address
          @markerAddress.setOptions
            title: newAddress
          @model.set
            address: newAddress
            latlng:  @markerAddress.position
            {silent: true}
          @changeAddress(newAddress)

  # ステーション決定
  presetStations: ->
    @onHideRoute()
    unless (@dfdPresetStations.state() is "pending")
      (@dfdPresetStations = $.Deferred()).promise()
    $.when(@searchStations())
    .done =>
      @dfdPresetStations.resolve()
    .fail (error) =>
      @dfdPresetStations.reject()
      @setDirectionWaitIcon(false)
      tp.alert error

  # 住所から経度、緯度を返す
  getLatLngByAddress: (address) ->
    dfd = $.Deferred()
    @geocoder.geocode {address: address},
      (results, status) =>
        if (status is google.maps.GeocoderStatus.OK)
          latlng = results[0].geometry.location
          dfd.resolve latlng
        else
          @alertFailure status
          dfd.reject()
    dfd.promise()

  # 現在地から住所、経度、緯度を返す
  getAddressFromCurrentPos: ->
    dfd = $.Deferred()
    if (navigator.geolocation)
      navigator.geolocation.getCurrentPosition(
        (position) =>
          latlng = new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
          @geocoder.geocode {location: latlng},
            (results, status) =>
              if (status is google.maps.GeocoderStatus.OK)
                address = results[0].formatted_address
                dfd.resolve
                  latlng: latlng
                  address: address
              else
                @alertFailure status
                dfd.reject()
        (error) ->
          switch (error.code)
            when error.TIMEOUT
              msg = "タイムアウトで<br>"
            when error.POSITION_UNAVAILABLE
              msg = "";
            when error.PERMISSION_DENIED
              msg = "アクセス許可の問題で<br>"
            when error.UNKNOWN_ERROR
              msg = "不明なエラーで<br>"
          tp.alert msg + "現在地が取得できませんでした。<br>住所を指定して検索してください。"
          dfd.reject()
      )
    else
      tp.alert "ご使用のブラウザでは現在地情報が取得できません。<br>住所を指定して検索してください。"
      dfd.reject()
    dfd.promise()

  resetCenter: ->
    google.maps.event.trigger @map, "resize"
    @map.panTo @markerAddress.position

  addStations: (addCount) ->
    if @shiftSearchedStations addCount - @selectListMax
      @setDirectionWaitIcon true
      @trigger "addStations"

  # failure async function call
  alertFailure: (status, option = "") ->
    tp.alert "Google-Geocodeは指定住所を取得できませんでした。" + option + "<br><br>エラーコード: " + status
    false

  # 直線距離を計算
  getStraightDistance: (latlngFrom, latLngTo) ->
    radianLat1 = latlngFrom.lat() * (Math.PI / 180)
    radianLng1 = latlngFrom.lng() * (Math.PI / 180)
    radianLat2 = latLngTo.lat() * (Math.PI / 180)
    radianLng2 = latLngTo.lng() * (Math.PI / 180)
    diffLat    = (radianLat1 - radianLat2)
    diffLng    = (radianLng1 - radianLng2)
    sinLat     = Math.sin(diffLat / 2)
    sinLng     = Math.sin(diffLng / 2)
    a = Math.pow(sinLat, 2.0) + Math.cos(radianLat1) * Math.cos(radianLat2) * Math.pow(sinLng, 2.0)
    earth_radius = 6378.1
    distance = earth_radius * 2 * Math.asin(Math.min(1, Math.sqrt(a)))

  # 新住所で再検索
  changeAddress: (newAddress) ->
    if (newAddress)
      @$("#address").val(newAddress)
    tp.activity.misc.centerAddress = @model.get("address")
    tp.activity.misc.latlng = @model.get("latlng")
    @map.panTo tp.activity.misc.latlng
    @collection.trigger "selectStation", {id: null}
    @collection.trigger "clearRoute"
    @setDirectionWaitIcon(true)
    @presetStations()
    @trigger "changeAddress"

  sendCenterLatLng: (container) ->
    container.latlng = @model.get("latlng")

  sendDfdWaitSearch: (container) ->
    container.dfdWaitSearch = @dfdWaitSearch

  ### on Model event ###
  # Addressからセンターマーカー設置
  changeCenterAddress: ->
    @getLatLngByAddress(address = @model.get("address"))
      .done (latlng) =>
        @markerAddress.setOptions
          title: address
          position: latlng
        @model.set
          latlng: latlng
        @changeAddress()

  ### on Collection event ###
  # ルートパス削除
  onHideRoute: (route) ->
    # 開始と終了地点を同じにしてルートクリアする
    if (@markerAddress && (!route || (@directionsDisplay.directions is route)))
      if (@zeroDirections)
        @directionsDisplay.setDirections(@zeroDirections)
      else
        @directionsService.route
          origin: @markerAddress.position
          destination: @markerAddress.position
          travelMode: google.maps.DirectionsTravelMode.WALKING
          (resp, status) =>
            if (status is google.maps.DirectionsStatus.OK)
              @directionsDisplay.setDirections(resp)
              @zeroDirections = resp

  # 最終地図位置合わせ
  onDoneLoads: (options) ->
    google.maps.event.trigger @map, "resize"
    if options?.changeTimetable
      @setDirectionWaitIcon false
    else
      setTimeout((=>
        @setDirectionWaitIcon false
      ), @waitMSec)

  onAddRender: (model, collection, options) ->
    markerView = new tp[@markerViewClassName]
      model: model
      map: @map
    markerView.on
      "setDistanceS":  @onSetDistanceS
      "setRoute":      @onSetRoute
      "setDirections": @onSetDirections
      "setCenter":     @onSetCenter
      "requestStreetView": @onRequestStreetView
      @

  setDirectionWaitIcon: (enable) ->
    if (enable)
      (@dfdWaitSearch = $.Deferred()).promise()
    else
      @dfdWaitSearch.resolve()
    if (@divMarker?.length > 0)
      if (enable)
        @imgMarker.hide()
        @divMarker.addClass("searching")
        @$("form, input, i").addClass("disabled")
        @$("form.inputForm input").attr("disabled", "disabled")
      else
        @imgMarker.show()
        @divMarker.removeClass("searching")
        @$("form, input, i").removeClass("disabled")
        @$("form.inputForm input").removeAttr("disabled")
        @trigger "readyNextStation"
    else
      @$("form, input, i").removeClass("disabled")
      @$("form.inputForm input").removeAttr("disabled")
      styleSheets = Array.from(document.styleSheets).filter(
        (styleSheet) ->
          not styleSheet.href || styleSheet.href.startsWith(window.location.origin)
      );
      for style of styleSheets
        if (style instanceof CSSStyleSheet) and style.cssRules
      # for i in [0...document.styleSheets.length]
          if rules = style.cssRules
            for j in [rules.length-1..0]
              switch rules[j]?.selectorText
                when "#map_canvas div.gmnoprint:first-child:not([controlwidth])", 'div.gmnoprint img[src$="marker_sprite.png"]'
                  style.deleteRule(j)
      @divMarker = $("#map_canvas div.gmnoprint:has(img[src$='marker_sprite.png'])")
      @imgMarker = $("#map_canvas div.gmnoprint img[src$='marker_sprite.png']").show()
      @trigger "readyNextStation"

  ### on MarkerView event ###
  onSetDistanceS: (model) ->
    distanceS = Math.round(@getStraightDistance(@markerAddress.position, model.get("latlng")) * 1000)
    model.set {distanceS: distanceS}

  onSetRoute: (model, option, loops = 1) ->
    traveMode = "WALKING" #tp.activity.misc.selectListOrder
    request =
      origin: @markerAddress.position
      destination: model.get("latlng")
      optimizeWaypoints: true
      travelMode: google.maps.DirectionsTravelMode[traveMode]
      unitSystem: google.maps.DirectionsUnitSystem.METRIC
    @directionsService.route request,
      (resp, status) =>
        if (status is google.maps.DirectionsStatus.OK)
          route = resp.routes[0]
          distance = 0
          $.each route.legs, (i, leg) ->
            distance += leg.distance.value
          resp.modelId = model.id
          model.set
            route: resp
            distanceW: Math.round(distance * 1000) / 1000
          if (option?.direction)
            @onSetDirections(resp)
        else if (status is google.maps.DirectionsStatus.OVER_QUERY_LIMIT)
          console.log("#{model.get('name')} Retry: #{loops}")
          if loops++ > @mapRouteRetryTimes
            model.get("deferred").resolve()
            tp.alert """
              '#{model.get('alias')}'の新しいルートを検出できませんでした。<br>
              検索順位は正しくありません。<br><br>
              再試行回数: #{loops}<br>
              エラーコード: #{status}
              """
          else
            setTimeout((=>
              @onSetRoute model, option, loops
            ), @mapRouteWaitMSec)
        else
          tp.alert "Google Maps APIは新しいルートを検出できませんでした。<br><br>" +
            "エラーコード: " + status

  onSetDirections: (route) ->
    @directionsDisplay.setDirections(route)

  onSetCenter: (latlng) ->
    @map.panTo(latlng)

  onRequestStreetView: (model) ->
    unless @svp
      @svp = @map.getStreetView()
    @svp.setPosition(model.get("latlng"))
    @svp.setVisible true

  ### on DOM event ###
  # 住所をセンター位置へ移動
  onChangeAddress: (event) ->
    if $(event.currentTarget).hasClass("disabled")
      return
    address = @$("#address").val()
    if (address)
      @model.set {address: address}
    else
      @getAddressFromCurrentPos()
        .done (resp) =>
          @markerAddress.setOptions
            title:    resp.address
            position: resp.latlng
          @model.set
            address: resp.address
            latlng:  resp.latlng
            {silent: true}
          @changeAddress resp.address
    false

  onFocusInput: ->
    @$("form.inputForm").addClass("focus")

  onBlurInput: ->
    @$("form.inputForm").removeClass("focus")

  ### property ###
  template: """
    <div class="divInputAddress">
      <form class="inputForm disabled">
        <i class="icon-search disabled"></i>
        <input id="address" type="text" disabled="disabled" placeholder="現在地">
      </form>
    </div>
    <div id="map_canvas">
      <div style="padding-top: 240px;">地図を検索しています。<img src="images/loading2.gif"></div>
    </div>
    """
}

tp.setFavStationLatLngs = ->
  # scdから経度、緯度を問い合わせて、関数実行
  getLatLngByScd = (station) ->
    dfd = $.Deferred()
    $.getJSON "https://share.timescar.jp/view/station/teeda.ajax",
      time: (new Date()).toString()
      scd: station.scd
      component: "station_detailPage"
      action: "ajaxScdSearch"
    .done (resp) ->
      station.latlng = new google.maps.LatLng(resp.jsonLat * 1 + tp.ptAdjust, resp.jsonLon * 1 - tp.ptAdjust)
      dfd.resolve()
    dfd.promise()

  dfd = $.Deferred()
  fixedStations = []
  @trigger "getLocalDB", container = {}
  $.each tp.activity.favs, (i, station) ->
    if (station.checked)
      fixedStations.push station

  dfdQueries = $.Deferred().resolve()
  $.each fixedStations, (i, station) =>
    if (latlng = container.localDB[station.scd]?.latlng)
      laln = []
      for key of latlng
        laln.push latlng[key]
      station.latlng = new google.maps.LatLng(latlng.hb || laln[0], latlng.ib || laln[1])
    else
      dfdQueries = dfdQueries.then -> getLatLngByScd(station)
  dfdQueries.done =>
    @trigger "sendStations", fixedStations
    dfd.resolve()
  dfd.promise() if (dfd.state() is "pending")

### for MapView class prototype ###
tp.checkSearchRangeS = (distance) ->
  @selectRangeFrom <= distance <= @selectRangeTo

tp.checkSearchRangeW = (distance) ->
  distance <= @selectRangeTo

# 検索モード時PRE処理
tp.searchStations = ->
  dfd = $.Deferred()
  latlng = @model.get("latlng")
  area3kLat = 0.028  # 検索範囲のマージン緯度（Latitude）
  area3kLng = 0.035  # 検索範囲のマージン経度（Longitude）
  $.getJSON "https://share.timescar.jp/view/station/teeda.ajax",
    time: (new Date()).toString()
    minlat: Math.round((latlng.lat() - area3kLat - tp.ptAdjust) * 1000000)  / 1000000
    maxlat: Math.round((latlng.lat() + area3kLat - tp.ptAdjust) * 1000000)  / 1000000
    minlon: Math.round((latlng.lng() - area3kLng + tp.ptAdjust) * 10000000) / 10000000
    maxlon: Math.round((latlng.lng() + area3kLng + tp.ptAdjust) * 10000000) / 10000000
    component: "station_stationMapPage"
    action: "ajaxViewMap"
  .done (json) =>
    json.s.shift()
    if (json.s.length > 0)
      date = new Date
      date.setMilliseconds(0)
      date.setSeconds(0)
      date.setMinutes(0)
      sDate = date.getTime()
      $.get "https://share.timescar.jp/view/station/stationMap.jsp",
          sDate: sDate,
          eDate: sDate,
          scd: json.s[0].cd
      .done =>
        @postCheckSearchStations json.s, latlng, dfd
      .fail (jqXHR, textStatus) ->
        dfd.reject("Request failed: " + textStatus)
    else
      dfd.reject "現在地付近にステーションが見つかりませんでした。"
  .fail (jqXHR, textStatus) =>
    dfd.reject("Request failed: " + textStatus)
  dfd.promise()

# 検索モード時POST処理
tp.MapView.prototype.postCheckSearchStations = (siteItems, latlng, dfd) ->
  # 直線距離範囲チェック & 徒歩距離１次チェック
  @searchedStations = []
  $.each siteItems, (i, station) =>
    newLatlng =
      lat: -> station.la * 1 + tp.ptAdjust
      lng: -> station.lo * 1 - tp.ptAdjust
    if @checkSearchRange distance = @getStraightDistance(latlng, newLatlng)
      station.distanceS = distance
      station.latlng = newLatlng
      @searchedStations.push(station)
  if (@searchedStations.length is 0)
    dfd.reject "半径#{@selectRangeTo}km圏内にステーションが見つかりませんでした。"
    return
  @searchedStations.sort (a, b) -> a.distanceS - b.distanceS
  @shiftSearchedStations(@searchMargin, dfd)

tp.MapView.prototype.shiftSearchedStations = (searchMargin, dfd) ->
  # 表示制限チェック
  fixedStations = []
  $.each @searchedStations, (i, station) =>
    if (i < ~~@selectListMax + searchMargin)
      fixedStations.push
        scd: station.cd
        latlng: new google.maps.LatLng(station.latlng.lat(), station.latlng.lng())
        distanceS: Math.round(station.distanceS * 1000)
        checked: true
      station.reject = true
    else
      false
  @searchedStations = _.reject @searchedStations, (station) -> station.reject
  if fixedStations.length is 0
    tp.alert "検索範囲のステーションがすべて検索されました。"
  @trigger "sendStations", fixedStations
  dfd?.resolve()
  true
