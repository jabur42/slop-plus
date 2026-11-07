sub init()
    m.bg = m.top.findNode("bg")
    m.ic = m.top.findNode("ic")
    m.label = m.top.findNode("label")
    m.label.font = appFont("SemiBold", 30)
    m.top.observeField("focusedChild", "onFocus")
    layout()
end sub

sub onText()
    m.label.text = m.top.text
    layout()
end sub

sub onIcon()
    m.ic.uri = m.top.icon
    m.ic.visible = (m.top.icon <> "")
    layout()
end sub

sub layout()
    x = 44
    if m.ic.visible then x = 92
    m.label.translation = [x, 0]
    w = m.label.boundingRect().width + x + 48
    if w < m.top.minWidth then w = m.top.minWidth
    m.bg.width = w
end sub

sub onFocus()
    if m.top.hasFocus()
        m.bg.blendColor = &hFFFFFFFF
        m.label.color = &h0E0E12FF
        m.ic.blendColor = &h0E0E12FF
    else
        m.bg.blendColor = &hFFFFFF26
        m.label.color = &hFFFFFFFF
        m.ic.blendColor = &hFFFFFFFF
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "OK"
        m.top.selected = true
        return true
    end if
    return false
end function
