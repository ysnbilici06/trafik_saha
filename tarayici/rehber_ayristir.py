"""EGM Trafik İdari Para Ceza Rehberi PDF'ini yapılandırılmış JSON'a çevirir.

Kullanım:  python rehber_ayristir.py rehber.pdf cikti.json

Rehber 13 sütunlu tek bir tablodur; para, puan, men gibi dar sütunlar 90 derece
döndürülmüş yazıyla basıldığı için hücreler karakter koordinatlarından okunur.
"""
import json
import re
import sys

import pdfplumber

SUTUNLAR = [
    "madde", "konu", "kime", "ceza", "indirimli", "mulki_amir", "mulki_amir_indirimli",
    "puan", "belge_geri_alma", "belge_mahkeme", "trafikten_men", "kullanmaktan_men", "diger",
]
BASLIK_SATIRI = 3


def _hucre_karakterleri(sayfa_karakterleri, kutu):
    x0, ust, x1, alt = kutu
    secilen = []
    for k in sayfa_karakterleri:
        mx = (k["x0"] + k["x1"]) / 2
        my = (k["top"] + k["bottom"]) / 2
        if x0 <= mx <= x1 and ust <= my <= alt:
            secilen.append(k)
    return secilen


def _yon(k):
    """Karakterin yazım yönü: R (düz), U (aşağıdan yukarı), L (ters), D (yukarıdan aşağı)."""
    a, b = k["matrix"][0], k["matrix"][1]
    if abs(a) >= abs(b):
        return "R" if a >= 0 else "L"
    return "U" if b > 0 else "D"


def _olcu(k, yon):
    """(okuma ekseninde başlangıç, bitiş, satır ekseni konumu, punto) döndürür."""
    if yon == "R":
        return k["x0"], k["x1"], (k["top"] + k["bottom"]) / 2, k["bottom"] - k["top"]
    if yon == "L":
        return -k["x1"], -k["x0"], -(k["top"] + k["bottom"]) / 2, k["bottom"] - k["top"]
    if yon == "U":
        return -k["bottom"], -k["top"], (k["x0"] + k["x1"]) / 2, k["x1"] - k["x0"]
    return k["top"], k["bottom"], -(k["x0"] + k["x1"]) / 2, k["x1"] - k["x0"]


def hucre_metni(sayfa_karakterleri, kutu):
    """Hücredeki karakterleri PDF akış sırasıyla birleştirir; eksik boşlukları aralıktan çıkarır."""
    if kutu is None:
        return ""
    metin = ""
    onceki = None
    for k in _hucre_karakterleri(sayfa_karakterleri, kutu):
        bas, son, satir, punto = _olcu(k, _yon(k))
        if onceki is not None:
            if abs(satir - onceki[2]) > 0.6 * max(punto, onceki[3]):
                metin += "\n"
            elif bas - onceki[1] > 0.1 * punto:
                metin += " "
        metin += k["text"]
        onceki = (bas, son, satir, punto)
    metin = re.sub(r"[ \t]+", " ", metin)
    return "\n".join(s.strip() for s in metin.split("\n") if s.strip())

def _sutun_baslangiclari(pdf):
    """Belgedeki tüm hücrelerin sol kenarlarından 13 sütunun x konumlarını çıkarır."""
    sayac = {}
    for sayfa in pdf.pages:
        for tablo in sayfa.find_tables():
            for satir in tablo.rows:
                for kutu in satir.cells:
                    if kutu is not None:
                        anahtar = round(kutu[0] / 3)
                        sayac[anahtar] = sayac.get(anahtar, 0) + 1
    en_sik = sorted(sorted(sayac, key=sayac.get, reverse=True)[: len(SUTUNLAR)])
    if len(en_sik) != len(SUTUNLAR):
        raise SystemExit(f"Rehber tablosunda {len(SUTUNLAR)} sütun bekleniyordu, {len(en_sik)} bulundu.")
    return [a * 3 for a in en_sik]


def ayristir(pdf_yolu):
    kayitlar = []
    with pdfplumber.open(pdf_yolu) as pdf:
        baslangiclar = _sutun_baslangiclari(pdf)
        for sayfa_no, sayfa in enumerate(pdf.pages, start=1):
            karakterler = sayfa.chars
            for tablo in sayfa.find_tables():
                # Başlık bazı sürümlerde her sayfada, bazılarında yalnızca ilk sayfada yer alır.
                ilk_satir = " ".join(hucre_metni(karakterler, k) for k in tablo.rows[0].cells if k)
                atla = BASLIK_SATIRI if "İhlalinin Konusu" in ilk_satir else 0
                for satir in tablo.rows[atla:]:
                    kayit = {ad: "" for ad in SUTUNLAR}
                    # Sayfadan sayfaya hücre sayısı değişebildiği için hücreyi konumuna göre sütuna eşle.
                    for kutu in satir.cells:
                        if kutu is None:
                            continue
                        sira = min(range(len(baslangiclar)), key=lambda i: abs(baslangiclar[i] - kutu[0]))
                        metin = hucre_metni(karakterler, kutu)
                        if metin:
                            kayit[SUTUNLAR[sira]] = (kayit[SUTUNLAR[sira]] + "\n" + metin).strip()
                    kayit["sayfa"] = sayfa_no
                    if not any(kayit[ad] for ad in SUTUNLAR):
                        continue
                    if not kayit["madde"] and kayitlar:
                        # Madde numarası olmayan satır, sayfa sonunda bölünmüş önceki satırın devamıdır.
                        for ad in SUTUNLAR:
                            if kayit[ad]:
                                kayitlar[-1][ad] = (kayitlar[-1][ad] + "\n" + kayit[ad]).strip()
                        continue
                    kayitlar.append(kayit)
    return kayitlar

if __name__ == "__main__":
    sonuc = ayristir(sys.argv[1])
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(sonuc, f, ensure_ascii=False, indent=1)
    print(f"{len(sonuc)} satır ayrıştırıldı")
