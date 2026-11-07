' Endereço do backend no seu PC.
' NÃO edite aqui: o deploy.ps1 coloca o IP correto só dentro do pacote enviado ao Roku,
' então o seu IP nunca fica salvo neste arquivo (nem no git).
function BackendUrl() as string
    return "http://127.0.0.1:8787"
end function
