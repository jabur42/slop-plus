sub init()
    m.badge = m.top.findNode("badge")
    m.quality = m.top.findNode("quality")
    m.release = m.top.findNode("release")
    m.dot = m.top.findNode("dot")
    m.details = m.top.findNode("details")
    m.tags = m.top.findNode("tags")
    m.quality.font = appFont("Bold", 24)
    m.release.font = appFont("SemiBold", 26)
    m.details.font = appFont("Regular", 23)
    m.tags.font = appFont("SemiBold", 22)
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.quality.text = c.quality
    m.badge.blendColor = qualityColor(c.quality)
    m.release.text = c.title
    m.details.text = c.description
    m.tags.text = c.tagText
    ' Verde: muitos peers (início rápido); amarelo: médio; vermelho: poucos
    p = c.peers
    if p >= 50
        m.dot.blendColor = &h22C55EFF
    else if p >= 10
        m.dot.blendColor = &hEAB308FF
    else
        m.dot.blendColor = &hEF4444FF
    end if
end sub
