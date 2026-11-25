# Origem do plugin de arquivos virtuais do Windows

- Código: `owncloud/client`, `src/plugins/vfs/win`, no commit `48fe016b9` do `master` (23/11/2026), que já traz as
  correções de hidratação (#12707 e #12713).
- Licença: o plugin era da licença comercial da ownCloud e foi relicenciado em GPL-2.0-or-later em 2025
  (PR `owncloud/client#12353`, "import and re-license the vfs-win plugin"). Os cabeçalhos dos arquivos dizem isso.
- Adaptação ao núcleo 6.0.x deste fork (o `master` já é a 7.x):
  - o slot voltou a se chamar `fileStatusChanged` (o `master` renomeou para `onFileStatusChanged`);
  - `fileSuffix()` devolve vazio (o núcleo 6.0.x ainda tem o modo sufixo e exige o método).
- O nome do plugin continua `wincfapi` (`ownCloud_vfs_wincfapi.dll`): o modo gravado na configuração de quem usava
  o plugin fechado 6.0.3.18040 segue valendo.
