sub init()
    m.hero = m.top.findNode("hero")
    m.titleLogo = m.top.findNode("titleLogo")
    m.metaRow = m.top.findNode("metaRow")
    m.meta = m.top.findNode("meta")
    m.imdb = m.top.findNode("imdb")
    m.imdbBg = m.top.findNode("imdbBg")
    m.desc = m.top.findNode("desc")
    m.cast = m.top.findNode("cast")
    m.watch = m.top.findNode("watch")
    m.seriesBox = m.top.findNode("seriesBox")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.status = m.top.findNode("status")

    m.meta.font = appFont("Medium", 26)
    m.imdb.font = appFont("Bold", 24)
    m.desc.font = appFont("Regular", 26)
    m.cast.font = appFont("Regular", 22)
    m.status.font = appFont("Medium", 30)
    m.seasons.font = appFont("Medium", 28)
    m.seasons.focusedFont = appFont("SemiBold", 28)

    m.meta = m.top.findNode("meta")
    m.data = invalid
    m.compact = false
    m.seasons.observeField("itemFocused", "onSeasonFocused")
    m.episodes.observeField("itemSelected", "onEpisodeSelected")
    m.watch.observeField("selected", "onWatch")
    m.titleLogo.observeField("height", "layout")
end sub

sub layout()
    h = m.titleLogo.height
    if h = invalid or h <= 0 then h = 80
    y = h + 24
    m.metaRow.translation = [0, y]
    y = y + 60
    m.desc.translation = [0, y]
    lines = 4
    if m.compact then lines = 2
    m.desc.maxLines = lines
    m.desc.height = 0
    dh = m.desc.boundingRect().height
    m.cast.translation = [0, y + dh + 14]
end sub

sub onParams()
    p = m.top.params
    m.titleLogo.text = p.name
    m.titleLogo.logoUri = p.logo
    m.hero.uri = p.bg
    m.task = callApi("/api/meta", { type: p.type, id: p.id }, "onMeta")
end sub

sub onMeta(event as object)
    r = event.getData()
    if not r.ok
        m.status.text = r.error
        return
    end if
    d = r.data
    m.data = d
    m.status.visible = false
    m.titleLogo.text = d.name
    if d.logo <> "" and d.logo <> m.titleLogo.logoUri then m.titleLogo.logoUri = d.logo
    if d.background <> "" then m.hero.uri = d.background

    parts = []
    if d.year <> "" then parts.Push(d.year)
    if d.genres <> "" then parts.Push(d.genres)
    if d.runtime <> "" then parts.Push(d.runtime)
    m.meta.text = parts.Join("   ·   ")
    if d.rating <> ""
        m.imdb.text = "IMDb " + d.rating
        x = m.meta.boundingRect().width + 28
        if parts.Count() = 0 then x = 0
        m.imdb.translation = [x + 16, -2]
        m.imdbBg.translation = [x, -2]
        m.imdbBg.width = m.imdb.boundingRect().width + 32
        m.imdbBg.visible = true
    end if
    m.desc.text = d.description
    if d.cast <> "" then m.cast.text = "Elenco: " + d.cast

    if d.type = "series" and d.seasons.Count() > 0
        m.compact = true
        root = CreateObject("roSGNode", "ContentNode")
        for each sn in d.seasons
            root.createChild("ContentNode").title = "   " + sn.label
        end for
        m.seasons.content = root
        m.seriesBox.visible = true
        fillEpisodes(0)
        m.episodes.setFocus(true)
    else
        m.watch.visible = true
        m.watch.setFocus(true)
    end if
    layout()
end sub

sub fillEpisodes(idx as integer)
    sn = m.data.seasons[idx]
    if sn = invalid then return
    m.seasonShort = sn.short
    root = CreateObject("roSGNode", "ContentNode")
    for each ep in sn.episodes
        c = root.createChild("ContentNode")
        c.title = toText(ep.ep) + ".  " + ep.title
        c.description = ep.overview
        c.hdPosterUrl = ep.thumb
        c.addFields({ videoId: ep.id, ep: ep.ep })
    end for
    m.episodes.content = root
end sub

sub onSeasonFocused()
    if m.data <> invalid then fillEpisodes(m.seasons.itemFocused)
end sub

sub onWatch()
    d = m.data
    meta = { metaId: d.id, type: d.type, name: d.name, poster: d.poster, bg: d.background, logo: d.logo, label: "" }
    m.top.navigate = { screen: "StreamsScreen", params: { type: d.type, id: d.id, title: d.name, subtitle: "Filme", bg: m.hero.uri, meta: meta } }
end sub

sub onEpisodeSelected()
    c = m.episodes.content.getChild(m.episodes.itemSelected)
    if c = invalid then return
    sub_ = m.seasonShort + ":E" + toText(c.ep) + "  ·  " + Mid(c.title, Instr(1, c.title, ".") + 3)
    bg = c.hdPosterUrl
    if m.data.background <> "" then bg = m.data.background
    d = m.data
    meta = { metaId: d.id, type: "series", name: d.name, poster: d.poster, bg: bg, logo: d.logo, label: sub_ }
    m.top.navigate = { screen: "StreamsScreen", params: { type: "series", id: c.videoId, title: d.name, subtitle: sub_, bg: bg, meta: meta } }
end sub

sub onFocusMe()
    if m.data = invalid
        m.top.setFocus(true)
    else if m.seriesBox.visible
        if m.seasons.hasFocus() then m.seasons.setFocus(true) else m.episodes.setFocus(true)
    else
        m.watch.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.seriesBox.visible then return false
    if key = "right" and m.seasons.hasFocus()
        m.episodes.setFocus(true)
        return true
    end if
    if key = "left" and m.episodes.hasFocus()
        m.seasons.setFocus(true)
        return true
    end if
    return false
end function
