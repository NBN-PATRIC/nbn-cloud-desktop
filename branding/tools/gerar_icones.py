"""Gera os ícones da marca NBN Cloud a partir do logo da NBN (logo-nbn.jpg).

Uso:  py -3 branding/tools/gerar_icones.py
Saída (dentro de branding/theme/):
  colored/<tam>-nbncloud-icon.png      ícone do aplicativo (.exe, atalhos, janela)
  colored/<tam>-nbncloud-sidebar.png   ícone do painel lateral do Explorer
  universal/nbncloud-icon-<tam>.png    ícone do aplicativo carregado em tempo de execução
  universal/wizard_logo.png            logo da primeira tela do assistente
  colored/state-<estado>-<tam>.png     bandeja com barra de tarefas clara
  dark/state-<estado>-<tam>.png        bandeja com barra de tarefas escura (padrão do Windows 11)
  preview.png                          folha de conferência (não vai para o build)

Só depende do Pillow. Desenha tudo em 1024 px e reduz com LANCZOS.
"""
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFont

AQUI = pathlib.Path(__file__).resolve().parent
TEMA = AQUI.parent / 'theme'
LOGO = AQUI / 'logo-nbn.jpg'

S = 1024
NAVY = (31, 42, 68, 255)       # #1F2A44, cor do timbrado
AZUL = (68, 114, 195, 255)     # #4472C3
CLARO = (230, 234, 242, 255)   # nuvem na barra escura
BRANCO = (255, 255, 255, 255)
ESTADOS = {
    'ok': (46, 164, 79, 255),
    'error': (217, 48, 37, 255),
    'information': AZUL,
    'offline': (138, 148, 166, 255),
    'pause': (232, 163, 23, 255),
    'sync': AZUL,
}
TAM_APP = [16, 24, 32, 48, 64, 128, 256, 512, 1024]
TAM_SIDEBAR = [16, 32, 64, 128, 256, 512]
TAM_ESTADO = [16, 22, 32, 48, 64, 128, 256]


def circulo(d, cx, cy, r, cor):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor)


def nuvem(cor, caixa):
    """Nuvem genérica (círculos + retângulo arredondado) dentro de caixa=(x0, y0, x1, y1) em fração de S."""
    x0, y0, x1, y1 = caixa
    w, h = (x1 - x0) * S, (y1 - y0) * S
    ox, oy = x0 * S, y0 * S
    camada = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    d.rounded_rectangle([ox, oy + 0.48 * h, ox + w, oy + h], radius=0.26 * h, fill=cor)
    circulo(d, ox + 0.30 * w, oy + 0.58 * h, 0.30 * h, cor)
    circulo(d, ox + 0.54 * w, oy + 0.42 * h, 0.42 * h, cor)
    circulo(d, ox + 0.78 * w, oy + 0.64 * h, 0.26 * h, cor)
    return camada


def letras_nbn(cor, largura):
    """Recorta as letras "nbn" do logo (sem "telecom" e sem o sorriso) e pinta com a cor pedida."""
    im = Image.open(LOGO).convert('L')
    corte = im.crop((0, 6, im.width, 182))
    mascara = corte.point(lambda v: 255 if v < 110 else (0 if v > 200 else int((200 - v) * 255 / 90)))
    bbox = mascara.getbbox()
    mascara = mascara.crop(bbox)
    alt = round(mascara.height * largura / mascara.width)
    mascara = mascara.resize((round(largura), alt), Image.LANCZOS)
    pintada = Image.new('RGBA', mascara.size, cor)
    pintada.putalpha(mascara)
    return pintada


def icone_app(com_letras):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 0.03 * S
    d.rounded_rectangle([m, m, S - m, S - m], radius=0.22 * S, fill=NAVY)
    img.alpha_composite(nuvem(BRANCO, (0.13, 0.22, 0.87, 0.78)))
    if com_letras:
        letras = letras_nbn(NAVY, 0.44 * S)
        img.alpha_composite(letras, (round(0.52 * S - letras.width / 2), round(0.60 * S - letras.height / 2)))
    return img


def icone_sidebar():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    img.alpha_composite(nuvem(NAVY, (0.04, 0.18, 0.96, 0.82)))
    return img


def glifo(d, estado, cx, cy, r):
    w = max(2, round(0.20 * r))
    if estado == 'ok':
        pts = [(cx - 0.45 * r, cy + 0.02 * r), (cx - 0.12 * r, cy + 0.36 * r), (cx + 0.48 * r, cy - 0.32 * r)]
        d.line(pts, fill=BRANCO, width=w, joint='curve')
    elif estado == 'error':
        k = 0.36 * r
        d.line([(cx - k, cy - k), (cx + k, cy + k)], fill=BRANCO, width=w)
        d.line([(cx - k, cy + k), (cx + k, cy - k)], fill=BRANCO, width=w)
    elif estado == 'information':
        circulo(d, cx, cy - 0.40 * r, 0.13 * r, BRANCO)
        d.rounded_rectangle([cx - 0.11 * r, cy - 0.16 * r, cx + 0.11 * r, cy + 0.52 * r], radius=0.08 * r, fill=BRANCO)
    elif estado == 'offline':
        d.rounded_rectangle([cx - 0.48 * r, cy - 0.11 * r, cx + 0.48 * r, cy + 0.11 * r], radius=0.08 * r, fill=BRANCO)
    elif estado == 'pause':
        for dx in (-0.22, 0.22):
            d.rounded_rectangle([cx + (dx - 0.10) * r, cy - 0.40 * r, cx + (dx + 0.10) * r, cy + 0.40 * r],
                                radius=0.05 * r, fill=BRANCO)
    elif estado == 'sync':
        ra = 0.46 * r
        d.arc([cx - ra, cy - ra, cx + ra, cy + ra], start=200, end=500, fill=BRANCO, width=w)
        ang = math.radians(500 - 360)
        px, py = cx + ra * math.cos(ang), cy + ra * math.sin(ang)
        t = 0.30 * r
        tang = ang + math.pi / 2
        ponta = (px + t * 0.9 * math.cos(tang), py + t * 0.9 * math.sin(tang))
        base1 = (px + t * 0.6 * math.cos(ang), py + t * 0.6 * math.sin(ang))
        base2 = (px - t * 0.6 * math.cos(ang), py - t * 0.6 * math.sin(ang))
        d.polygon([ponta, base1, base2], fill=BRANCO)


def icone_estado(estado, cor_nuvem):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    camada = nuvem(cor_nuvem, (0.02, 0.10, 0.98, 0.66))
    bx, by, br = 0.70 * S, 0.70 * S, 0.29 * S
    # vão transparente em volta do selo, para ele se destacar em qualquer fundo
    furo = Image.new('L', (S, S), 255)
    circulo(ImageDraw.Draw(furo), bx, by, br + 0.06 * S, 0)
    camada.putalpha(ImageChops.multiply(camada.getchannel('A'), furo))
    img.alpha_composite(camada)
    d = ImageDraw.Draw(img)
    circulo(d, bx, by, br, ESTADOS[estado])
    glifo(d, estado, bx, by, br)
    return img


def logo_assistente():
    im = Image.open(LOGO).convert('L')
    mascara = im.point(lambda v: 255 if v < 110 else (0 if v > 200 else int((200 - v) * 255 / 90)))
    logo = Image.new('RGBA', im.size, NAVY)
    logo.putalpha(mascara)
    W, H = 480, 480
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    lw = 360
    logo = logo.resize((lw, round(im.height * lw / im.width)), Image.LANCZOS)
    img.alpha_composite(logo, ((W - lw) // 2, 24))
    fonte = ImageFont.truetype(r'C:\Windows\Fonts\seguisb.ttf', 96)
    d = ImageDraw.Draw(img)
    texto = 'Cloud'
    tw = d.textlength(texto, font=fonte)
    d.text(((W - tw) / 2, 24 + logo.height + 6), texto, font=fonte, fill=AZUL)
    return img.crop(img.getbbox())


def reduzir(img, tam):
    return img.resize((tam, tam), Image.LANCZOS)


def main():
    for sub in ('colored', 'dark', 'universal'):
        (TEMA / sub).mkdir(parents=True, exist_ok=True)

    grande = icone_app(True)
    pequeno = icone_app(False)
    for t in TAM_APP:
        img = reduzir(pequeno if t <= 32 else grande, t)
        img.save(TEMA / 'colored' / f'{t}-nbncloud-icon.png')
        img.save(TEMA / 'universal' / f'nbncloud-icon-{t}.png')

    side = icone_sidebar()
    for t in TAM_SIDEBAR:
        reduzir(side, t).save(TEMA / 'colored' / f'{t}-nbncloud-sidebar.png')

    logo_assistente().save(TEMA / 'universal' / 'wizard_logo.png')

    for estado in ESTADOS:
        for pasta, cor in (('colored', NAVY), ('dark', CLARO)):
            base = icone_estado(estado, cor)
            for t in TAM_ESTADO:
                reduzir(base, t).save(TEMA / pasta / f'state-{estado}-{t}.png')

    # folha de conferência: ícones em 16/32/48/256 sobre fundo claro e escuro
    linhas = [[reduzir(pequeno, 16), reduzir(pequeno, 32), reduzir(grande, 48), reduzir(grande, 256)]]
    for pasta, cor in (('colored', NAVY), ('dark', CLARO)):
        linhas.append([reduzir(icone_estado(e, cor), 32) for e in ESTADOS] + [reduzir(icone_estado(e, cor), 16) for e in ESTADOS])
    folha = Image.new('RGBA', (900, 560), (255, 255, 255, 255))
    d = ImageDraw.Draw(folha)
    d.rectangle([0, 380, 900, 560], fill=(32, 32, 32, 255))
    x = 10
    for im in linhas[0]:
        folha.alpha_composite(im, (x, 10)); x += im.width + 20
    folha.alpha_composite(logo_assistente().resize((200, 200 * logo_assistente().height // logo_assistente().width)), (660, 10))
    x = 10
    for im in linhas[1]:
        folha.alpha_composite(im, (x, 300)); x += im.width + 14
    x = 10
    for im in linhas[2]:
        folha.alpha_composite(im, (x, 420)); x += im.width + 14
    folha.save(AQUI / 'preview.png')
    print('ok')


if __name__ == '__main__':
    main()
