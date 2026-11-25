# NBN Cloud: arquivos virtuais no macOS (File Provider)

O ownCloud Desktop só tem, no macOS, o modo de arquivos virtuais por sufixo (`.owncloud`), que os programas não abrem.
Esta pasta traz os arquivos virtuais de verdade, pela API do sistema (File Provider, a mesma do iCloud Drive, OneDrive,
Google Drive e Dropbox): o arquivo aparece no Finder com o nome real, não ocupa disco e baixa quando é aberto.

## Fase 1: teste de viabilidade (atual)

- `Ext/`: a extensão. A lógica é a do **NextcloudFileProviderKit** (LGPL-3.0-or-later, do `nextcloud/desktop`), que
  fala WebDAV com o servidor pelo NextcloudKit (GPL-3.0). O CI o baixa num commit fixo (`NC_DESKTOP_SHA` no workflow
  `nbn-macos-fileprovider.yml`).
- `Teste/`: app de linha de comando que faz o papel do app principal: registra o domínio e entrega a conta pelo canal
  XPC do kit (`ClientCommunicationProtocol`, GPL-2.0-or-later).
- Sem conta de desenvolvedor da Apple: assinatura ad hoc. No primeiro uso o usuário liga o provedor uma vez em
  Ajustes > Geral > Itens de Início e Extensões > Provedores de Arquivos.

Uso no Mac (o zip vem do artefato do CI):

```sh
ditto -x -k NBNCloudFPTeste.zip ~/Applications && A=~/Applications/NBNCloudFPTeste.app/Contents/MacOS/NBNCloudFPTeste
open -W --stdout /tmp/fp.log ~/Applications/NBNCloudFPTeste.app --args add; cat /tmp/fp.log
# ligar o provedor em Ajustes (uma vez)
umask 077; printf '%s' "<senha>" > /tmp/fp-senha
open -W --stdout /tmp/fp.log ~/Applications/NBNCloudFPTeste.app --args config https://servidor <usuario> /tmp/fp-senha
ls ~/Library/CloudStorage/
```

## Próximas fases

1. Servidores ownCloud 10 (clássico): conferir enumeração, abrir, enviar, mover, apagar e conflitos.
2. Infinite Scale: login OIDC (token no lugar da senha) e Spaces.
3. Integrar ao app principal (`src/gui`): por conta, no macOS, registrar o domínio e entregar a credencial no lugar da
   pasta sincronizada; tela "Ative o NBN Cloud no Finder" que abre os Ajustes no lugar certo.
