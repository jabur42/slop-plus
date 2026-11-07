sub init()
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.overview = m.top.findNode("overview")
    m.title.font = appFont("SemiBold", 28)
    m.overview.font = appFont("Regular", 22)
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.title.text = c.title
    m.overview.text = c.description
    m.thumb.uri = c.hdPosterUrl
end sub
