// Generated by CoffeeScript 1.12.7
(function() {
  var $;

  $ = jQuery;

  $(function() {
    var FavoriteTabView, MainView, OptionsMiscModel, PlainModel, SearchTabView, StationCollection, StationModel, mainView, tp;
    PlainModel = Backbone.Model.extend({});
    StationModel = Backbone.Model.extend({
      idAttribute: "scd"
    });
    StationCollection = Backbone.Collection.extend({
      model: StationModel,
      comparator: function(model) {
        return model.get("ordernum");
      }
    });
    OptionsMiscModel = Backbone.Model.extend({
      defaults: {
        tabid: 0,
        centerAddress: "",
        centerAddressFav: "",
        selectRangeFrom: 0.0,
        selectRangeTo: 3.0,
        selectListOrder: "WALKING",
        selectListMax: "5",
        checkMap: true,
        dispMax: 15,
        mapRouteRetryTimes: 4,
        mapRouteWaitMSec: 2000
      }
    });
    SearchTabView = Backbone.View.extend({
      SelectMaxListView: Backbone.View.extend({
        el: "#selectListMax",
        events: {
          "change": "onChange"
        },
        initialize: function(options) {
          var i, k;
          for (i = k = 1; k <= 7; i = ++k) {
            this.$el.append($("<option />", {
              value: i,
              text: i
            }));
          }
          this.$el.val(this.model.get("selectListMax"));
          return this.model.on("change:selectListMax", this.onChangeSelectListMax, this);
        },
        onChange: function() {
          return this.model.set({
            selectListMax: this.$el.val()
          });
        },
        onChangeSelectListMax: function() {
          return this.$el.val(this.model.get("selectListMax"));
        }
      }),
      SelectSearchOrder: Backbone.View.extend({
        el: "#selectListOrder",
        events: {
          "change": "onChange"
        },
        initialize: function() {
          this.$el.val(this.model.get("selectListOrder"));
          return this.model.on("change:selectListOrder", this.onChangeSelectSearchOrder, this);
        },
        onChange: function() {
          return this.model.set({
            selectListOrder: this.$el.val()
          });
        },
        onChangeSelectSearchOrder: function() {
          return this.$el.val(this.model.get("selectListOrder"));
        }
      }),
      initialize: function() {
        new this.SelectMaxListView({
          model: this.model
        });
        return new this.SelectSearchOrder({
          model: this.model
        });
      }
    });
    FavoriteTabView = Backbone.View.extend({
      StationView: Backbone.View.extend({
        el: "<tr/>",
        initialize: function() {
          return this.model.on("change:checked", this.renderOnChecked, this);
        },
        render: function() {
          this.$el.html(this.template(this.model.toJSON()));
          return this;
        },
        renderOnChecked: function() {
          if (this.model.get("checked")) {
            return this.$("i.icon-ok").addClass("checked");
          } else {
            return this.$("i.icon-ok").removeClass("checked");
          }
        },
        template: _.template("<td>\n  <i class=\"icon-ok<% if (checked) { %> checked<% } %>\"></i>\n  <div class=\"station\" title=\"<%= place %>\"><%= alias %></div>\n  <input type=\"hidden\" value=\"<%= scd %>\">\n</td>")
      }),
      StationsView: Backbone.View.extend({
        el: "#listitem",
        events: {
          "click td": "onClick"
        },
        initialize: function() {
          this.collection.on("add", this.render, this);
          return this.$el.sortable({
            delay: 150,
            disabled: false,
            handle: "div,label,td",
            cursor: "pointer",
            helper: "clone",
            scroll: false,
            start: (function(_this) {
              return function(event, ui) {
                _this.$("tr.ui-sortable-placeholder").append('<td><div class="ui-icon ui-icon-triangle-1-e"></div></td>');
                return _this.$("label").css("cursor", "pointer");
              };
            })(this),
            stop: (function(_this) {
              return function(event, ui) {
                _this.$("label").css("cursor", "default");
                _this.$("tr").each(function(i, elem) {
                  var scd;
                  scd = $(elem).find("input").val();
                  return _this.collection.get(scd).set({
                    ordernum: i
                  });
                });
                return _this.collection.sort();
              };
            })(this),
            update: (function(_this) {
              return function(event, ui) {
                return _this.$el;
              };
            })(this)
          });
        },
        render: function(model) {
          return this.$el.append((new this.options.StationView({
            model: model
          })).render().$el);
        },
        checkAll: function(checked) {
          return this.collection.each((function(_this) {
            return function(model) {
              return model.set({
                checked: checked
              });
            };
          })(this));
        },
        onClick: function(event) {
          var checked, model, parent$, scd, target;
          scd = (parent$ = $(event.currentTarget)).find("input").val();
          if ((model = this.collection.get(scd))) {
            target = parent$.find("i.icon-ok");
            if (target.hasClass("checked")) {
              target.removeClass("checked");
              checked = false;
            } else {
              checked = true;
              target.addClass("checked");
            }
            return model.set({
              checked: checked
            }, {
              silent: true
            });
          }
        },
        switchModeEdit: function() {
          var enable, width;
          enable = !(this.$("input:text").length > 0);
          if (enable) {
            width = this.$("td:first").width();
            this.$("td").each(function() {
              var forid, label, text, title;
              label = $(this).css("padding", "0.2em 0.3em").find("div.station");
              text = label.text();
              title = label.attr("title");
              forid = $(this).find("input").val();
              return label.replaceWith($("<input />", {
                type: "text",
                value: text,
                title: title,
                id: "chk" + forid
              }).width(width).css("border", "1px solid #9999FF"));
            });
            $("doit").attr("disabled", "disabled");
            return this.$("i.icon-ok,fieldset,div.iconbutton").hide();
          } else {
            this.$("td").each(function() {
              var alias, alias$;
              alias$ = $(this).css("padding", "").css("padding-right", "2em").find("input:text");
              if ($.trim(alias$.val()) === "") {
                alias = alias$.attr("title");
              } else {
                alias = alias$.val();
              }
              return alias$.replaceWith($("<div />", {
                "class": "station",
                title: alias$.attr("title"),
                text: alias
              }));
            });
            $("doit").removeAttr("disabled");
            this.$("i.icon-ok,fieldset,div.iconbutton").show();
            return $.each(this.collection.models, (function(_this) {
              return function(i, model) {
                return model.set({
                  alias: _this.$("td").find("input[value='" + model.id + "']").parent().find("div.station").text()
                });
              };
            })(this));
          }
        }
      }),
      AllChkButtonView: Backbone.View.extend({
        el: "div.iconbutton",
        events: {
          "click": "onClick"
        },
        onClick: function() {
          this.$el.toggleClass("checked");
          return this.trigger("checkAll", this.$el.hasClass("checked"));
        }
      }),
      SettingButtonView: Backbone.View.extend({
        el: "i.icon-edit",
        events: {
          "click": "renderOnClick"
        },
        renderOnClick: function() {
          this.trigger("switchModeEdit");
          return false;
        }
      }),
      initialize: function() {
        var allChkButtonView, settingButtonView;
        this.stationsView = new this.StationsView({
          collection: new StationCollection(),
          StationView: this.StationView
        });
        allChkButtonView = new this.AllChkButtonView();
        settingButtonView = new this.SettingButtonView();
        allChkButtonView.on("checkAll", this.stationsView.checkAll, this.stationsView);
        return settingButtonView.on("switchModeEdit", this.stationsView.switchModeEdit, this.stationsView);
      }
    });
    MainView = Backbone.View.extend({
      el: "body",
      events: {
        "click": "onClick"
      },
      onClick: function() {
        return this.$("#divPanel").hide();
      },
      TabView: Backbone.View.extend({
        initialize: function() {
          return this.model.on("change:tabid", this.onChangeTabid, this);
        },
        events: {
          "click": "renderOnClick"
        },
        renderOnClick: function() {
          return this.model.set({
            tabid: this.options.index
          });
        },
        onChangeTabid: function() {
          if (this.model.get("tabid") === this.options.index) {
            return this.setCurrentTab();
          }
        },
        setCurrentTab: function() {
          this.trigger("reset");
          $("div.tabPanel").eq(this.options.index).show();
          return this.$el.addClass("current");
        }
      }),
      TabsView: Backbone.View.extend({
        el: "ul.tabs li",
        initialize: function() {
          var inputCenterAddress, inputCenterAddressFav;
          inputCenterAddress = new this.options.InputCenterAddress({
            model: this.model
          });
          inputCenterAddressFav = new this.options.InputCenterAddressFav({
            model: this.model
          });
          this.$el.each((function(_this) {
            return function(i, el) {
              return new _this.options.TabView({
                model: _this.model,
                el: el,
                index: i,
                inputCenterAddress: inputCenterAddress
              }).on("reset", _this.reset, _this);
            };
          })(this));
          return this.model.trigger("change:tabid");
        },
        reset: function() {
          $("div.tabPanel").hide();
          return this.$el.removeClass("current");
        }
      }),
      InputCenterAddress: Backbone.View.extend({
        el: "#centerAddress",
        initialize: function() {
          this.$el.val(this.model.get("centerAddress") || "");
          this.$el.on("change", this.onChange.bind(this));
          return this.model.on("change:centerAddress", this.onChangeCenterAddress, this);
        },
        onChange: function() {
          return this.model.set({
            centerAddress: this.$el.val()
          });
        },
        onChangeCenterAddress: function() {
          return this.$el.val(this.model.get("centerAddress"));
        }
      }),
      InputCenterAddressFav: Backbone.View.extend({
        el: "#centerAddressFav",
        initialize: function() {
          this.$el.val(this.model.get("centerAddressFav") || "");
          this.$el.on("change", this.onChange.bind(this));
          return this.model.on("change:centerAddressFav", this.onChangeCenterAddress, this);
        },
        onChange: function() {
          return this.model.set({
            centerAddressFav: this.$el.val()
          });
        },
        onChangeCenterAddress: function() {
          return this.$el.val(this.model.get("centerAddressFav"));
        }
      }),
      CloseButtonView: Backbone.View.extend({
        el: "i.icon-remove",
        events: {
          "click": "onClick"
        },
        onClick: function() {
          return window.close();
        }
      }),
      StartButtonView: Backbone.View.extend({
        el: "form.inputForm",
        events: {
          "click #doit": "onSubmit"
        },
        onSubmit: function() {
          var activity, checkedList;
          activity = mainView.getActivity();
          if (activity.misc.tabid === tp.tabidFavorite) {
            checkedList = $.grep(activity.favs, function(elem) {
              return elem.checked;
            });
            if (checkedList.length === 0) {
              return this.showAlert("div.tabFavorite table tr:first", "チェックされていません");
            }
            activity.misc.centerAddress = activity.misc.centerAddressFav;
          }
          activity.misc.centerAddress = $.trim(activity.misc.centerAddress);
          return chrome.tabs.getSelected(null, function(tab) {
            var uidparams;
            if (/newtab.html/.test(tab.url)) {
              uidparams = /[\\?&]uid=([^&#]*)/.exec(tab.url);
              tp.setActivity(uidparams[1], activity);
              chrome.tabs.sendMessage(tab.id, "restart");
            } else {
              tp.createNewTab(activity);
            }
            return window.close();
          });
        },
        setEnable: function() {
          return this.$("#doit").removeAttr("disabled").removeClass("disabled").focus();
        },
        showAlert: function(selector, msg) {
          mainView.alertView.setElement(selector);
          mainView.alertView.model.set({
            contents: msg
          });
          return false;
        }
      }),
      AlertView: Backbone.View.extend({
        initialize: function() {
          $.balloon.defaults.classname = "balloon";
          $.balloon.defaults.position = "top";
          $.balloon.defaults.css = {
            "font-size": "75%",
            "white-space": "normal",
            minWidth: "20px",
            padding: "5px",
            borderRadius: "6px",
            border: "solid 1px #777",
            boxShadow: "4px 4px 4px #555",
            color: "#333",
            backgroundColor: "#FFC",
            opacity: "1",
            zIndex: "32767",
            textAlign: "left"
          };
          return this.model.on("change", this.render, this);
        },
        render: function() {
          this.$el.showBalloon(this.model.toJSON()).focus();
          setTimeout("$(\"" + this.$el.selector + "\").hideBalloon()", 2000);
          return this.model.clear({
            silent: true
          });
        }
      }),
      getActivity: function() {
        var activity;
        activity = {};
        activity.favs = this.favoriteTabView.stationsView.collection.toJSON();
        activity.misc = this.miscModel.toJSON();
        return activity;
      },
      initialize: function() {
        this.miscModel = new OptionsMiscModel();
        new this.TabsView({
          model: this.miscModel,
          TabView: this.TabView,
          InputCenterAddress: this.InputCenterAddress,
          InputCenterAddressFav: this.InputCenterAddressFav
        });
        new SearchTabView({
          model: this.miscModel
        });
        this.favoriteTabView = new FavoriteTabView({
          model: this.miscModel
        });
        new this.CloseButtonView();
        this.startButtonView = new this.StartButtonView();
        this.alertView = new this.AlertView({
          model: new PlainModel()
        });
        return $(window).on("unload", this.onWindowUnload.bind(this));
      },
      onWindowUnload: function() {
        var activity;
        this.favoriteTabView.stationsView.switchModeEdit(false);
        activity = this.getActivity();
        localStorage.myfavs = JSON.stringify(activity);
        return $.each(activity.favs, function(i, station) {
          var savedStation;
          if (savedStation = tp.getLocalDB(station.scd)) {
            savedStation.alias = station.alias;
            return tp.setLocalDB(station.scd, savedStation);
          } else {
            savedStation = {};
            savedStation.alias = station.alias;
            savedStation.name = station.place;
            return tp.setLocalDB(station.scd, savedStation);
          }
        });
      },
      run: function() {
        var favorites, storageData;
        favorites = tp.getFavorites().slice(0);
        storageData = {};
        if (localStorage.myfavs || (localStorage.myfavs = localStorage.myscd)) {
          storageData = JSON.parse(localStorage.myfavs);
          if (storageData.scdList) {
            storageData.favs = storageData.scdList;
            delete storageData.scdList;
          }
        }
        if (storageData.favs) {
          $.each(storageData.favs, (function(_this) {
            return function(i, station) {
              station.place = "不明";
              $.each(favorites, function(j, favorite) {
                if (station.scd === favorite.scd) {
                  station.place = favorite.place;
                  favorites.splice(j, 1);
                  return false;
                }
              });
              if (station.place !== "不明") {
                return _this.favoriteTabView.stationsView.collection.push(station);
              }
            };
          })(this));
        }
        $.each(favorites, (function(_this) {
          return function(i, favorite) {
            return _this.favoriteTabView.stationsView.collection.push(favorite);
          };
        })(this));
        this.miscModel.set(storageData.misc || {});
        return chrome.tabs.getSelected(null, (function(_this) {
          return function(tab) {
            if (/newtab.html/.test(tab.url)) {
              return chrome.tabs.sendMessage(tab.id, "requestStartTrigger", function(resp) {
                if (resp === "ok") {
                  return _this.startButtonView.setEnable();
                }
              });
            } else {
              return _this.startButtonView.setEnable();
            }
          };
        })(this));
      }
    });
    tp = chrome.extension.getBackgroundPage().window.tp;
    mainView = new MainView();
    mainView.run();
    return this;
  });

}).call(this);
