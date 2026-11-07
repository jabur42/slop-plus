sub init()
    m.top.functionName = "doRequest"
end sub

sub doRequest()
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)

    url = BackendUrl() + m.top.path
    q = m.top.query
    if q <> invalid
        sep = "?"
        for each k in q
            url = url + sep + k + "=" + xfer.Escape(q[k])
            sep = "&"
        end for
    end if
    xfer.SetUrl(url)

    result = { ok: false, error: "Backend offline? Verifique o PC" }
    if xfer.AsyncGetToString()
        msg = wait(600000, port)
        if type(msg) = "roUrlEvent"
            code = msg.GetResponseCode()
            data = ParseJson(msg.GetString())
            if code = 200 and data <> invalid
                result = { ok: true, data: data }
            else if data <> invalid and data.error <> invalid
                result = { ok: false, error: data.error }
            else if code < 0
                result = { ok: false, error: "Sem conexão com o PC (" + BackendUrl() + ")" }
            else
                result = { ok: false, error: "Erro HTTP " + Str(code).Trim() }
            end if
        else
            xfer.AsyncCancel()
            result = { ok: false, error: "Tempo esgotado" }
        end if
    end if
    m.top.response = result
end sub
