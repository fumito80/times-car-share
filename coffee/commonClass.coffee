### const ###
# 車の色のイメージ名
car_color_classes =
  "ホワイト":     "car_white"
  "グリーン":     "car_green"
  "レッド":       "car_red"
  "ブルー":       "car_blue"
  "シルバー":     "car_silver"
  "グレー":       "car_gray"
  "オレンジ":     "car_orange"
  "ライトブルー": "car_lightblue"
  "ブラウン":     "car_brown"
  "オレンジ":     "car_orange"
  "ワインレッド": "car_winered"
  "スモーキーグリーン": "car_smokygreen"
  "パープル": "car_purple"
  "ライムグリーン": "car_limegreen"
### end const ###

# 公開メンバオブジェクト
window.tp = chrome.extension.getBackgroundPage().window.tp

# 汎用モデル
tp.PlainModel = Backbone.Model.extend {}

# 各ステーション ウィンドウのモデル
StationModel = Backbone.Model.extend
  idAttribute: "scd"

### StationModel description
  scd:        ステーションID（Model id）
  name:       ステーション名
  alias:      ステーション設定値
  distanceS:  直線距離m
  distanceW:  徒歩距離m
  selected:   選択ステーション
  disabled:   非表示フラグ
  latlng:     緯度経度 Google maps object
  ordernum:   表示順Number
  contents:   タイムテーブル生HTML
  formdata:   フォームデータ
  route:      地図ルート Google maps direction object
  deferred:   jQuery Deferred object
###

# ステーションウィンドウのモデルのコレクション
tp.StationCollection = Backbone.Collection.extend {model: StationModel}

# 各ステーションウィンドウのビュー
StationBaseView = Backbone.View.extend

  events:
    "click button.reserv": "onClickReserve"
    "click i.icon-remove": "onClickDelStation"

  initialize: (options) ->
    @model.on
      "change:deferred": @renderLoading
      "change:contents": @renderContents
      "change:alias":    @renderAlias
      "change:error":    @renderError
      "remove":          @onRemove
      @

  render: ->
    @setElement @templateFrame(@model.toJSON())
    @

  ### on Model event ###
  renderLoading: ->
    if (@model.get("deferred").state() is "pending")
      if (@$el.find("img").show().length is 0)
        @$el.find("button").remove()
        @$el.find("table").remove()
        @$el.find("div:first").append '<img src="images/loading2.gif" class="loading">'

  # 各車情報の表示
  renderContents: ->
    @$("table").remove()
    $.each $(@model.get("contents")), (i, html) =>
      @$el.find("div:first").append @templateContent($(html))
    @model.unset "contents", {silent: true}

  # ステーション名
  renderAlias: ->
    @$("span.alias").text(@model.get("alias"))

  # Error時の表示
  renderError: ->
    @$el.find("div:first").append('<div class="errmsg">' + @model.get("error") + '</div>').find("img").remove()

  # el, events, 自身の削除
  onRemove: ->
    @model.collection.off null, null, @
    @model.off null, null, null
    @off null, null, null
    @remove()

  ### on DOM event ###
  onClickReserve: (event) ->
    @model.trigger "requestReservePage", $(event.currentTarget).parents("table").attr("id")

  onClickDelStation: (event) ->
    collection = @model.collection
    # if _.filter(collection.pluck("disabled"), (disabled) -> !disabled).length is 1
    #   return
    @$el.parent().remove()
    collection.trigger "requestStartTrigger", container = {}
    container.dfdWaitSearch
      .done ->
        collection.trigger "enableNextSta", true
    collection.trigger "hideRoute", @model.get("route")
    collection.remove(@model)
    event.stopPropagation()

  ### instance method/property ###
  templateContent: (car$) ->
    carId = car$[0].id
    color_name_jp = car$.data("color")
    car_color_class = car_color_classes[color_name_jp]
    timetable = car$.find("table.time")
    # color_name_jp = timetable.find("th:contains('カラー')").next().text()
    if (!car_color_class)
      car_color_class = "car_fumei"
    templCar = """
      <div class="panelCarname">
        <div class="caricon #{car_color_class}"></div>
        <div class="carname" title="#{color_name_jp}">#{car$.find("p.carname").text()}</div>
        <button class="reserv small square" style="float:left">予約</button>
        <div class="iconbutton">詳細<i class="icon-caret-down"></i></div>
        <div style="clear:both"></div>
      </div>
      """
    timetable
      .attr("id", carId)
      .prepend("<caption></caption>")
      .removeClass("time").addClass("timetable")
      .find("caption").append($(templCar))
        .end()
      .find("tr:has(th)")
        .addClass("detail")
        .hide()
        .end()
      .find("td").removeAttr("width")
    timetable

  templateFrame: _.template """
    <div id="<%= scd %>" class="station">
      <div class="stationBorder">
        <span class="ordernum"></span>
        <span class="alias" title="<%= name %>"><%= alias %></span>
        <img src="images/loading2.gif" class="loading" style="display:none">
        <i class="icon-remove" title="削除"></i>
        <div class="distance straight"></div>
        <div class="distance str s2"></div>
        <div class="distance walk"></div>
        <div class="distance str s1"></div>
      </div>
    </div>
    """

# 各ステーションウィンドウのビュー
class tp.StationNomapView extends StationBaseView

  constructor: (options) ->
    super(options)

  events: _.extend
    "click button.mapDetail": "onClickMapDetail"
    StationBaseView.prototype.events

  ### on Model event ###
  # 各車情報の表示
  renderContents: ->
    super()
    @$el.css("padding": "15px")
    @$("img").replaceWith($("<button />", {class: "mapDetail small", text: "地図"}))
    @$("div.iconbutton").hide()
    @$("div.ui-icon-close").show()
    @$("table").find("tr:has(th)").show()
    @model.get("deferred").resolve()

  ### on DOM event ###
  onClickMapDetail: ->
    window.open("https://share.timescar.jp/view/station/detail.jsp?scd=" + @model.id)

class SortableStationBaseView extends StationBaseView

  constructor: (options) ->
    super(options)
    @model.on
      "change:route":     @renderDistanceW
      "change:distanceS": @renderDistanceS
      "change:ordernum":  @renderOrderNum
      @
    @model.collection.on
      "selectStation": @onSelectStation
      "hoverStation":  @onHoverStation
      @

  ### instance method/property ###
  events: _.extend
    "click":             "onClickStation"
    "mouseenter":        "onMouseenterStation"
    "mouseleave":        "onMouseleaveStation"
    "click .iconbutton": "onClickDetail"
    "mouseenter .iconbutton": "onMouseenterDetail"
    "mouseleave .iconbutton": "onMouseleaveDetail"
    StationBaseView.prototype.events

  # 距離の変換
  formatDistance: (num) ->
    if (num > 999)
      result = (Math.round(num / 10) / 100).toString().replace(/^(-?\d+)(\d{3})/,"$1,$2")
      """<span class="number">#{result}km</span>"""
    else
      """<span class="number">#{num}m</span>"""

  ### on Model event ###
  # 各車情報の表示
  renderContents: ->
    super()
    @$el
      .find("img").remove().end()
      .find("div.ui-icon-close").show()

  # 直線距離の表示
  renderDistanceS: ->
    if (@model.has("distanceS"))
      @$("div.straight").html(@formatDistance(@model.get("distanceS")))
      @$(".distance.s1").text("")
      @$(".distance.s2").text("")
    else
      @$("div.straight").text("")
      @$(".distance.s1").text("徒歩:")
      @$(".distance.s2").text("/")

  # 徒歩距離の表示
  renderDistanceW: ->
    if (@model.has("route"))
      @$("div.straight").html(@formatDistance(@model.get("distanceS")))
      @$("div.walk").html(@formatDistance(@model.get("distanceW")))
      @$(".distance.s1").text("徒歩:")
      @$(".distance.s2").text("/")
    else
      @$("div.walk").text("")
      @$("div.straight").text("")
      @$(".distance.s1").text("")
      @$(".distance.s2").text("")

  # 順序の表示
  renderOrderNum: ->
    if (@model.get("distanceS"))
      ordernum = @model.get("ordernum")
    else
      ordernum = 0
    @$("span.ordernum").text(ordernum)
    @$el.parent().parent().children().eq(ordernum).append(@$el)
    if (@$el.parent().hasClass("hide"))
      @model.set {disabled: true}
    else
      @model.set {disabled: false}

  ### on Collection event ###
  onSelectStation: (id, whichSelect) ->
    if (id is @model.id)
      @$el.addClass("hilite")
      if (whichSelect is "marker")
        @$el.scrollintoview(50)
    else
      @$el.removeClass("hilite")

  onHoverStation: (hovered, id, whichSelect) ->
    if (id is @model.id)
      if (hovered) then @$el.addClass("hover") else @$el.removeClass("hover")
      if (whichSelect is "marker")
        @$el.scrollintoview(50)
    else
      @$el.removeClass("hover")

  ### on DOM event ###
  onClickStation: (event) ->
    @model.collection.trigger "selectStation", @model.id, "listItem"

  onMouseenterStation: ->
    @model.collection.trigger "hoverStation", true, @model.id, "listItem"

  onMouseleaveStation: ->
    @model.collection.trigger "hoverStation", false, @model.id, "listItem"

  onClickDetail: (event) ->
    $(event.currentTarget).parents("table:first").find("tr:has(th)").slideToggle()

  onMouseenterDetail: (event) ->
    if ($(event.currentTarget).hasClass("iconbutton"))
      $(event.currentTarget)
        .addClass("detailActive")
        .find("span").addClass("uiIconActive")

  onMouseleaveDetail: (event) ->
    if ($(event.currentTarget).hasClass("iconbutton"))
      $(event.currentTarget)
        .removeClass("detailActive")
        .find("span").removeClass("uiIconActive")

  onClickDelStation: (event) ->
    collection = @model.collection
    super(event)
    collection.trigger "doneRenderDistance"

class tp.SortableStationView extends SortableStationBaseView

  renderContents: ->
    super()
    @model.get("deferred").resolve()

class tp.SortableRouteStationView extends SortableStationBaseView

  renderDistanceW: ->
    super()
    @model.get("deferred").resolve()


# 受信HTML解析・送信フォームデータ作成ワーク用オンメモリDOMビュー
RequestDataView = Backbone.View.extend

  url: "https://share.timescar.jp/view/reserve/input.jsp"

  initialize: (options) ->
    @id = @model.id
    @model.on
      "requestReservePage": @onRequestReservePage
      "change:timetables":  @onChangeTimetables
      "remove":             @onRemove
      @

  ### on Model event ###
  # el, events, 自身の削除
  onRemove: ->
    @model.collection.off null, null, @
    @model.off null, null, null
    @off null, null, null
    @remove()

  onRequestReservePage: (carId) ->
    sdate = ~~$("#selectDate").val().replace(/-/g, "").substring(0, 8)
    sdate = sdate * 10000 + ~~$("#selectHour").val() * 100
    formTemplate = """
      <form method="GET" action="#{@url}" target="_blank">
        <input type="hidden" name="scd" value="#{@model.id}">
        <input type="hidden" name="carId" value="#{carId}">
        <input type="hidden" name="sdate" value="#{sdate}">
        <input type="hidden" name="edate" value="#{sdate}">
      </form>
      """
    $(formTemplate).appendTo($("#form").empty()).submit()
  
  onChangeTimetables: ->
    stationInfo = @model.get("stationInfo")
    if (stationInfo)
      @updateContents(stationInfo)
    else
      @doAjaxLoad()

  ### instance method/property ###
  updateContents: (stationInfo) ->
    contents = []
    $.each @model.get("timetables"), (scd, div) =>
      cardesc = stationInfo.cardesc[div[0].id]
      if not cardesc or Object.keys(cardesc).length is 0
        return
      # div[0].dataset.color = /（(.+)）$/.exec(cardesc[0])?[1]
      div[0].dataset.color = "ホワイト"
      m = {}
      [m.carname, m.clas, m.capa, m.color, m.limit, m.charge, m.maxcharge, m.tpnavi, m.navimodel, m.note] = cardesc
      contents.push div.find("table tr:first").before(@template(m)).end()[0].outerHTML
    @model.set {contents: contents}
    @model.unset "timetables", {silent: true}

  doAjaxLoad: ->
    $.ajax
      type: "GET"
      url: @url + "?scd=#{@id}"
    .done (resp) =>
      if (/<input type='hidden' name='te-conditions' value='.*' \/>/.test resp)
        resp$ = $(resp)
        stationName = resp$.find("span[id='stationNm']").text()
        timetables = resp$.find("""span[id="timetableHtmlTag"]""").children()
        stationInfo = @updateLocalDB stationName, timetables
        @updateContents(stationInfo)
      else
        tp.alert "データを取得できませんでした。<br><br>タイムアウトの可能性があります。<br>" +
          "マイページトップを再読み込みしてください。"
        @model.set error: "Error: タイムアウトが発生しました。"
    .fail =>
      tp.alert "データを取得できませんでした。<br><br>" +
        "ログインされていない可能性があります。"
      @model.set error: "Error: ログインされていない可能性があります。"

  updateLocalDB: (stationName, timetables) ->
    stationInfo = {}
    name = @model.get("name")
    if (/^Station\s\d+$/.test name)
      @model.set
        name: stationName
        alias: stationName
    else
      stationName = name
      unless (stationName is (alias = @model.get("alias")))
        stationInfo.alias = alias
    stationInfo.name = stationName
    stationInfo.latlng = @model.get("latlng")
    stationInfo.cardesc = {}
    $.each timetables, (i, elem) ->
      car$ = $(elem)
      car$.find("table.time").find("tr:not(:has(th))").remove()
      carname = car$.find("p").find("span").remove().end().text()
      cardesc = [carname]
      $.each car$.find("td"), (i, elem) ->
        cardesc.push $(elem).text()
      stationInfo.cardesc[elem.id] = cardesc
    @model.set {stationInfo: stationInfo}
    @model.collection.trigger "updateLocalDB", @id, stationInfo
    stationInfo

  template: _.template """
    <tr class="detail">
      <th colspan="10">クラス</th>
      <td colspan="14"><%= clas %></td>
      <th colspan="10">定員</th>
      <td colspan="14"><%= capa %></td>
    </tr>
    <tr class="detail">
      <th colspan="10">駆動</th>
      <td colspan="14"><%= color %></td>
      <th colspan="10">現在の燃料残目安</th>
      <td colspan="14"><%= limit %></td>
    </tr>
    <tr class="detail">
      <th colspan="10">安全装備</th>
      <td colspan="38"><%= charge %></td>
    </tr>
    <tr class="detail">
      <th colspan="10">備考</th>
      <td colspan="38"><%= note %></td>
    </tr>
    """

# ステーションウィンドウのモデルのコレクションのビュー基底クラス
StationSetBaseView = Backbone.View.extend

  el: "#stations_block"

  initialize: (options) ->
    @model.on
      "change:selectDate": "onChangeSelectDate"
      "change:selectHour": "onChangeSelectDate"
      @
    @collection.on
      "add":  @onAddRender
      "updateLocalDB": @onUpdateLocalDB
      @
    tp.atwith tp.activity.misc, @

  events:
    "click button.newtimetable":      "onClickReload"
    "change #selectDate,#selectHour": "onChangeDomSelectDate"

  render: ->
    @$el.append @template
    @trigger "getSelectDateHour", container = {}
    @$("#selectDate").html(container.selectDate.html()).change()
    @$("#selectHour").html(container.selectHour.html()).val((new Date).getHours()).change()
    @

  doTeedaAjax: (options) ->
    @trigger "getCenterLatLng", container = {}
    unless (latlng = container.latlng)
      return
    requestDateHour = @model.get("selectDateHour")
    date = (requestDateHour?.date || "")
    hour = (requestDateHour?.hour || "")
    startSearch = ""
    if (requestDateHour)
      startSearch = date.substring(0, 10).replace(/-0/g, "-") + " " + hour + ":00:00"
      sDate = ""
    else
      date = new Date()
      startSearch = [date.getFullYear(), date.getMonth() + 1, date.getDate()].join("-") + " " + date.getHours() + ":00:00"
      date.setMilliseconds(0)
      date.setSeconds(0)
      date.setMinutes(0)
      sDate = date.getTime()
    unless (options?.changeTimetable)
      @collection.comparator = (model) =>
        model.get("distanceS")
      @collection.sort(silent: true)
    lon = Math.round(latlng.lng() * 10000000) / 10000000 - tp.ptAdjust
    lat = Math.round(latlng.lat() * 1000000) / 1000000 - tp.ptAdjust
    allTargets = []
    $.each @collection.models, (x, model) ->
      if (model.get("deferred").state() is "pending")
        latlng = model.get("latlng")
        allTargets.push
          scd: model.id
          lon: Math.round(latlng.lng() * 10000000) / 10000000
          lat: Math.round(latlng.lat() * 1000000) / 1000000
    formData =
      component: "station_stationMapPage"
      action:    "ajaxCreateTimeTable"
      time:      encodeURIComponent((new Date()).toString())
      lonAjax:       ""
      latAjax:       ""
      stationCdAjax: ""
      centerLon: lon
      centerLat: lat
      startSearch: startSearch
      dateSpace: date
      hourSpace: hour
      useHour: 0
      useMinute: 0
      sDate: sDate
      eDate: sDate
      mainteCard: false
      method: "POST"
    @doAjaxThing formData, allTargets, options

  doAjaxThing: (formData, allTargets, options) ->
    targets = []
    if (allTargets.length > 0)
      for i in [1..Math.min(5, allTargets.length)]
        targets.push allTargets.shift()
      [formData.stationCdAjax, formData.lonAjax, formData.latAjax] =
        [(_.pluck targets, "scd").join() + ",", (_.pluck targets, "lon").join() + ",", (_.pluck targets, "lat").join() + ","]
      $.ajax
        url: "https://share.timescar.jp/view/station/teeda.ajax"
        method: "POST"
        data: formData
      .done (resp) =>
        @doneAjaxThing resp, targets
        @doAjaxThing(formData, allTargets, options)
    else
      if options?.changeTimetable
        $.each @collection.models, (i, model) ->
          if (dfd = model.get("deferred")).state() is "pending"
            dfd.resolve()

  doneAjaxThing: (resp, targets) ->
    timetablesSet = {}
    $.each $("<div>").append($(resp)).find("div.tableoff"), (i, elem) ->
      target = $(elem)
      scd = /openPop\('(.*)'\)/.exec((tagA = target.find("a")).attr("onclick"))[1]
      carname = tagA.text()
      target.find("p").empty().text(carname)
      (timetablesSet[scd] || timetablesSet[scd] = {})[elem.id] = target
    @trigger "getLocalDB", container = {}
    $.each targets, (i, target) =>
      timetables = timetablesSet[target.scd]
      stationInfo = container.localDB[target.scd]
      if (timetables && stationInfo)
        a = _.keys(stationInfo.cardesc || {})
        b = _.keys(timetables)
        diff = _.difference(a, b).concat _.difference(b, a)
        unless (diff.length is 0)
          stationInfo = null
      @collection.get(target.scd).set
        timetables: timetables || []
        stationInfo: stationInfo

  ### on Collection event ###
  onAddRender: (model, collection, options) ->
    stationView = new tp[@options.stationViewClassName] model: model
    @$("div.stations").append $("<div>").append stationView.render().$el
    new RequestDataView {model: model}

  onDoneReadyLoads: (options) ->
    @$("div.divInputSelect")
      .find("select,button,a").attr("disabled", "disabled")
    @doTeedaAjax(options)

  onDoneLoads: ->
    @$("div.divInputSelect").find("select,button:not(.nextsta)").removeAttr("disabled")

  onUpdateLocalDB: (scd, station) ->
    @trigger "updateLocalDB", scd, station

  ### on DOM event ###
  # 新タイムテーブル読み込み
  onClickReload: ->
    @trigger "setDirectionWaitIcon", true
    @trigger "changeTimetable", {changeTimetable: true}

  onChangeDomSelectDate: (event) ->
    @model.set
      selectDateHour:
        date: @$("#selectDate").val()
        hour: @$("#selectHour").val()

  onChangeSelectDate: ->
    @$("#selectDate").val(@model.get("selectDate"))
    @$("#selectHour").val(@model.get("selectHour"))

  onClickSelectHour: ->
    @$("#selectHour").toggle()

  template: """
    <div class="divInputSelect">
      <select id="selectDate"></select>
      <select id="selectHour"></select><button class="newtimetable small square" disabled="disabled" title="更新"><i class="icon-repeat"></i> 更新</button>
    </div>
    <div class="stations custom-scroll-bar">
    </div>
    """

# マップあり基底クラス
class StationSetMapBaseView extends StationSetBaseView

  constructor: (options) ->
    super(options)
    @collection.on
      "hoverStation":  @onHoverStation
      @

  events: _.extend
    "mousedown div.vsplitbar": "onVsplitterMouseDown"
    "mouseup   div.vsplitbar": "onVsplitterMouseUp"
    StationSetBaseView.prototype.events

  render: ->
    super()
    $("""<div class="vsplitbar"></div>""").insertBefore @$("div:first")
    @style = $("<style>", {type:"text/css"}).appendTo($("head"))[0].sheet
    @$(".vsplitbar")
    .draggable
      axis: "x"
      cursor: "e-resize"
      start: @onSplitStart.bind(@)
      drag: @onSplitDrag.bind(@)
      stop: @onSplitStop.bind(@)

  ### on DOM event ###
  onHoverStation: (hovered, id, whitch) ->
    if (!hovered && whitch is "marker")
      if (selectedModels = @collection.where {selected: true}).length > 0
        @collection.trigger "selectStation", selectedModels[0].id, "marker"

  onSplitStart: (event, ui) ->
    @$el.removeAttr("style")
    @dragStartLeft = ui.position.left

  onSplitDrag: (event, ui) ->
    addEm = Math.round((@dragStartLeft - ui.position.left) / 100) * 5 / 100
    if (Math.abs(addEm) > 0)
      tmp = Math.round((@tdPaddingEm + addEm) * 100) / 100
      if (0.2 <= tmp <= 0.5)
        @style.deleteRule(0)
        @style.addRule ".timetable th,.timetable td", "padding:#{(@tdPaddingEm = tmp)}em"
        @dragStartLeft = ui.position.left

  onSplitStop: (event, ui) ->
    @$("div.vsplitbar").removeAttr("style")
    @$el.width(@$el.width())
    @trigger "doneDragSplitter"

  onVsplitterMouseDown: ->
    @$("div.vsplitbar").addClass("drag")

  onVsplitterMouseUp: ->
    @$("div.vsplitbar").removeClass("drag")

  ### on Object event ###
  onSetStationWidth: (container) ->
    @style.addRule ".timetable th,.timetable td", "padding:#{(@tdPaddingEm = container.tdPaddingEm * 1)}em"
    @$el.width(container.divStationsWidth)

  onGetStationWidth: (container) ->
    container.tdPaddingEm = Math.round(@tdPaddingEm * 100) / 100
    container.divStationsWidth = @$el.width()

# インスタンス化クラス

# お気に入りモードマップなし
class tp.StationSetNomapView extends StationSetBaseView

  constructor: (options) ->
    super(options)
    @$el.addClass("nomap")
　
# お気に入りモードマップあり
class tp.StationSetView extends StationSetMapBaseView

# マップ検索モード 直線距離順
class tp.SortableStationSetView extends StationSetMapBaseView

  events: _.extend
    "click a.nextsta": "onClickNextSta"
    StationSetMapBaseView.prototype.events

  sortFieldName: "distanceS"

  constructor: (options) ->
    super(options)
    @collection.on
      "sort":               @onSortRender
      "doneRenderDistance": @onDoneRenderDistance
      "enableNextSta":      @enableNextSta
      @

  render: ->
    super()
    @$("div.divInputSelect").append """<a href="javascript:void(0)" class="nextsta" disabled="disabled">次順追加<i class="icon-plus"></i></a>"""
    @elHideStations = $("<div>", {"class": "hide"}).appendTo(@$(".stations"))
    for i in [0...@options.searchMargin]
      @$(".stations").append $("<div>", {"class": "hide"})
    @addDivs()
    @

  addDivs: ->
    addCount = i = Math.min(@selectListMax, Math.max(0, @dispMax - @$(".stations > div:not(.hide)").length))
    while i--
      @elHideStations.after "<div/>"
    addCount

  refreshDivs: ->
    @$(".stations > div:not(.hide)").remove()
    @addDivs()

  enableNextSta: (force) ->
    unless @$(".stations > div:not(.hide)").length >= @dispMax && !force
      @$("div.divInputSelect a.nextsta").removeAttr("disabled")

  onAddRender: (model, collection, options) ->
    model.set {disabled: true}
    stationView = new tp[@options.stationViewClassName] model: model
    @elHideStations.append stationView.render().$el
    new RequestDataView {model: model}

  onSortRender: (collection, options) ->
    index = 1
    $.each collection.models, (i, model) =>
      distance = model.get(@sortFieldName)
      if (distance)
        if (@selectRangeFrom * 1000 <= distance <= @selectRangeTo * 1000)
          ordernum = index++
        else
          ordernum = 0
      else
        ordernum = 0
      model.set {ordernum: ordernum}, {silent: true}
      model.trigger "change:ordernum"

  onDoneRenderDistance: ->
    @collection.comparator = (model) =>
      model.get(@sortFieldName)
    @collection.sort()

  onDoneLoads: ->
    @onDoneRenderDistance()
    super()
    targets = _.filter @collection.models, (model) =>
      distance = model.get(@sortFieldName)
      if (distance)
        if (@selectRangeFrom * 1000 <= distance <= @selectRangeTo * 1000)
          return true
      false
    if (targets.length is 0)
      tp.alert "徒歩ルートで#{@selectRangeTo}km以内にステーションが見つかりませんでした。"

  onClickNextSta: (event) ->
    unless $(event.currentTarget).attr("disabled") is "disabled"
      @trigger "addStations", @addDivs()

# マップ検索モード 徒歩距離順
class tp.SortableRouteStationSetView extends tp.SortableStationSetView

  sortFieldName: "distanceW"


# オブジェクトをContextに紐付
tp.atwith = (parent, ctx, prefix = "") ->
  $.each parent, (key, value) => ctx[prefix + key] = value

# アラートダイアログ
tp.alert = (text) ->
  templateDialog = _.template """
    <div>
      <!-- <div class="dialogTitle"><%= title %></div> -->
      <i class="icon-remove" style="float: right;cursor: pointer;"></i>
      <div class="dialogContent">
        <i class="icon-warning-sign" style="float:left;margin-right:4px"></i>
        <div style="overflow:auto"><%= content %></div>
      </div>
      <div class="buttons">
        <button class="buttonYes">OK</button>
      </div>
    </div>
    """
  $("#dialog").html templateDialog
    title: ""
    content: text
  $.facybox div: "#dialog"
  $("#facybox")
    .draggable
      handle: "div.dialogTitle"
      cursor: "move"
    .find("button,i.icon-remove").on "click", ->
      $(document).trigger "close.facybox"
