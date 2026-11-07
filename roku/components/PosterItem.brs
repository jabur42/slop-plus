sub init()
    m.bg = m.top.findNode("bg")
    m.name = m.top.findNode("name")
    m.poster = m.top.findNode("poster")
    m.track = m.top.findNode("track")
    m.fill = m.top.findNode("fill")
    m.name.font = appFont("Medium", 22)
    m.poster.observeField("loadStatus", "onPosterStatus")
end sub

' O nome em texto só aparece se o pôster não carregar
sub onPosterStatus()
    m.name.visible = (m.poster.loadStatus <> "ready")
end sub

sub onSize()
    w = m.top.width
    h = m.top.height
    m.bg.width = w
    m.bg.height = h
    m.name.translation = [12, 0]
    m.name.width = w - 24
    m.name.height = h
    m.poster.width = w
    m.poster.height = h
    m.poster.loadWidth = w
    m.poster.loadHeight = h
    m.track.translation = [14, h - 20]
    m.track.width = w - 28
    m.fill.translation = [14, h - 20]
    updateProgress()
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.name.text = c.title
    m.poster.uri = c.hdPosterUrl
    updateProgress()
end sub

' Barra de progresso (fileira "Continuar assistindo")
sub updateProgress()
    c = m.top.itemContent
    p = invalid
    if c <> invalid then p = c.progress
    if p = invalid or p <= 0
        m.track.visible = false
        m.fill.visible = false
        return
    end if
    m.track.visible = true
    m.fill.visible = true
    m.fill.width = m.track.width * p
end sub

' Itens fora de foco ficam levemente apagados quando a lista está focada
sub onFocusState()
    if m.top.rowListHasFocus
        m.top.opacity = 0.62 + 0.38 * m.top.focusPercent
    else
        m.top.opacity = 1.0
    end if
end sub
