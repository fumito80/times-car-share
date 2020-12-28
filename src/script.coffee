# 初期SCDリスト作成
favorites = []

$("#favoriteStation option").each ->
  fav = JSON.parse($(@).val() || "{}")
  if scd = fav.cd
    favorites.push
      scd: scd
      place: fav.nm
      alias: fav.nm
      checked: true

# chrome.extensionポートオブジェクト
portCtoB = chrome.extension.connect {name: "CtoB"}
portCtoB.postMessage
  command: "sendFavorites"
  favorites: favorites

# ウィンドウ終了時編集SCDリスト破棄
$(window).unload ->
  portCtoB.disconnect()
