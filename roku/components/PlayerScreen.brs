' Player do Slop+: carregamento, controles próprios, legendas desenhadas pelo app,
' troca de áudio/legenda e seek (no modo HLS, seek fora do trecho pronto reinicia a conversão).
sub init()
    m.video = m.top.findNode("video")
    m.subsGroup = m.top.findNode("subs")
    m.loader = m.top.findNode("loader")
    m.hero = m.top.findNode("hero")
    m.busy = m.top.findNode("busy")
    m.busyLabel = m.top.findNode("busyLabel")
    m.controls = m.top.findNode("controls")
    m.buffered = m.top.findNode("buffered")
    m.played = m.top.findNode("played")
    m.knob = m.top.findNode("knob")
    m.preview = m.top.findNode("preview")
    m.tCur = m.top.findNode("tCur")
    m.tEnd = m.top.findNode("tEnd")
    m.btnName = m.top.findNode("btnName")
    m.panelGrp = m.top.findNode("panel")
    m.pTitle = m.top.findNode("pTitle")
    m.pHint = m.top.findNode("pHint")
    m.radio = m.top.findNode("radio")
    m.styleList = m.top.findNode("styleList")
    m.hideTimer = m.top.findNode("hideTimer")
    m.seekTimer = m.top.findNode("seekTimer")
    m.pollTimer = m.top.findNode("pollTimer")
    m.subTimer = m.top.findNode("subTimer")
    m.spinA = m.top.findNode("spinA")
    m.spinB = m.top.findNode("spinB")

    m.top.findNode("lTitle").font = appFont("Bold", 52)
    m.top.findNode("lSub").font = appFont("Medium", 30)
    m.top.findNode("lSource").font = appFont("Regular", 22)
    m.top.findNode("lPhase").font = appFont("SemiBold", 32)
    m.top.findNode("lInfo").font = appFont("Regular", 26)
    m.top.findNode("lHint").font = appFont("Regular", 22)
    m.top.findNode("lSource").wrap = false
    m.busyLabel.font = appFont("SemiBold", 30)
    m.top.findNode("cTitle").font = appFont("Bold", 40)
    m.top.findNode("cSub").font = appFont("Medium", 26)
    m.tCur.font = appFont("Medium", 26)
    m.tEnd.font = appFont("Medium", 26)
    m.preview.font = appFont("SemiBold", 30)
    m.btnName.font = appFont("Medium", 20)
    m.pTitle.font = appFont("Bold", 40)
    m.pHint.font = appFont("Regular", 22)
    m.radio.font = appFont("Medium", 26)
    m.radio.focusedFont = appFont("SemiBold", 26)
    m.styleList.font = appFont("Medium", 26)
    m.styleList.focusedFont = appFont("SemiBold", 26)

    m.btns = []
    btnGroup = m.top.findNode("buttons")
    for i = 0 to btnGroup.getChildCount() - 1
        g = btnGroup.getChild(i)
        m.btns.Push({ g: g, bg: g.getChild(0), ic: g.getChild(1) })
    end for
    m.btnNames = ["Voltar 10s", "Pausar", "Avançar 10s", "Legendas", "Áudio", "Estilo da legenda"]

    m.caps = m.global.caps
    if m.caps = invalid then m.caps = {}
    m.mode = ""
    m.offset = 0.0
    m.duration = 0.0
    m.ready = 0.0
    m.done = false
    m.progress = 0.0
    m.audios = []
    m.audioN = -1
    m.subs = []
    m.subSel = { kind: "off" }
    m.cues = []
    m.cueI = 0
    m.curSubText = ""
    m.subDelay = 0.0
    m.wantNative = ""
    m.subsInit = false
    m.started = false
    m.loading = false
    m.failed = false
    m.forcedHls = false
    m.ctlVisible = false
    m.zone = "bar"
    m.btn = 1
    m.pendingSeek = -1.0
    m.panel = ""
    m.panelOpts = []

    st = prefGet("subStyle", "1,0,1").Split(",")
    m.style = { size: Val(st[0]), color: Val(st[1]), bg: Val(st[2]) }
    m.sizes = [34, 42, 52, 62]
    m.sizeNames = ["Pequeno", "Médio", "Grande", "Enorme"]
    m.colors = [&hFFFFFFFF, &hFFE14DFF, &h7DD3FCFF]
    m.colorNames = ["Branco", "Amarelo", "Ciano"]
    m.bgOpac = [0.0, 0.55, 0.9]
    m.bgNames = ["Sem fundo", "Translúcido", "Sólido"]
    buildSubSlots()
    applyStyle()

    m.video.notificationInterval = 0.5
    m.video.observeField("state", "onVideoState")
    m.video.observeField("position", "onPosition")
    m.hideTimer.observeField("fire", "onHideTimer")
    m.seekTimer.observeField("fire", "onSeekTimer")
    m.pollTimer.observeField("fire", "onPoll")
    m.subTimer.observeField("fire", "onSubTick")
    m.reportTimer = m.top.findNode("reportTimer")
    m.reportTimer.observeField("fire", "onReport")
    m.firstPlay = true
    m.finished = false
    m.resumeFrom = 0.0
    m.radio.observeField("itemSelected", "onRadioSelected")
    m.styleList.observeField("itemSelected", "onStyleSelected")
end sub

' ================================================================= carregamento
sub onParams()
    p = m.top.params
    m.top.findNode("lTitle").text = p.title
    m.top.findNode("lSub").text = p.subtitle
    m.top.findNode("lSource").text = p.source
    m.top.findNode("cTitle").text = p.title
    m.top.findNode("cSub").text = p.subtitle
    m.hero.uri = p.bg
    setPhase("Conectando ao torrent...", "")
    m.spinA.control = "start"
    startPlay(0, prefGet("audioLang", "por"))
end sub

sub setPhase(phase as string, info as string)
    m.top.findNode("lPhase").text = phase
    m.top.findNode("lInfo").text = info
end sub

sub startPlay(start as float, audio as string)
    m.loading = true
    q = { key: m.top.params.key, start: toText(Int(start)), audio: audio }
    for each k in m.caps
        q[k] = m.caps[k]
    end for
    if m.forcedHls then q.force = "hls"
    if m.top.params.vid <> invalid then q.vid = m.top.params.vid
    if m.firstPlay then q.resume = "1"
    m.firstPlay = false
    m.playTask = callApi("/api/play", q, "onPlay")
    m.pollTimer.control = "start"
end sub

sub onPoll()
    m.statusTask = callApi("/api/status", {}, "onStatus")
end sub

sub onStatus(event as object)
    r = event.getData()
    if not r.ok then return
    d = r.data
    m.ready = d.ready
    m.done = d.done
    m.progress = d.progress
    if m.loading and not m.started and not m.failed
        info = ""
        if d.peers > 0 or d.speed > 0
            info = toText(d.peers) + " peers   ·   " + speedText(d.speed)
            if d.progress > 0 then info = info + "   ·   " + toText(d.progress) + "% baixado"
        end if
        ph = d.phase
        if ph = "" then ph = "Conectando ao torrent"
        setPhase(ph + "...", info)
    end if
    if m.ctlVisible then updateBar()
end sub

function speedText(kb as dynamic) as string
    if kb >= 1024 then return toText(Int(kb / 102.4) / 10) + " MB/s"
    return toText(kb) + " KB/s"
end function

sub onPlay(event as object)
    if not m.loading then return
    r = event.getData()
    if not r.ok
        showError(r.error)
        return
    end if
    d = r.data
    m.mode = d.mode
    m.offset = d.offset
    m.duration = d.duration
    m.audios = d.audios
    m.audioN = d.audio
    m.subs = d.subtitles
    m.ready = 0
    resumeMsg = ""
    if d.resume <> invalid and d.resume > 0
        m.resumeFrom = d.resume
        if m.mode = "direct" and m.resumeAt = invalid then m.resumeAt = d.resume
        resumeMsg = "Retomando de " + formatTime(d.resume) + "..."
    end if
    content = CreateObject("roSGNode", "ContentNode")
    content.url = d.url
    content.streamFormat = d.format
    content.title = m.top.params.title
    content.live = false
    if m.mode = "direct" and m.resumeAt <> invalid and m.resumeAt > 0 then content.playStart = m.resumeAt
    m.resumeAt = invalid
    m.video.content = content
    m.video.visible = true
    m.video.control = "play"
    if resumeMsg <> ""
        setPhase(resumeMsg, "")
    else if m.started
        setPhase("Iniciando...", "")
    else
        setPhase("Iniciando a reprodução...", "")
    end if
    if not m.subsInit
        m.subsInit = true
        applyDefaultSubs()
    end if
end sub

sub showError(msg as string)
    m.failed = true
    m.loading = false
    m.pollTimer.control = "stop"
    m.spinA.control = "stop"
    m.spinB.control = "stop"
    m.busy.visible = false
    m.controls.visible = false
    m.ctlVisible = false
    m.video.control = "stop"
    m.video.visible = false
    m.loader.visible = true
    m.top.findNode("loadSpinner").visible = false
    setPhase("Não foi possível reproduzir", msg)
    m.top.findNode("lHint").text = "Voltar para escolher outra fonte"
end sub

' ================================================================= estado do vídeo
sub onVideoState()
    st = m.video.state
    if st = "playing"
        m.loading = false
        m.busy.visible = false
        m.spinB.control = "stop"
        if not m.started
            m.started = true
            m.loader.visible = false
            m.spinA.control = "stop"
            m.top.setFocus(true)
            showControls()
            m.reportTimer.control = "start"
            if m.wantNative <> "" then pickNativeSub(m.wantNative)
        end if
        updateButtons()
        restartHide()
    else if st = "buffering"
        if m.started
            m.busyLabel.text = ""
            m.busy.visible = true
            m.spinB.control = "start"
        end if
    else if st = "paused"
        updateButtons()
        showControls()
        m.hideTimer.control = "stop"
    else if st = "error"
        if m.mode = "direct" and not m.forcedHls
            ' O Roku não aceitou o arquivo direto: tenta convertendo
            m.forcedHls = true
            t = curPos()
            if t < 1 then t = m.resumeFrom
            restartAt(t, toText(m.audioN))
        else
            showError("Erro no player: " + m.video.errorMsg)
        end if
    else if st = "finished"
        d = totalDur()
        reportPos(d, d)
        m.finished = true
        m.top.navigate = { screen: "_back" }
    end if
end sub

' ================================================================= histórico (onde parou)
sub onReport()
    if m.loading or m.finished then return
    st = m.video.state
    if st = "playing" or st = "paused" then reportPos(curPos(), totalDur())
end sub

sub reportPos(p as float, d as float)
    if not m.started or m.top.params.vid = invalid then return
    meta = m.top.params.meta
    if meta = invalid then meta = {}
    q = { vid: m.top.params.vid, pos: toText(Int(p)), dur: toText(Int(d)) }
    for each k in ["metaId", "type", "name", "poster", "bg", "logo", "label"]
        v = meta[k]
        if v <> invalid then q[k] = toText(v)
    end for
    m.reportTask = callApi("/api/progress", q, "onReported")
end sub

sub onReported()
end sub

function curPos() as float
    return m.offset + m.video.position
end function

function totalDur() as float
    if m.duration > 0 then return m.duration
    return m.offset + m.video.duration
end function

sub onPosition()
    if m.ctlVisible and m.pendingSeek < 0 then updateBar()
end sub

' ================================================================= seek
sub seekBy(delta as float)
    if not m.started or m.loading then return
    base = m.pendingSeek
    if base < 0 then base = curPos()
    t = base + delta
    if t < 0 then t = 0
    d = totalDur()
    if d > 0 and t > d - 5 then t = d - 5
    m.pendingSeek = t
    showControls()
    m.hideTimer.control = "stop"
    updateBar()
    m.seekTimer.control = "stop"
    m.seekTimer.control = "start"
end sub

sub onSeekTimer()
    t = m.pendingSeek
    m.pendingSeek = -1
    m.preview.visible = false
    if t < 0 then return
    commitSeek(t)
    restartHide()
end sub

sub commitSeek(t as float)
    m.cueI = 0
    if m.mode = "direct"
        m.video.seek = t
        return
    end if
    rel = t - m.offset
    if rel >= 0 and (rel <= m.ready - 6 or m.done)
        m.video.seek = rel
    else
        restartAt(t, toText(m.audioN))
    end if
end sub

sub restartAt(t as float, audio as string)
    m.video.control = "stop"
    m.busyLabel.text = "Indo para " + formatTime(t) + "..."
    m.busy.visible = true
    m.spinB.control = "start"
    m.resumeAt = t
    startPlay(t, audio)
end sub

' ================================================================= controles
sub showControls()
    m.controls.visible = true
    m.ctlVisible = true
    updateBar()
    updateButtons()
    layoutSubs()
    restartHide()
end sub

sub hideControls()
    m.controls.visible = false
    m.ctlVisible = false
    m.zone = "bar"
    m.preview.visible = false
    layoutSubs()
end sub

sub restartHide()
    m.hideTimer.control = "stop"
    if m.video.state = "playing" then m.hideTimer.control = "start"
end sub

sub onHideTimer()
    if m.video.state = "playing" and m.panel = "" and m.pendingSeek < 0 then hideControls()
end sub

sub updateBar()
    w = 1728
    at = m.pendingSeek
    if at < 0 then at = curPos()
    d = totalDur()
    frac = 0.0
    if d > 0 then frac = at / d
    if frac > 1 then frac = 1
    if frac < 0 then frac = 0
    m.played.width = w * frac
    m.knob.translation = [w * frac - 14, -10]
    bufEnd = 0.0
    if m.mode = "hls"
        bufEnd = m.offset + m.ready
    else
        bufEnd = d * m.progress / 100
    end if
    bf = 0.0
    if d > 0 then bf = bufEnd / d
    if bf > 1 then bf = 1
    m.buffered.width = w * bf
    m.tCur.text = formatTime(at)
    if d > 0 then m.tEnd.text = formatTime(d) else m.tEnd.text = ""
    if m.pendingSeek >= 0
        m.preview.text = formatTime(at)
        m.preview.translation = [w * frac - 100, -64]
        m.preview.visible = true
    end if
    if m.zone = "bar" then m.knob.scale = [1.35, 1.35] else m.knob.scale = [1.0, 1.0]
end sub

sub updateButtons()
    if m.video.state = "paused" then m.btns[1].ic.uri = "pkg:/images/ic_play.png" else m.btns[1].ic.uri = "pkg:/images/ic_pause.png"
    if m.video.state = "paused" then m.btnNames[1] = "Continuar" else m.btnNames[1] = "Pausar"
    for i = 0 to m.btns.Count() - 1
        b = m.btns[i]
        if m.zone = "buttons" and i = m.btn
            b.bg.blendColor = &hFFFFFFFF
            b.bg.opacity = 1.0
            b.ic.blendColor = &h0E0E12FF
        else
            b.bg.blendColor = &hFFFFFFFF
            b.bg.opacity = 0.16
            b.ic.blendColor = &hFFFFFFFF
        end if
    end for
    if m.zone = "buttons"
        g = m.btns[m.btn].g
        m.btnName.text = m.btnNames[m.btn]
        m.btnName.translation = [g.translation[0] - 56, 1040]
        m.btnName.visible = true
    else
        m.btnName.visible = false
    end if
    updateBar()
end sub

sub togglePause()
    st = m.video.state
    if st = "playing"
        m.video.control = "pause"
    else if st = "paused"
        m.video.control = "resume"
    end if
end sub

sub activateButton(i as integer)
    if i = 0
        seekBy(-10)
    else if i = 1
        togglePause()
    else if i = 2
        seekBy(10)
    else if i = 3
        openPanel("subs")
    else if i = 4
        openPanel("audio")
    else if i = 5
        openPanel("style")
    end if
end sub

' ================================================================= painel lateral
sub openPanel(kind as string)
    m.panel = kind
    m.panelOpts = []
    m.hideTimer.control = "stop"
    root = CreateObject("roSGNode", "ContentNode")
    checked = 0
    if kind = "subs"
        m.pTitle.text = "Legendas"
        m.pHint.text = "OK para escolher   ·   Esquerda para fechar"
        addOpt(root, "Desligadas", { kind: "off" })
        for i = 0 to m.subs.Count() - 1
            addOpt(root, m.subs[i].label, { kind: "ext", idx: i, lang: m.subs[i].lang })
            if m.subSel.kind = "ext" and m.subSel.idx = i then checked = m.panelOpts.Count() - 1
        end for
        if m.mode = "direct"
            tracks = m.video.availableSubtitleTracks
            if tracks <> invalid
                for each t in tracks
                    name = t.Description
                    if name = invalid or name = "" then name = UCase(toText(t.Language))
                    addOpt(root, "Embutida  ·  " + name, { kind: "native", track: t.TrackName, lang: toText(t.Language) })
                    if m.subSel.kind = "native" and m.subSel.track = t.TrackName then checked = m.panelOpts.Count() - 1
                end for
            end if
        end if
    else if kind = "audio"
        m.pTitle.text = "Áudio"
        m.pHint.text = "OK para escolher   ·   Esquerda para fechar"
        if m.mode = "direct"
            tracks = m.video.availableAudioTracks
            if tracks <> invalid
                for each t in tracks
                    name = t.Name
                    if name = invalid or name = "" then name = UCase(toText(t.Language))
                    if t.Format <> invalid and t.Format <> "" then name = name + "  (" + t.Format + ")"
                    addOpt(root, name, { kind: "native", track: t.Track, lang: toText(t.Language) })
                    if t.Track = m.video.currentAudioTrack then checked = m.panelOpts.Count() - 1
                end for
            end if
        else
            for each a in m.audios
                addOpt(root, a.label, { kind: "hls", n: a.n, lang: a.lang })
                if a.n = m.audioN then checked = m.panelOpts.Count() - 1
            end for
        end if
        if m.panelOpts.Count() = 0 then addOpt(root, "Faixa única", { kind: "none" })
    end if

    if kind = "style"
        m.pTitle.text = "Estilo da legenda"
        m.pHint.text = "Esquerda/direita ou OK para mudar"
        m.radio.visible = false
        m.styleList.visible = true
        refreshStyleList()
        m.styleList.jumpToItem = 0
        m.styleList.setFocus(true)
    else
        m.styleList.visible = false
        m.radio.visible = true
        m.radio.content = root
        m.radio.checkedItem = checked
        m.radio.jumpToItem = checked
        m.radio.setFocus(true)
    end if
    m.panelGrp.visible = true
end sub

sub addOpt(root as object, label as string, opt as object)
    root.createChild("ContentNode").title = label
    m.panelOpts.Push(opt)
end sub

sub closePanel()
    m.panel = ""
    m.panelGrp.visible = false
    m.top.setFocus(true)
    restartHide()
end sub

sub onRadioSelected()
    opt = m.panelOpts[m.radio.itemSelected]
    if opt = invalid then return
    if m.panel = "subs"
        selectSub(opt, true)
    else if m.panel = "audio"
        if opt.kind = "native"
            m.video.audioTrack = opt.track
            prefSet("audioLang", opt.lang)
        else if opt.kind = "hls" and opt.n <> m.audioN
            prefSet("audioLang", opt.lang)
            closePanel()
            restartAt(curPos(), toText(opt.n))
            return
        end if
    end if
    closePanel()
end sub

' ================================================================= estilo
sub refreshStyleList()
    root = CreateObject("roSGNode", "ContentNode")
    root.createChild("ContentNode").title = "   Tamanho:   " + m.sizeNames[m.style.size]
    root.createChild("ContentNode").title = "   Cor:   " + m.colorNames[m.style.color]
    root.createChild("ContentNode").title = "   Fundo:   " + m.bgNames[m.style.bg]
    d = m.subDelay
    sign = ""
    if d > 0 then sign = "+"
    root.createChild("ContentNode").title = "   Sincronia:   " + sign + toText(d) + " s"
    sel = m.styleList.itemFocused
    m.styleList.content = root
    if sel <> invalid and sel >= 0 then m.styleList.jumpToItem = sel
end sub

sub changeStyle(item as integer, dir as integer)
    if item = 0
        m.style.size = (m.style.size + dir + 4) mod 4
    else if item = 1
        m.style.color = (m.style.color + dir + 3) mod 3
    else if item = 2
        m.style.bg = (m.style.bg + dir + 3) mod 3
    else if item = 3
        m.subDelay = m.subDelay + dir * 0.5
    end if
    prefSet("subStyle", toText(m.style.size) + "," + toText(m.style.color) + "," + toText(m.style.bg))
    applyStyle()
    refreshStyleList()
    m.curSubText = "*"
    onSubTick()
end sub

sub onStyleSelected()
    changeStyle(m.styleList.itemSelected, 1)
end sub

' ================================================================= legendas
function langKey(l as dynamic) as string
    x = LCase(toText(l))
    if x = "pt" or x = "por" or x = "pob" or x = "pt-br" or x = "pt_br" then return "por"
    if x = "en" or x = "eng" then return "eng"
    if x = "es" or x = "spa" then return "spa"
    return x
end function

sub applyDefaultSubs()
    pref = prefGet("subLang", "por")
    if pref = "off" then return
    ' Áudio já no idioma preferido (ex.: dublado): não liga legenda
    for each a in m.audios
        if a.n = m.audioN and langKey(a.lang) = langKey(pref) then return
    end for
    for i = 0 to m.subs.Count() - 1
        if langKey(m.subs[i].lang) = langKey(pref)
            selectSub({ kind: "ext", idx: i, lang: m.subs[i].lang }, false)
            return
        end if
    end for
    m.wantNative = pref
end sub

sub pickNativeSub(pref as string)
    m.wantNative = ""
    if m.mode <> "direct" or m.subSel.kind <> "off" then return
    tracks = m.video.availableSubtitleTracks
    if tracks = invalid then return
    for each t in tracks
        if langKey(t.Language) = langKey(pref)
            selectSub({ kind: "native", track: t.TrackName, lang: toText(t.Language) }, false)
            return
        end if
    end for
end sub

sub selectSub(opt as object, persist as boolean)
    m.subSel = opt
    m.cues = []
    m.cueI = 0
    showSubText("")
    m.subTimer.control = "stop"
    m.video.globalCaptionMode = "Off"
    if opt.kind = "ext"
        m.subTask = callApi("/api/subs", { u: m.subs[opt.idx].url }, "onCues")
        if persist then prefSet("subLang", langKey(opt.lang))
    else if opt.kind = "native"
        m.video.subtitleTrack = opt.track
        m.video.globalCaptionMode = "On"
        if persist then prefSet("subLang", langKey(opt.lang))
    else
        if persist then prefSet("subLang", "off")
    end if
end sub

sub onCues(event as object)
    r = event.getData()
    if not r.ok or m.subSel.kind <> "ext" then return
    m.cues = r.data.cues
    m.cueI = 0
    m.subTimer.control = "start"
end sub

sub buildSubSlots()
    m.slots = []
    for i = 0 to 3
        bg = m.subsGroup.createChild("Rectangle")
        bg.color = &h000000FF
        sh = m.subsGroup.createChild("Label")
        sh.color = &h000000E6
        lb = m.subsGroup.createChild("Label")
        m.slots.Push({ bg: bg, sh: sh, lb: lb })
    end for
end sub

sub applyStyle()
    size = m.sizes[m.style.size]
    f = appFont("SemiBold", size)
    for each s in m.slots
        s.lb.font = f
        s.sh.font = f
        s.lb.color = m.colors[m.style.color]
        s.bg.opacity = m.bgOpac[m.style.bg]
    end for
end sub

sub onSubTick()
    n = m.cues.Count()
    if n = 0 or m.loading then return
    t = curPos() - m.subDelay
    i = m.cueI
    if i >= n or m.cues[i][0] > t
        ' Pulou para trás (seek): busca binária pela última fala que começa antes de t
        lo = 0
        hi = n - 1
        i = 0
        while lo <= hi
            mid = Int((lo + hi) / 2)
            if m.cues[mid][0] <= t
                i = mid
                lo = mid + 1
            else
                hi = mid - 1
            end if
        end while
    else
        while i + 1 < n and m.cues[i + 1][0] <= t
            i = i + 1
        end while
    end if
    m.cueI = i
    c = m.cues[i]
    if c[0] <= t and t < c[1] then showSubText(c[2]) else showSubText("")
end sub

' Quebra o texto em linhas que caibam na tela
function wrapLines(text as string, maxChars as integer) as object
    out = []
    for each raw in text.Split(Chr(10))
        line = raw.Trim()
        while Len(line) > maxChars
            cut = maxChars
            while cut > 0 and Mid(line, cut, 1) <> " "
                cut = cut - 1
            end while
            if cut <= 0 then cut = maxChars
            out.Push(Left(line, cut).Trim())
            line = Mid(line, cut + 1).Trim()
        end while
        if line <> "" then out.Push(line)
    end for
    while out.Count() > 4
        out.Shift()
    end while
    return out
end function

sub showSubText(text as string)
    if text = m.curSubText then return
    m.curSubText = text
    size = m.sizes[m.style.size]
    lines = []
    if text <> "" then lines = wrapLines(text, Int(1650 / (size * 0.55)))
    m.subLines = lines
    layoutSubs()
end sub

sub layoutSubs()
    if m.slots = invalid then return
    lines = m.subLines
    if lines = invalid then lines = []
    size = m.sizes[m.style.size]
    lineH = Int(size * 1.42)
    baseY = 1010
    if m.ctlVisible then baseY = 840
    n = lines.Count()
    showBg = m.bgOpac[m.style.bg] > 0
    for i = 0 to 3
        s = m.slots[i]
        if i < n
            s.lb.text = lines[i]
            s.sh.text = lines[i]
            w = s.lb.boundingRect().width
            x = Int((1920 - w) / 2)
            y = baseY - (n - i) * lineH
            s.lb.translation = [x, y]
            s.sh.translation = [x + 3, y + 3]
            s.bg.translation = [x - 16, y - 2]
            s.bg.width = w + 32
            s.bg.height = lineH
            s.lb.visible = true
            s.sh.visible = not showBg
            s.bg.visible = showBg
        else
            s.lb.visible = false
            s.sh.visible = false
            s.bg.visible = false
        end if
    end for
end sub

' ================================================================= teclas
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if m.panel <> ""
        if key = "back" or key = "options" or (key = "left" and m.panel <> "style")
            closePanel()
        else if m.panel = "style" and (key = "left" or key = "right")
            dir = 1
            if key = "left" then dir = -1
            changeStyle(m.styleList.itemFocused, dir)
        else if key = "play"
            togglePause()
        end if
        return true
    end if

    ' Carregando ou com erro: Voltar sai do player (MainScene fecha a tela)
    if m.failed or not m.started
        return key <> "back"
    end if

    if key = "back"
        if m.ctlVisible
            hideControls()
            return true
        end if
        return false
    end if
    if m.loading then return true

    if key = "play"
        togglePause()
        showControls()
    else if key = "OK"
        if not m.ctlVisible
            togglePause()
            showControls()
        else if m.zone = "buttons"
            activateButton(m.btn)
            restartHide()
        else if m.pendingSeek >= 0
            m.seekTimer.control = "stop"
            onSeekTimer()
        else
            togglePause()
        end if
    else if key = "left" or key = "right"
        dir = 1
        if key = "left" then dir = -1
        if m.ctlVisible and m.zone = "buttons"
            m.btn = m.btn + dir
            if m.btn < 0 then m.btn = 0
            if m.btn > m.btns.Count() - 1 then m.btn = m.btns.Count() - 1
            updateButtons()
            restartHide()
        else
            m.zone = "bar"
            seekBy(dir * 10)
        end if
    else if key = "fastforward"
        m.zone = "bar"
        seekBy(30)
    else if key = "rewind"
        m.zone = "bar"
        seekBy(-30)
    else if key = "replay"
        seekBy(-10)
        m.seekTimer.control = "stop"
        onSeekTimer()
    else if key = "down"
        if not m.ctlVisible then showControls()
        m.zone = "buttons"
        updateButtons()
        restartHide()
    else if key = "up"
        if m.ctlVisible and m.zone = "buttons"
            m.zone = "bar"
            updateButtons()
        else
            showControls()
        end if
        restartHide()
    else if key = "options"
        showControls()
        openPanel("subs")
    end if
    return true
end function

' ================================================================= saída
sub onClosing()
    ' Salva onde parou antes de encerrar (se não terminou o vídeo)
    if m.started and not m.finished and not m.loading and not m.failed then reportPos(curPos(), totalDur())
    m.reportTimer.control = "stop"
    m.pollTimer.control = "stop"
    m.subTimer.control = "stop"
    m.hideTimer.control = "stop"
    m.seekTimer.control = "stop"
    m.spinA.control = "stop"
    m.spinB.control = "stop"
    m.loading = false
    m.video.control = "stop"
    m.stopTask = callApi("/api/stop", {}, "onStopped")
end sub

sub onStopped()
end sub

sub onFocusMe()
    m.top.setFocus(true)
end sub
