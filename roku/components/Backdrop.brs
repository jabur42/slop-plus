sub init()
    m.a = m.top.findNode("a")
    m.b = m.top.findNode("b")
    m.layers = m.top.findNode("layers")
    m.fade = m.top.findNode("fade")
    m.interp = m.top.findNode("interp")
    m.showingB = false
    m.pending = invalid
    m.a.observeField("loadStatus", "onLoaded")
    m.b.observeField("loadStatus", "onLoaded")
end sub

sub onDim()
    m.layers.opacity = m.top.dim
end sub

sub onUri()
    u = m.top.uri
    if u = invalid or u = "" then return
    ' Carrega na camada escondida e faz o crossfade quando estiver pronta
    if m.showingB
        if m.a.uri = u then
            fadeTo(false)
            return
        end if
        m.pending = m.a
        m.a.uri = u
    else
        if m.b.uri = u then
            fadeTo(true)
            return
        end if
        m.pending = m.b
        m.b.uri = u
    end if
end sub

sub onLoaded(event as object)
    p = event.getRoSGNode()
    if m.pending = invalid or not p.isSameNode(m.pending) then return
    st = p.loadStatus
    if st <> "ready" and st <> "failed" then return
    m.pending = invalid
    fadeTo(p.isSameNode(m.b))
end sub

sub fadeTo(showB as boolean)
    m.fade.control = "stop"
    cur = m.b.opacity
    if showB
        m.interp.keyValue = [cur, 1.0]
    else
        m.interp.keyValue = [cur, 0.0]
    end if
    m.showingB = showB
    m.fade.control = "start"
end sub
