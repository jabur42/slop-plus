sub init()
    m.rows = m.top.findNode("rows")
    m.hero = m.top.findNode("hero")
    m.titleLogo = m.top.findNode("titleLogo")
    m.meta = m.top.findNode("meta")
    m.desc = m.top.findNode("desc")
    m.status = m.top.findNode("status")
    m.statusSub = m.top.findNode("statusSub")
    m.statusBox = m.top.findNode("statusBox")
    m.heroTimer = m.top.findNode("heroTimer")
    m.retryTimer = m.top.findNode("retryTimer")

    m.top.findNode("searchLabel").font = appFont("Medium", 26)
    m.meta.font = appFont("Medium", 26)
    m.desc.font = appFont("Regular", 26)
    m.status.font = appFont("SemiBold", 36)
    m.statusSub.font = appFont("Regular", 26)
    m.rows.rowLabelFont = appFont("SemiBold", 30)

    m.isSearch = false
    m.lastPath = "/api/home"
    m.lastQuery = {}
    m.rows.observeField("rowItemFocused", "onItemFocused")
    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.titleLogo.observeField("height", "layoutInfo")
    m.heroTimer.observeField("fire", "onHeroTimer")
    m.retryTimer.observeField("fire", "onRetry")
    layoutInfo()
    loadRows("/api/home", {})
end sub

sub layoutInfo()
    h = m.titleLogo.height
    if h = invalid or h <= 0 then h = 80
    m.meta.translation = [0, h + 22]
    m.desc.translation = [0, h + 72]
end sub

sub loadRows(path as string, query as object)
    m.lastPath = path
    m.lastQuery = query
    m.status.text = "Carregando..."
    m.statusSub.text = ""
    m.statusBox.visible = true
    m.task = callApi(path, query, "onRows")
end sub

sub onRetry()
    loadRows(m.lastPath, m.lastQuery)
end sub

sub onRows(event as object)
    r = event.getData()
    if not r.ok
        ' PC desligado ou backend iniciando: tenta de novo sozinho
        m.status.text = "Conectando ao Slop+ no seu PC..."
        m.statusSub.text = r.error + "   ·   tentando de novo"
        m.retryTimer.control = "start"
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    m.contSig = ""
    for each row in r.data.rows
        root.appendChild(makeRow(row))
        if row.kind <> invalid and row.kind = "continue" then m.contSig = rowSig(row)
    end for
    if root.getChildCount() = 0
        m.status.text = "Nada encontrado"
        m.statusSub.text = "Aperte Voltar para retornar"
        return
    end if
    m.statusBox.visible = false
    m.rows.content = root
    m.rows.jumpToRowItem = [0, 0]
    m.rows.setFocus(true)
end sub

function makeRow(row as object) as object
    rowNode = CreateObject("roSGNode", "ContentNode")
    rowNode.title = row.title
    isCont = (row.kind <> invalid and row.kind = "continue")
    rowNode.addFields({ isContinue: isCont })
    for each it in row.items
        c = rowNode.createChild("ContentNode")
        c.title = it.name
        c.hdPosterUrl = it.poster
        c.description = it.description
        c.addFields({ metaId: it.id, metaType: it.type, bg: it.background, info: it.info, logo: it.logo })
        if isCont then c.addFields({ progress: it.progress, vid: it.vid, label: it.label })
    end for
    return rowNode
end function

function rowSig(row as object) as string
    if row = invalid then return ""
    sig = ""
    for each it in row.items
        sig = sig + it.vid + "@" + toText(Int(it.progress * 200)) + ";"
    end for
    return sig
end function

' Ao voltar do player: atualiza a fileira "Continuar assistindo"
sub refreshContinue()
    if m.isSearch or m.rows.content = invalid then return
    m.contTask = callApi("/api/continue", {}, "onContinue")
end sub

sub onContinue(event as object)
    r = event.getData()
    if not r.ok or m.isSearch or m.rows.content = invalid then return
    row = r.data.row
    sig = rowSig(row)
    if sig = m.contSig then return
    m.contSig = sig
    old = m.rows.content
    root = CreateObject("roSGNode", "ContentNode")
    if row <> invalid then root.appendChild(makeRow(row))
    rows = []
    for i = 0 to old.getChildCount() - 1
        ch = old.getChild(i)
        if ch.isContinue <> true then rows.Push(ch)
    end for
    for each ch in rows
        root.appendChild(ch)
    end for
    m.rows.content = root
    m.rows.jumpToRowItem = [0, 0]
    m.rows.setFocus(true)
end sub

function focusedItem() as object
    idx = m.rows.rowItemFocused
    if m.rows.content = invalid or idx = invalid or idx.Count() < 2 then return invalid
    row = m.rows.content.getChild(idx[0])
    if row = invalid then return invalid
    return row.getChild(idx[1])
end function

sub onItemFocused()
    it = focusedItem()
    if it = invalid then return
    m.titleLogo.logoUri = ""
    m.titleLogo.text = it.title
    m.titleLogo.logoUri = it.logo
    m.meta.text = it.info
    m.desc.text = it.description
    ' Espera o usuário parar de navegar para trocar a imagem de fundo
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub onHeroTimer()
    it = focusedItem()
    if it <> invalid then m.hero.uri = it.bg
end sub

sub onItemSelected()
    it = focusedItem()
    if it = invalid then return
    if it.vid <> invalid and it.vid <> ""
        ' Continuar assistindo: vai direto para as fontes do mesmo filme/episódio
        sub_ = it.label
        if sub_ = "" then sub_ = "Filme"
        meta = { metaId: it.metaId, type: it.metaType, name: it.title, poster: it.hdPosterUrl, bg: it.bg, logo: it.logo, label: it.label }
        m.top.navigate = { screen: "StreamsScreen", params: { type: it.metaType, id: it.vid, title: it.title, subtitle: sub_, bg: it.bg, meta: meta } }
        return
    end if
    m.top.navigate = { screen: "DetailsScreen", params: { id: it.metaId, type: it.metaType, name: it.title, bg: it.bg, logo: it.logo } }
end sub

sub onFocusMe()
    if m.rows.content <> invalid
        m.rows.setFocus(true)
        refreshContinue()
    else
        m.top.setFocus(true)
    end if
end sub

sub openSearch()
    kd = CreateObject("roSGNode", "StandardKeyboardDialog")
    kd.title = "Buscar filmes e séries"
    kd.buttons = ["Buscar", "Cancelar"]
    kd.observeField("buttonSelected", "onSearchButton")
    kd.observeField("wasClosed", "onSearchClosed")
    m.kd = kd
    m.top.getScene().dialog = kd
end sub

sub onSearchButton()
    text = m.kd.text
    go = (m.kd.buttonSelected = 0 and text <> "")
    m.kd.close = true
    if go
        m.isSearch = true
        m.titleLogo.logoUri = ""
        m.titleLogo.text = "Busca: " + text
        m.meta.text = ""
        m.desc.text = ""
        loadRows("/api/search", { q: text })
    end if
end sub

sub onSearchClosed()
    onFocusMe()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options"
        openSearch()
        return true
    end if
    if key = "back" and m.isSearch
        m.isSearch = false
        loadRows("/api/home", {})
        return true
    end if
    return false
end function
