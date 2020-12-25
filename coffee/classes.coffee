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
      target = div.find("table tr:first")
      if target.length is 0
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
