"""Mevzuat kitaplığı: sahada başvurulan diğer kanun, yönetmelik ve tebliğlerin tam metni.

Kullanım:  python kitaplik.py <cikti_klasoru> [kod ...]

Metinler mevzuat.gov.tr'nin HTML metin sayfasından alınır (her mevzuatın PDF'i yok) ve
"MADDE n –" başlıklarından maddelere bölünür. Liste kaynaklar.json içindeki "kitaplik" alanındadır.
Çıktı: her mevzuat için mevzuat_<kod>.json ve hepsinin dizini kitaplik.json.
"""
import html.parser
import json
import os
import re
import sys
import time

import requests

from veri_olustur import BOLUM, baslik_bicimi, kimlik, yaz

BURASI = os.path.dirname(os.path.abspath(__file__))
TARAYICI_KIMLIGI = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                  "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"}
METIN_ADRESI = ("https://www.mevzuat.gov.tr/anasayfa/MevzuatFihristDetayIframe"
                "?MevzuatTur={tur}&MevzuatNo={no}&MevzuatTertip={tertip}")
SAYFA_ADRESI = "https://www.mevzuat.gov.tr/mevzuat?MevzuatNo={no}&MevzuatTur={tur}&MevzuatTertip={tertip}"
TUR_ADLARI = {1: "Kanun", 7: "Yönetmelik", 9: "Tebliğ"}
# Uygulamaya kanun metni olarak zaten giren, dizinde en başta gösterilen iki kanun.
TEMEL = [
    {"kod": "2918", "ad": "Karayolları Trafik Kanunu", "tur": 1, "no": 2918, "tertip": 5, "rg": "18.10.1983 / 18195"},
    {"kod": "4925", "ad": "Karayolu Taşıma Kanunu", "tur": 1, "no": 4925, "tertip": 5, "rg": "19.07.2003 / 25173"},
]
# Yönetmeliklerde madde başlığı kısa çizgi, orta çizgi ya da uzun çizgiyle yazılabiliyor.
MADDE_BASI = re.compile(r"^((?:Ek Geçici |Ek |Geçici |Mükerrer )?Madde) (\d+)(/[A-Z])? ?[–—-] ?", re.I)
BLOKLAR = {"p", "div", "li", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "table"}


class _Satirlar(html.parser.HTMLParser):
    """HTML'i paragraf paragraf düz metne çevirir; tablo satırlarının hücreleri ' | ' ile ayrılır."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.satirlar = []
        self._parca = []
        self._atla = 0
        self._tabloda = 0

    def _bitir(self):
        ham = "".join(self._parca)
        self._parca = []
        # Bazı metinlerin tamamı tek hücreli bir düzen tablosuna sarılıdır; uzun "satır" gerçek bir
        # tablo satırı değildir, içindeki paragraflar ayrı satır olarak alınır.
        if len(ham) > 300 and "\x00" in ham:
            parcalar = ham.replace(" | ", " ").split("\x00")
        else:
            parcalar = [ham.replace("\x00", " ")]
        for parca in parcalar:
            metin = re.sub(r"\s+", " ", parca).strip(" |")
            if metin:
                self.satirlar.append(metin)

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "head"):
            self._atla += 1
        elif tag == "table":
            self._bitir()
            self._tabloda += 1
        elif tag == "br" and not self._tabloda:
            self._bitir()
        elif tag in ("td", "th"):
            self._parca.append(" | ")
        elif tag in BLOKLAR:
            self._blok(tag)

    def _blok(self, tag):
        if self._tabloda and tag != "tr":
            self._parca.append("\x00")
        else:
            self._bitir()

    def handle_endtag(self, tag):
        if tag in ("script", "style", "head"):
            self._atla = max(0, self._atla - 1)
        elif tag == "table":
            self._bitir()
            self._tabloda = max(0, self._tabloda - 1)
        elif tag in BLOKLAR:
            self._blok(tag)

    def handle_data(self, data):
        if not self._atla:
            self._parca.append(data)


def satirlar(html_metni):
    c = _Satirlar()
    c.feed(html_metni)
    c.close()
    c._bitir()
    return c.satirlar


def _baslik_mi(s):
    return (len(s) < 160 and not s.endswith((".", ";", ",", ":")) and "|" not in s
            and not re.match(r"^(\(|[a-zçğıöşü]{1,2}\)|\d{1,3}[.)] )", s))


def maddeler(html_metni):
    """Mevzuat metnini maddelere böler; 2918/4925 dosyalarıyla aynı alanları üretir."""
    sonuc = []
    kisim = bolum = ""
    onceki = []  # ilk maddeden önceki satırlar (başlık adayı için)
    kimlikler = {}
    ekte = False  # ana metin bittikten sonra numarası 1'den yeniden başlayan ek metinlerin içinde
    liste = satirlar(html_metni)
    i = 0
    while i < len(liste):
        s = liste[i]
        if BOLUM.match(s):
            sonraki = liste[i + 1] if i + 1 < len(liste) else ""
            ad = sonraki if sonraki and not MADDE_BASI.match(sonraki) and _baslik_mi(sonraki) else ""
            etiket = f"{baslik_bicimi(s)} – {ad}" if ad else baslik_bicimi(s)
            if "KISIM" in s:
                kisim, bolum = etiket, ""
            else:
                bolum = etiket
            i += 2 if ad else 1
            continue
        m = MADDE_BASI.match(s)
        if m:
            on_ek = m.group(1).lower()
            tur = "Geçici" if "ge" in on_ek[:2] else "Ek" if on_ek.startswith("ek") else "Mükerrer" if on_ek.startswith("mük") else ""
            no = m.group(2) + (m.group(3) or "")
            hedef = sonuc[-1]["_satirlar"] if sonuc else onceki
            baslik = hedef.pop() if hedef and _baslik_mi(hedef[-1]) and (len(hedef) > 1 or not sonuc) else ""
            kim = kimlik(f"{ {'Geçici': 'gecici', 'Mükerrer': 'mukerrer'}.get(tur, tur) } m{no}")
            kimlikler[kim] = kimlikler.get(kim, 0) + 1
            if kimlikler[kim] > 1:
                ekte = ekte or kim == "m1"
                kim = f"{kim}-{kimlikler[kim]}"
            sonuc.append({
                "id": kim,
                "no": f"{tur} {no}".strip(),
                "baslik": baslik,
                "kisim": "Ekler ve cetveller" if ekte else " / ".join(x for x in (kisim, bolum) if x),
                "_satirlar": [s[m.end():].strip()],
            })
        elif sonuc:
            sonuc[-1]["_satirlar"].append(s)
        else:
            onceki.append(s)
        i += 1
    for madde in sonuc:
        madde["metin"] = "\n".join(x for x in madde.pop("_satirlar") if x)
    return sonuc


def indir(kayit):
    adres = METIN_ADRESI.format(**kayit)
    yanit = requests.get(adres, headers=TARAYICI_KIMLIGI, timeout=120)
    yanit.raise_for_status()
    return yanit.content.decode("utf-8", errors="replace")


def dizin_kaydi(kayit, madde_sayisi):
    return {
        "kod": kayit["kod"],
        "ad": kayit["ad"],
        "tur": TUR_ADLARI[kayit["tur"]],
        "no": kayit["no"],
        "rg": kayit.get("rg", ""),
        "dosya": f"mevzuat_{kayit['kod']}.json",
        "kaynak": SAYFA_ADRESI.format(**kayit),
        "madde": madde_sayisi,
    }


def olustur(cikti, kodlar=None, liste=None):
    """Kitaplık metinlerini indirip [cikti] klasörüne yazar; {dosya adı: madde sayısı} döndürür.

    İndirilemeyen ya da maddeye bölünemeyen mevzuat atlanır; çağıran mevcut dosyayı korur.
    """
    if liste is None:
        with open(os.path.join(BURASI, "kaynaklar.json"), encoding="utf-8") as f:
            liste = json.load(f)["kitaplik"]
    os.makedirs(cikti, exist_ok=True)
    sonuc = {}
    for kayit in liste:
        kayit = {"tertip": 5, **kayit}
        if kodlar and kayit["kod"] not in kodlar:
            continue
        try:
            veri = maddeler(indir(kayit))
        except requests.RequestException as hata:
            print(f"  UYARI: {kayit['ad']} indirilemedi ({hata})")
            continue
        if len(veri) < 3:
            print(f"  UYARI: {kayit['ad']} maddelere ayrılamadı ({len(veri)} madde); atlandı")
            continue
        ad = f"mevzuat_{kayit['kod']}.json"
        yaz(cikti, ad, veri)
        sonuc[ad] = len(veri)
        print(f"  {ad}: {len(veri)} madde, {sum(len(m['metin']) for m in veri) // 1024} KB  ({kayit['ad']})")
        time.sleep(1)  # kaynağı yormamak için
    return sonuc


def dizin_yaz(veri_klasoru, liste=None):
    """Veri klasöründe dosyası bulunan mevzuatın dizinini (kitaplik.json) yazar."""
    if liste is None:
        with open(os.path.join(BURASI, "kaynaklar.json"), encoding="utf-8") as f:
            liste = json.load(f)["kitaplik"]
    dizin = []
    for kayit in TEMEL + liste:
        kayit = {"tertip": 5, **kayit}
        yol = os.path.join(veri_klasoru, f"mevzuat_{kayit['kod']}.json")
        if os.path.exists(yol):
            with open(yol, encoding="utf-8") as f:
                dizin.append(dizin_kaydi(kayit, len(json.load(f))))
    yaz(veri_klasoru, "kitaplik.json", dizin)
    return dizin


if __name__ == "__main__":
    olustur(sys.argv[1], set(sys.argv[2:]))
    dizin_yaz(sys.argv[1])
