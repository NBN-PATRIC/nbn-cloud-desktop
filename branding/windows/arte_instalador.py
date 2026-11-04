"""NBN Cloud: arte e licença das telas do instalador MSI (WixUI).

    python arte_instalador.py <pasta de saída> [--plugin-vfs]

Gera, a partir dos PNGs da marca (branding/theme) e do COPYING do repositório:
    nbncloud.ico   ícone do atalho e do Painel de Controle
    banner.bmp     faixa do topo das telas internas (493x58)
    dialogo.bmp    fundo das telas de boas-vindas e de conclusão (493x312)
    licenca.rtf    aviso em português + GPL v2 (texto oficial, em inglês)

--plugin-vfs acrescenta à licença o aviso de que o pacote leva o plugin de arquivos virtuais
da ownCloud GmbH, que não é software livre (só no MSI interno montado com ele).
"""
import sys
from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
TEMA = AQUI.parent / 'theme'
COPYING = AQUI.parent.parent / 'COPYING'

NAVY = (31, 42, 68)
BRANCO = (255, 255, 255)


def icone(saida):
    png = Image.open(TEMA / 'colored' / '256-nbncloud-icon.png')
    png.save(saida / 'nbncloud.ico',
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def colar(fundo, img, x, y):
    fundo.paste(img, (round(x), round(y)), img)


def banner(saida):
    # o título e a descrição da tela ficam à esquerda, em preto: fundo branco, ícone à direita
    img = Image.new('RGB', (493, 58), BRANCO)
    ic = Image.open(TEMA / 'colored' / '256-nbncloud-icon.png').convert('RGBA')
    ic = ic.resize((46, 46), Image.LANCZOS)
    colar(img, ic, 493 - 46 - 8, 6)
    img.save(saida / 'banner.bmp')


def dialogo(saida):
    # o texto das telas de boas-vindas e de conclusão começa em ~180 px: painel azul-marinho
    # com o logo em branco à esquerda e o resto em branco
    img = Image.new('RGB', (493, 312), BRANCO)
    painel = 164
    img.paste(NAVY, (0, 0, painel, 312))
    logo = Image.open(TEMA / 'universal' / 'wizard_logo.png').convert('RGBA')
    lw = 120
    logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    colar(img, logo, (painel - lw) / 2, 312 * 0.38 - logo.height / 2)
    img.save(saida / 'dialogo.bmp')


def rtf_texto(s):
    out = []
    for ch in s:
        if ch in '\\{}':
            out.append('\\' + ch)
        elif ch == '\n':
            out.append('\\par\n')
        elif ord(ch) > 127:
            out.append('\\u%d?' % ord(ch))
        else:
            out.append(ch)
    return ''.join(out)


def licenca(saida, plugin_vfs):
    aviso = [
        'NBN Cloud',
        '',
        'Copyright NBN Telecom. Baseado no ownCloud Desktop, copyright ownCloud GmbH e colaboradores.',
        '',
        'Este programa é software livre: você pode redistribuí-lo e modificá-lo nos termos da Licença '
        'Pública Geral GNU (GPL), versão 2, publicada pela Free Software Foundation. Ele é distribuído '
        'na esperança de ser útil, mas SEM NENHUMA GARANTIA, nem mesmo a garantia implícita de '
        'COMERCIALIZAÇÃO ou de ADEQUAÇÃO A UM FIM ESPECÍFICO. O texto oficial da licença, em inglês, '
        'vem a seguir.',
        '',
        'Código-fonte: https://github.com/NBN-PATRIC/nbn-cloud-desktop',
        '',
        'ownCloud é marca registrada da ownCloud GmbH. Este programa não é afiliado à ownCloud GmbH '
        'nem endossado por ela.',
    ]
    if plugin_vfs:
        aviso += [
            '',
            'Esta instalação inclui o plugin de arquivos virtuais do Windows da ownCloud GmbH '
            '(ownCloud_vfs_wincfapi.dll), que não é software livre e não está coberto pela GPL.',
        ]
    texto = '\n'.join(aviso) + '\n\n' + COPYING.read_text(encoding='utf-8')
    rtf = ('{\\rtf1\\ansi\\ansicpg1252\\deff0{\\fonttbl{\\f0\\fswiss Segoe UI;}}'
           '\\viewkind4\\uc1\\pard\\f0\\fs16\n' + rtf_texto(texto) + '}\n')
    (saida / 'licenca.rtf').write_text(rtf, encoding='ascii')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    saida = Path(args[0])
    saida.mkdir(parents=True, exist_ok=True)
    icone(saida)
    banner(saida)
    dialogo(saida)
    licenca(saida, '--plugin-vfs' in sys.argv)


if __name__ == '__main__':
    main()
