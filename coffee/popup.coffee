$ = jQuery
$ ->
  # 汎用モデル
  PlainModel = Backbone.Model.extend {}
  # ステーションモデル
  StationModel = Backbone.Model.extend
    idAttribute: "scd"
  # ステーションコレクション
  StationCollection = Backbone.Collection.extend
    model: StationModel
    comparator: (model) ->
      model.get("ordernum")
  # その他設定デフォルト値
  OptionsMiscModel = Backbone.Model.extend
    defaults:
      tabid: 0
      centerAddress: ""
      centerAddressFav: ""
      selectRangeFrom: 0.0
      selectRangeTo: 3.0
      selectListOrder: "WALKING"
      selectListMax: "5"
      checkMap: true
      dispMax: 15
      mapRouteRetryTimes: 4
      mapRouteWaitMSec: 2000

  # 検索タブ
  SearchTabView = Backbone.View.extend

    # 検索最大数
    SelectMaxListView: Backbone.View.extend
      el: "#selectListMax"
      events: "change": "onChange"
      initialize: (options) ->
        for i in [1..7]
          @$el.append($("<option />", {value: i, text: i}))
        @$el.val(@model.get("selectListMax"))
        @model.on "change:selectListMax", @onChangeSelectListMax, @
      onChange: ->
        @model.set {selectListMax: @$el.val()}
      onChangeSelectListMax: ->
        @$el.val(@model.get("selectListMax"))

    # 並び順Select
    SelectSearchOrder: Backbone.View.extend
      el: "#selectListOrder"
      events: "change": "onChange"
      initialize: ->
        @$el.val(@model.get("selectListOrder"))
        @model.on "change:selectListOrder", @onChangeSelectSearchOrder, @
      onChange: ->
        @model.set {selectListOrder: @$el.val()}
      onChangeSelectSearchOrder: ->
        @$el.val(@model.get("selectListOrder"))

    # 初期化
    initialize: ->
      new @SelectMaxListView model: @model
      new @SelectSearchOrder model: @model

  # お気に入りタブ
  FavoriteTabView = Backbone.View.extend

    # ステーション
    StationView: Backbone.View.extend
      el: "<tr/>"
      initialize: ->
        @model.on "change:checked", @renderOnChecked, @
      render: ->
        @$el.html @template(@model.toJSON())
        @
      renderOnChecked: ->
        if (@model.get("checked"))
          @$("i.icon-ok").addClass("checked")
        else
          @$("i.icon-ok").removeClass("checked")
      template: _.template """
        <td>
          <i class="icon-ok<% if (checked) { %> checked<% } %>"></i>
          <div class="station" title="<%= place %>"><%= alias %></div>
          <input type="hidden" value="<%= scd %>">
        </td>
        """

    # ステーションリストView has Selectable,Sortable,Editable
    StationsView: Backbone.View.extend
      el: "#listitem"
      events:
        "click td": "onClick"
      initialize: ->
        @collection.on "add", @render, @
        @$el.sortable
          delay: 150
          disabled: false
          handle: "div,label,td"
          cursor: "pointer"
          helper: "clone"
          scroll: false
          start: (event, ui) =>
            @$("tr.ui-sortable-placeholder").append('<td><div class="ui-icon ui-icon-triangle-1-e"></div></td>')
            @$("label").css("cursor", "pointer")
          stop: (event, ui) =>
            @$("label").css("cursor", "default")
            @$("tr").each (i, elem) =>
              scd = $(elem).find("input").val()
              @collection.get(scd).set {ordernum: i}
            @collection.sort()
          update: (event, ui) =>
            @$el
      render: (model) ->
        @$el.append((new @options.StationView({model: model})).render().$el)
      checkAll: (checked) ->
        @collection.each (model) =>
          model.set {checked: checked}
      onClick: (event) ->
        scd = (parent$ = $(event.currentTarget)).find("input").val()
        if (model = @collection.get(scd))
          target = parent$.find("i.icon-ok")
          if (target.hasClass("checked"))
            target.removeClass("checked")
            checked = false
          else
            checked = true
            target.addClass("checked")
          model.set {checked: checked}, {silent: true}
      # 編集モード
      switchModeEdit: ->
        enable = !(@$("input:text").length > 0)
        if (enable)
          # case ON
          width = @$("td:first").width()
          @$("td").each ->
            label = $(@).css("padding", "0.2em 0.3em").find("div.station")
            text = label.text()
            title = label.attr("title")
            forid = $(@).find("input").val()
            label.replaceWith(
              $("<input />",
                  type: "text"
                  value: text
                  title: title
                  id: "chk" + forid)
              .width(width)
              .css("border", "1px solid #9999FF")
            )
          $("doit").attr("disabled", "disabled")
          @$("i.icon-ok,fieldset,div.iconbutton").hide()
        else
          # case OFF
          @$("td").each ->
            alias$ = $(@)
              .css("padding", "")
              .css("padding-right", "2em")
              .find("input:text")
            if $.trim(alias$.val()) is ""
              alias = alias$.attr("title")
            else
              alias = alias$.val()
            alias$.replaceWith(
              $("<div />",
                class: "station"
                title: alias$.attr("title")
                text: alias
              )
            )
          $("doit").removeAttr("disabled")
          @$("i.icon-ok,fieldset,div.iconbutton").show()
          $.each @collection.models, (i, model) =>
            model.set
              alias: @$("td").find("input[value='#{model.id}']").parent().find("div.station").text()

    # すべて選択ボタン
    AllChkButtonView: Backbone.View.extend
      el: "div.iconbutton"
      events:
        "click": "onClick"
      onClick: ->
        @$el.toggleClass("checked")
        @trigger "checkAll", @$el.hasClass("checked")

    # 編集ボタン
    SettingButtonView: Backbone.View.extend
      el: "i.icon-edit"
      events:
        "click": "renderOnClick"
      renderOnClick: ->
        @trigger "switchModeEdit"
        false

    # 初期化
    initialize: ->
      @stationsView = new @StationsView
        collection: new StationCollection()
        StationView: @StationView
      allChkButtonView = new @AllChkButtonView()
      settingButtonView = new @SettingButtonView()
      allChkButtonView.on  "checkAll"      , @stationsView.checkAll      , @stationsView
      settingButtonView.on "switchModeEdit", @stationsView.switchModeEdit, @stationsView


  # メインページビュー
  MainView = Backbone.View.extend

    el: "body"

    events: "click": "onClick"

    onClick: -> @$("#divPanel").hide()

    # タブの処理
    TabView: Backbone.View.extend
      initialize: ->
        @model.on "change:tabid", @onChangeTabid, @
      events:
        "click": "renderOnClick"
      renderOnClick: ->
        @model.set {tabid: @options.index}
      onChangeTabid: ->
        if (@model.get("tabid") is @options.index)
          @setCurrentTab()
      setCurrentTab: ->
        @trigger "reset"
        $("div.tabPanel").eq(@options.index)
          .show()
          #.find("fieldset.inputAddress").append @options.inputCenterAddress.$el
          @$el.addClass("current")

    TabsView: Backbone.View.extend
      el: "ul.tabs li"
      initialize: ->
        inputCenterAddress = new @options.InputCenterAddress model: @model
        inputCenterAddressFav = new @options.InputCenterAddressFav model: @model
        @$el.each (i, el) =>
          new @options.TabView
            model: @model
            el: el
            index: i
            inputCenterAddress: inputCenterAddress
          .on "reset", @reset, @
        @model.trigger "change:tabid"
      reset: ->
        $("div.tabPanel").hide()
        @$el.removeClass("current")

    InputCenterAddress: Backbone.View.extend
      el: "#centerAddress"
      initialize: ->
        @$el.val(@model.get("centerAddress") || "")
        @$el.on "change", @onChange.bind(@)
        @model.on "change:centerAddress", @onChangeCenterAddress, @
      onChange: ->
        @model.set {centerAddress: @$el.val()}
      onChangeCenterAddress: ->
        @$el.val(@model.get("centerAddress"))

    InputCenterAddressFav: Backbone.View.extend
      el: "#centerAddressFav"
      initialize: ->
        @$el.val(@model.get("centerAddressFav") || "")
        @$el.on "change", @onChange.bind(@)
        @model.on "change:centerAddressFav", @onChangeCenterAddress, @
      onChange: ->
        @model.set {centerAddressFav: @$el.val()}
      onChangeCenterAddress: ->
        @$el.val(@model.get("centerAddressFav"))

    # 閉じるボタン
    CloseButtonView: Backbone.View.extend
      el: "i.icon-remove"
      events:
        "click": "onClick"
        # "mouseenter": "renderOnMouseenter"
        # "mouseleave": "renderOnMouseleave"
      onClick: ->
        window.close()
      # renderOnMouseenter: ->
      #   @$el.css("background-image", "url(css/images/ui-icons_228ef1_256x240.png)")
      # renderOnMouseleave: ->
      #   @$el.css("background-image", "")

    # 開始ボタン
    StartButtonView: Backbone.View.extend
      el: "form.inputForm"
      events: "click #doit": "onSubmit"
      onSubmit: ->
        activity = mainView.getActivity()
        if activity.misc.tabid is tp.tabidFavorite
          # お気に入りモード時
          checkedList = $.grep activity.favs, (elem) -> elem.checked
          if (checkedList.length is 0)
            return @showAlert("div.tabFavorite table tr:first", "チェックされていません")
          activity.misc.centerAddress = activity.misc.centerAddressFav
        activity.misc.centerAddress = $.trim activity.misc.centerAddress
        chrome.tabs.getSelected null, (tab) ->
          if (/newtab.html/.test tab.url)
            uidparams = /[\\?&]uid=([^&#]*)/.exec tab.url
            tp.setActivity uidparams[1], activity
            chrome.tabs.sendMessage tab.id, "restart"
          else
            tp.createNewTab activity
          window.close()
      setEnable: ->
        @$("#doit").removeAttr("disabled").removeClass("disabled").focus()
      showAlert: (selector, msg) ->
        mainView.alertView.setElement selector
        mainView.alertView.model.set {contents: msg}
        false

    # アラートポップアップ
    AlertView: Backbone.View.extend
      initialize: ->
        $.balloon.defaults.classname = "balloon"
        $.balloon.defaults.position = "top"
        $.balloon.defaults.css =
          "font-size": "75%"
          "white-space": "normal"
          minWidth: "20px"
          padding: "5px"
          borderRadius: "6px"
          border: "solid 1px #777"
          boxShadow: "4px 4px 4px #555"
          color: "#333"
          backgroundColor: "#FFC"
          opacity: "1"
          zIndex: "32767"
          textAlign: "left"
        @model.on "change", @render, @
      render: ->
        @$el.showBalloon(@model.toJSON()).focus()
        setTimeout("$(\"" + @$el.selector + "\").hideBalloon()", 2000)
        @model.clear {silent: true}

    #function getActivity() 現在の設定を取得
    getActivity: ->
      activity = {}
      activity.favs = @favoriteTabView.stationsView.collection.toJSON()
      activity.misc = @miscModel.toJSON()
      activity

    # 初期化
    initialize: ->

      # その他View
      @miscModel = new OptionsMiscModel()
      new @TabsView
        model: @miscModel
        TabView: @TabView
        InputCenterAddress: @InputCenterAddress
        InputCenterAddressFav: @InputCenterAddressFav
      new SearchTabView model: @miscModel
      @favoriteTabView = new FavoriteTabView model: @miscModel
      new @CloseButtonView()
      @startButtonView = new @StartButtonView()
      @alertView = new @AlertView {model: new PlainModel()}

      $(window).on "unload", @onWindowUnload.bind(@)

    # Popup終了時編集SCDリスト保存
    onWindowUnload: ->
      @favoriteTabView.stationsView.switchModeEdit(false)
      activity = @getActivity()
      localStorage.myfavs = JSON.stringify(activity)
      # scd情報オブジェクト更新
      $.each activity.favs, (i, station) ->
        if savedStation = tp.getLocalDB(station.scd)
          savedStation.alias = station.alias
          tp.setLocalDB station.scd, savedStation
        else
          savedStation = {}
          savedStation.alias = station.alias
          savedStation.name  = station.place
          tp.setLocalDB station.scd,  savedStation

    # App start point
    run: ->
      # ページお気に入りリストから取得
      favorites = tp.getFavorites().slice(0)
      storageData = {}
      if (localStorage.myfavs || (localStorage.myfavs = localStorage.myscd))
        # 保存SCDリストのチェック
        storageData = JSON.parse(localStorage.myfavs)
        # 旧設定対応
        if (storageData.scdList)
          storageData.favs = storageData.scdList
          delete storageData.scdList

      # 保存ステーションリストから取得
      if (storageData.favs)
        $.each storageData.favs, (i, station) =>
          station.place = "不明"
          $.each favorites, (j, favorite) ->
            if (station.scd is favorite.scd)
              # station.name = favorite.name
              station.place = favorite.place
              favorites.splice(j, 1)
              return false
          if station.place isnt "不明"
            @favoriteTabView.stationsView.collection.push station

      # 保存SCDリストがないとき、または新たに追加されたとき、初期SCDリストからセットされる
      $.each favorites, (i, favorite) =>
        @favoriteTabView.stationsView.collection.push favorite

      # その他保存設定
      @miscModel.set storageData.misc || {}

      chrome.tabs.getSelected null, (tab) =>
        if (/newtab.html/.test tab.url)
          chrome.tabs.sendMessage tab.id, "requestStartTrigger", (resp) =>
            if (resp is "ok")
              @startButtonView.setEnable()
        else
          @startButtonView.setEnable()

  # App start
  tp = chrome.extension.getBackgroundPage().window.tp

  mainView = new MainView()
  mainView.run()
  @
