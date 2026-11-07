' Dispara uma chamada ao backend; o callback recebe o evento com o campo "response".
function callApi(path as string, query as object, callback as string) as object
    task = CreateObject("roSGNode", "ApiTask")
    task.path = path
    task.query = query
    task.observeField("response", callback)
    task.control = "RUN"
    return task
end function

function toText(v as dynamic) as string
    if v = invalid then return ""
    t = type(v)
    if t = "String" or t = "roString" then return v
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble"
        if v = Int(v) then return Str(Int(v)).Trim()
        return Str(v).Trim()
    end if
    if t = "Boolean" or t = "roBoolean"
        if v then return "true"
        return "false"
    end if
    return Str(v).Trim()
end function

' Fonte Poppins (pkg:/fonts). weight: Regular | Medium | SemiBold | Bold
function appFont(weight as string, size as integer) as object
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/Poppins-" + weight + ".ttf"
    f.size = size
    return f
end function

' 3725 -> "1:02:05", 65 -> "1:05"
function formatTime(secs as dynamic) as string
    if secs = invalid or secs < 0 then secs = 0
    t = Int(secs)
    h = Int(t / 3600)
    mi = Int((t mod 3600) / 60)
    se = t mod 60
    ss = Right("0" + Str(se).Trim(), 2)
    if h > 0 then return Str(h).Trim() + ":" + Right("0" + Str(mi).Trim(), 2) + ":" + ss
    return Str(mi).Trim() + ":" + ss
end function

' ---------------------------------------------------------------- preferências
function prefGet(key as string, def as string) as string
    sec = CreateObject("roRegistrySection", "slopplus")
    if sec.Exists(key) then return sec.Read(key)
    return def
end function

sub prefSet(key as string, value as string)
    sec = CreateObject("roRegistrySection", "slopplus")
    sec.Write(key, value)
    sec.Flush()
end sub

' ---------------------------------------------------------------- capacidades do aparelho
' Enviadas ao backend para ele decidir se toca direto (rápido) ou converte.
function deviceCaps() as object
    di = CreateObject("roDeviceInfo")
    caps = { hevc: "0", hevc10: "0", ac3: "0", eac3: "0", maxh: "1080" }
    if di.CanDecodeVideo({ Codec: "hevc", Profile: "main", Level: "4.1", Container: "mkv" }).result = true then caps.hevc = "1"
    if di.CanDecodeVideo({ Codec: "hevc", Profile: "main 10", Level: "4.1", Container: "mkv" }).result = true then caps.hevc10 = "1"
    if di.CanDecodeAudio({ Codec: "ac3" }).result = true then caps.ac3 = "1"
    if di.CanDecodeAudio({ Codec: "eac3" }).result = true then caps.eac3 = "1"
    mode = di.GetVideoMode()
    if Instr(1, mode, "2160") > 0 and di.CanDecodeVideo({ Codec: "hevc", Profile: "main", Level: "5.1" }).result = true
        caps.maxh = "2160"
    else if Instr(1, mode, "720") > 0
        caps.maxh = "720"
    end if
    return caps
end function

' Cor da etiqueta de qualidade
function qualityColor(q as string) as integer
    if q = "4K" then return &h8B5CF6FF
    if q = "1080p" then return &h2563EBFF
    if q = "720p" then return &h0D9488FF
    if q = "CAM" then return &hB91C1CFF
    return &h52525BFF
end function
