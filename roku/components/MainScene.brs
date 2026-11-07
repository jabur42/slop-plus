' Pilha de telas: Home -> Detalhes -> Fontes -> Player
sub init()
    m.stack = m.top.findNode("stack")
    m.global.addFields({ caps: deviceCaps() })
    push("HomeScreen", {})
end sub

function topScreen() as object
    n = m.stack.getChildCount()
    if n = 0 then return invalid
    return m.stack.getChild(n - 1)
end function

sub push(name as string, params as object)
    cur = topScreen()
    if cur <> invalid then cur.visible = false
    scr = CreateObject("roSGNode", name)
    scr.observeField("navigate", "onNavigate")
    m.stack.appendChild(scr)
    scr.params = params
    scr.focusMe = true
end sub

sub pop()
    scr = topScreen()
    if scr = invalid then return
    scr.closing = true
    m.stack.removeChild(scr)
    cur = topScreen()
    if cur <> invalid
        cur.visible = true
        cur.focusMe = true
    end if
end sub

sub onNavigate(event as object)
    nav = event.getData()
    if nav = invalid or nav.screen = invalid then return
    if nav.screen = "_back"
        if m.stack.getChildCount() > 1 then pop()
        return
    end if
    push(nav.screen, nav.params)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" and m.stack.getChildCount() > 1
        pop()
        return true
    end if
    return false
end function
