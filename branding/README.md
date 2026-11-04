# NBN Cloud: cliente desktop

Fork do [ownCloud Desktop](https://github.com/owncloud/client) 6.0.3 com a marca da NBN Telecom, distribuído sob
a mesma licença (GNU GPL versão 2). ownCloud é marca registrada da ownCloud GmbH; este projeto não é afiliado
à ownCloud GmbH nem endossado por ela.

## Por que a base 6.0.x

A versão 7.x do ownCloud Desktop deixou de falar com o servidor ownCloud clássico (10.x e 11.x). A 6.0.3 fala com
o servidor clássico e com o Infinite Scale, então o mesmo programa atende os dois tipos de servidor.

## O que muda em relação ao ownCloud Desktop

- Marca: nome, ícones, cores, texto do Sobre (`branding/`).
- Servidor sugerido na primeira tela, sem travar: vem do instalador, da política do Windows ou de
  `NBNCLOUD_SERVER_URL`. O programa continua aceitando várias contas, em servidores diferentes.
- Convive com o ownCloud Desktop na mesma máquina (canal do Explorer, CLSIDs e nomes de overlay próprios).
- Arquivos virtuais no Windows só aparecem se o plugin CfApi estiver presente na pasta do programa. Esse plugin
  não faz parte do código aberto do ownCloud, então este build não o traz; sem ele, a opção some (em vez de cair
  no modo experimental por sufixo).

## Instalar

```
msiexec /i NBNCloud-<versão>-x64.msi
msiexec /i NBNCloud-<versão>-x64.msi SERVERURL=https://servidor.exemplo.com.br /qn
```

`SERVERURL` fica em `HKLM\Software\NBN Telecom\NBN Cloud\ServerUrl` e é mantido nas atualizações. Por GPO, o mesmo
valor pode ir em `HKLM\Software\Policies\NBN Telecom\NBN Cloud\ServerUrl`.

## Compilar

O build roda no GitHub Actions (`.github/workflows/nbn-windows.yml`): KDE Craft com o cache de dependências do
ownCloud 6.0, pacote portátil e depois o MSI (`branding/windows/gerar-msi.ps1`, WiX 5).

Os ícones são gerados por `branding/tools/gerar_icones.py` (Pillow) a partir de `branding/tools/logo-nbn.jpg`.
