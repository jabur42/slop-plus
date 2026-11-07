sub init()
    m.logo = m.top.findNode("logo")
    m.label = m.top.findNode("label")
    m.label.font = appFont("Bold", 64)
    m.logo.observeField("loadStatus", "onLoadStatus")
end sub

sub onFontSize()
    m.label.font = appFont("Bold", m.top.fontSize)
end sub

sub onText()
    m.label.text = m.top.text
    if m.top.logoUri = "" then showText()
end sub

sub onLogo()
    u = m.top.logoUri
    m.logo.visible = false
    if u = invalid or u = ""
        m.logo.uri = ""
        showText()
        return
    end if
    m.label.visible = false
    m.logo.width = 0
    m.logo.height = 0
    m.logo.uri = u
end sub

sub showText()
    m.logo.visible = false
    m.label.visible = true
    r = m.label.boundingRect()
    m.top.height = r.height
end sub

sub onLoadStatus()
    st = m.logo.loadStatus
    if st = "failed"
        showText()
    else if st = "ready"
        bw = m.logo.bitmapWidth
        bh = m.logo.bitmapHeight
        if bw <= 0 or bh <= 0
            showText()
            return
        end if
        sc = m.top.maxW / bw
        if bh * sc > m.top.maxH then sc = m.top.maxH / bh
        m.logo.width = bw * sc
        m.logo.height = bh * sc
        m.logo.visible = true
        m.label.visible = false
        m.top.height = bh * sc
    end if
end sub
