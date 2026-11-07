# Slop+ 🍿

**Versão alpha 0.1** · *"Roku quer te fazer assinar mais um streaming? Relaxa paizão."*

🇧🇷 Português · [🇺🇸 English](README.en.md)

O Slop+ é um canal para Roku com cara de Stremio de verdade (só que de graça e com um nome pior). Ele usa os addons do ecossistema Stremio, Seu PC faz o trabalho pesado, e o coitado do Roku Express (ou RokuTV), só precisa mostrar o vídeo.

> EU NÃO SOU DEV (já fui hoje eu só edito video memo), sou só um teimoso que passou raiva tentando assistir streamings duvidosos no roku. ISSO É 200% VIBECODADO!!! Se funcionou na minha casa, deve funcionar na sua. Se não, abra uma issue e reze. 🙏

---

## Antes de mais nada a parte séria (ou quase isso)

- O Slop+ **não hospeda, não baixa por conta própria e não distribui nenhum conteúdo**. Ele vem só com o catálogo público (Cinemeta) e legendas (OpenSubtitles). As fontes de vídeo vêm dos addons que **você** escolher adicionar. Assista só ao que você tem direito de assistir. Se der ruim, deu ruim.
- **Torrent mostra o seu IP público** para as outras pessoas do mesmo arquivo. Isso acontece em qualquer programa de torrent, não é culpa minha ou do Slop+. Se isso te tira o sono, use uma VPN.
- Não temos nada a ver com o Stremio nem com a Roku nem com as fontes. Eles nem sabem que isso existe.
- É **alpha**. Tem bug. Muitos? talvez. Mas tem "Continuar assistindo".

O que tem dentro:

- 🏠 **Home** com "Continuar assistindo", catálogos e busca
- 📺 **Detalhes** com temporadas e episódios (com miniatura, chique)
- 🧲 **Lista de fontes** ordenada por qualidade (4K > 1080p > 720p > SD > "filmado no cinema") e, dentro de cada uma, por número de peers
- ▶️ **Player** com controles, troca de áudio, legendas (idioma, tamanho, cor, fundo e sincronia, para aquele filme em que a legenda chega 2 segundos atrasada)
- ⏱️ **Lembra onde você parou**, mesmo se você trocar de torrent (sim, a gente se importa)
- 🎮 Converte o vídeo na placa NVIDIA (NVENC) se você tiver; senão, a CPU sofre um pouquinho
- 🧹 Apaga o cache do vídeo anterior quando você dá play no próximo. Seu HD agradece.

## Você vai precisar de

- Um **Roku** (testado no Roku Express, o mais humilde de todos) na mesma rede do PC.
- Um **PC com Windows 10/11** que fique ligado enquanto você assiste.
- **Node.js 20 ou mais novo** ([nodejs.org](https://nodejs.org), pegue a versão LTS e clique em "Avançar" até acabar)

## Instalação

### 1. Coloque o Roku no modo desenvolvedor (o "modo hacker")

1. No controle do Roku, faça o KUnami Code: **Home 3x, Cima 2x, Direita, Esquerda, Direita, Esquerda, Direita**. É sério. Parece Konami Code, mas é a Roku.
2. Anote o **IP** que aparece na tela (ex.: `192.168.x.xx`).
3. Aceite os termos (ninguém lê, a gente sabe), ative o instalador e **crie uma senha**. Anote essa também.
4. O Roku reinicia. Respire.

> O IP e a senha do Roku são **seus**. Eles ficam **somente no seu PC**, num arquivo que o git ignora. **Nunca** cole esses dados numa issue, num pull request ou num print no Twitter (Descanse em paz).

### 2. Baixe o Slop+

No topo desta página, clique em **Code > Download ZIP** e extraia numa pasta qualquer (ex.: `Documentos\slop-plus`).

### 3. Rode o instalador mágico

Abra a pasta extraída, clique com o botão direito num espaço vazio e escolha **Abrir no Terminal**. Depois cole:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

O instalador vai:
1. Conferir se o Node.js está lá.
2. Baixar as dependências.
3. **Pedir o IP e a senha do seu Roku**.
4. Ligar o backend, que passa a iniciar sozinho junto com o Windows.
5. instalar o canal **Slop+** no Roku.

Se o Windows perguntar sobre o **Firewall** para o Node.js, clique em **Permitir** (rede privada). Sem isso, o Roku fica gritando no vazio.

### 4. Arrume umas fontes

De fábrica, o Slop+ só tem o catálogo e as legendas. ou seja dá para ver tudo, mas não toca nada. Para ter fontes de vídeo, adicione addons Stremio da sua escolha:

- **Importar da sua conta Stremio** (pega os mesmos addons que você já usa lá):
  ```powershell
  cd backend
  npm run import
  ```
  O e-mail e a senha são usados só para o login no Stremio e **não são salvos**. Nem a gente vê.
- **Do jeito raiz:** edite `backend\config.json` e coloque o endereço do `manifest.json` de cada addon na lista `addons`.

Depois, reinicie o backend: rode `.\instalar-autostart.ps1` de novo, ou faça o clássico "desliga e liga" no PC.

## Uso no dia a dia

- Abra o **Slop+** no Roku. O backend já estará rodando no PC, se esforçando em silêncio.
- **Busca:** tecla `*` na Home.
- **No player:**
  - **OK:** pausa e continua.
  - **Esquerda/direita:** volta ou avança 10s. ⏪/⏩ pulam 30s.
  - **Baixo:** mostra os botões (legendas, áudio, estilo).
  - **`*`:** abre direto o menu de legendas.
- **1080p com bolinha verde** (muitos peers) começam rapidinho. Um 4K de 60 GB com 3 peers vai te lembrar a época do Tibia na net discada...

## Privacidade: o que fica onde

| Dado | Onde fica | Vai para o GitHub? |
|---|---|---|
| IP e senha do Roku | `configuracao-local.json` | Não (o git ignora) |
| Seus addons | `backend\config.json` | Não (o git ignora) |
| Histórico / onde parou | `%LOCALAPPDATA%\SlopPlus\history.json` | Não (fica fora da pasta) |
| IP do PC | só dentro do pacote enviado ao Roku | Não |
| Vídeos baixados | pasta temporária do Windows, apagada ao trocar de vídeo | Não, e nem tem como |

O backend só aceita conexões da rede de casa (IPs privados). Se alguém abrir a porta 8787 no roteador por engano, acessos vindos da internet levam um 403 na cara. Mesmo assim, **não abra essa porta no roteador.**

## Deu ruim?

| Sintoma | O que fazer |
|---|---|
| "Conectando ao Slop+ no seu PC..." eternamente | O PC está ligado? O backend roda? Veja o log em `%LOCALAPPDATA%\SlopPlus\backend.log`. Confira o Firewall. |
| Falha no deploy | IP ou senha do Roku errados, ou o modo desenvolvedor desligou. Rode o `instalar.ps1` de novo. |
| O IP do PC mudou | Rode `.\deploy.ps1 -PcIp NOVO_IP`, ou fixe o IP do PC no roteador (reserva DHCP). |
| Demora para começar | Escolha uma fonte com mais peers ou de menor qualidade. Seu Roku Express não é uma NASA. |
| Quero parar o início automático | `.\instalar-autostart.ps1 -Remover` |

## Para devs (de verdade)

```
backend/          Node.js: agrega addons, WebTorrent, ffmpeg (HLS), histórico
  server.js       API usada pelo Roku (/api/home, /api/streams, /api/play, ...)
  supervisor.js   ressuscita o backend se ele cair
  *.test.js       testes (npm test); os e2e-*.js usam torrents de domínio público
roku/             canal em BrightScript + SceneGraph
  components/     telas (Home, Detalhes, Fontes, Player) e componentes
tools/            gerador das imagens do canal
deploy.ps1        empacota e envia o canal ao Roku (-SoEmpacotar só gera o zip)
```

- Testes do backend: `cd backend; npm test`
- Validação do BrightScript: `cd roku; npx brighterscript --createPackage false`
- **Contribuições são muito bem-vindas!** Abra uma issue ou mande um pull request. Hoje o instalador só funciona no Windows; suporte a Linux/macOS seria lindo. Melhorias no player, novos idiomas e piadas melhores para este README também valem.

## Créditos e licenças

- Código do Slop+: [MIT](LICENSE). Faça o que quiser, só não diga que a culpa é minha.
- Fonte [Poppins](https://fonts.google.com/specimen/Poppins): SIL Open Font License (`roku/fonts/OFL.txt`)
- [WebTorrent](https://webtorrent.io) (MIT) e [FFmpeg](https://ffmpeg.org) (baixado na instalação via `ffmpeg-static`; LGPL/GPL)
- Compatível com o [protocolo de addons do Stremio](https://github.com/Stremio/stremio-addon-sdk), obrigado por deixarem isso aberto ❤️
