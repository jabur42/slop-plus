sub init()
    m.hero = m.top.findNode("hero")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.count = m.top.findNode("count")
    m.list = m.top.findNode("list")
    m.statusBox = m.top.findNode("statusBox")
    m.status = m.top.findNode("status")
    m.spinner = m.top.findNode("spinner")
    m.spin = m.top.findNode("spin")
    m.title.font = appFont("Bold", 48)
    m.subtitle.font = appFont("Medium", 26)
    m.count.font = appFont("Regular", 24)
    m.status.font = appFont("Medium", 30)
    m.list.observeField("itemSelected", "onStreamSelected")
    m.spin.control = "start"
end sub

sub onParams()
    p = m.top.params
    m.title.text = p.title
    m.subtitle.text = p.subtitle
    m.hero.uri = p.bg
    m.task = callApi("/api/streams", { type: p.type, id: p.id }, "onStreams")
end sub

sub onStreams(event as object)
    m.spin.control = "stop"
    m.spinner.visible = false
    r = event.getData()
    if not r.ok
        m.status.text = r.error
        return
    end if
    if r.data.streams.Count() = 0
        m.status.text = "Nenhuma fonte encontrada para este título."
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    for each st in r.data.streams
        c = root.createChild("ContentNode")
        title = st.release
        if st.file <> "" then title = st.file
        c.title = title

        d = [toText(st.peers) + " peers"]
        if st.size <> "" then d.Push(st.size)
        if st.source <> "" then d.Push(st.source)
        if st.langs.Count() > 0
            langs = []
            for i = 0 to st.langs.Count() - 1
                if i < 6 then langs.Push(st.langs[i])
            end for
            lt = langs.Join(", ")
            if st.langs.Count() > 6 then lt = lt + " +" + toText(st.langs.Count() - 6)
            d.Push("Áudio " + lt)
        end if
        c.description = d.Join("     ·     ")
        c.addFields({ streamKey: st.key, quality: st.quality, peers: st.peers, tagText: st.tags.Join("   "), release: st.release })
    end for
    m.statusBox.visible = false
    m.count.text = toText(r.data.streams.Count()) + " fontes  ·  por qualidade e peers"
    m.list.content = root
    m.list.setFocus(true)
end sub

sub onStreamSelected()
    c = m.list.content.getChild(m.list.itemSelected)
    if c = invalid then return
    p = m.top.params
    m.top.navigate = { screen: "PlayerScreen", params: {
        key: c.streamKey, title: p.title, subtitle: p.subtitle, bg: p.bg,
        source: c.quality + "  ·  " + c.title, vid: p.id, meta: p.meta
    } }
end sub

sub onFocusMe()
    if m.list.content <> invalid then m.list.setFocus(true) else m.top.setFocus(true)
end sub
