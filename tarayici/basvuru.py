"""Başvuru tabloları: sürücü belgesi kodları ve tehlikeli madde (UN) numaraları.

Kullanım:  python basvuru.py <cikti_klasoru> [pdf_klasoru]

Bu iki tablo seyrek değişir (kod tablosu tarihli tek belge, ADR iki yılda bir yenilenir); bu yüzden
saatlik güncellemeye bağlı değildir, kaynak yenilendiğinde elle çalıştırılır. Adresler kaynaklar.json
içindeki "basvuru" alanındadır. Çalıştırdıktan sonra guncelle.py ile surum.json yenilenmelidir.

Çıktı:
  surucu_kodlari.json  {"kaynak", "tarih", "bolumler": [{"baslik", "kodlar": [{"kod", "aciklama"}]}]}
  un_kodlari.json      {"kaynak", "surum", "maddeler": [{"un", "ad", "sinif", "kod", "pg", "etiket",
                        "kategori", "tehlikeNo"}]}
"""
import json
import os
import re
import sys
import tempfile

import pdfplumber
import requests

from veri_olustur import tek_satir, yaz

BURASI = os.path.dirname(os.path.abspath(__file__))
TARAYICI_KIMLIGI = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                  "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"}
BOLUM_BASI = re.compile(r"^[a-d][.)]\s*(.+)$")
KOD_BASI = re.compile(r"^(\d{2,3}(?:\.\d{2})?)[.\-]*\s+(.+)$")


def _indir(adres, hedef):
    if os.path.exists(hedef):
        return
    yanit = requests.get(adres, headers=TARAYICI_KIMLIGI, timeout=600)
    yanit.raise_for_status()
    if not yanit.content.startswith(b"%PDF"):
        raise ValueError(f"PDF değil: {adres}")
    with open(hedef, "wb") as f:
        f.write(yanit.content)


def surucu_kodlari(pdf_yolu):
    """NVİ'nin 'Sürücü/sürücü adayı ve araçlara ilişkin kod tablosu'nu bölümlere ve kodlara ayırır."""
    satirlar = []
    with pdfplumber.open(pdf_yolu) as pdf:
        for sayfa in pdf.pages:
            satirlar += [s.strip() for s in (sayfa.extract_text(x_tolerance=1.5, y_tolerance=2) or "").split("\n") if s.strip()]
    tarih = next((m.group(1) for s in satirlar[:4] if (m := re.match(r"^\((\d{2}\.\d{2}\.\d{4})\)$", s))), "")
    bolumler = []
    gorulen = set()
    son = None  # devam satırlarının ekleneceği kayıt (bölüm başlığı ya da kod)
    for s in satirlar:
        if BOLUM_BASI.match(s) and s[2:].strip().upper() == s[2:].strip():
            bolumler.append({"baslik": BOLUM_BASI.match(s).group(1).strip(), "kodlar": []})
            son = ("baslik", bolumler[-1])
            continue
        m = KOD_BASI.match(s)
        if m and bolumler:
            # Kaynak PDF'te bir sayfanın sonu sonraki sayfada yinelenir; aynı bölümde aynı kod bir kez alınır.
            anahtar = (len(bolumler), m.group(1))
            if anahtar in gorulen:
                son = None
                continue
            gorulen.add(anahtar)
            bolumler[-1]["kodlar"].append({"kod": m.group(1), "aciklama": m.group(2).strip()})
            son = ("aciklama", bolumler[-1]["kodlar"][-1])
        elif son and not re.match(r"^\(?\d{2}\.\d{2}\.\d{4}\)?$", s) and "KOD TABLOSU" not in s:
            son[1][son[0]] += " " + s
    return {"tarih": tarih, "bolumler": [b for b in bolumler if b["kodlar"]]}


def _ad_duzelt(metin):
    """Hücre içinde satır sonunda bölünmüş uzun kelimeyi birleştirir, kimyasal ön ekteki tireyi korur."""
    metin = re.sub(r"([A-ZÇĞİÖŞÜ]{4,})-\n(?=[A-ZÇĞİÖŞÜ])", r"\1", metin or "")
    return tek_satir(metin)


def un_kodlari(pdf_yolu):
    """ADR Tablo A'dan (Bölüm 3.2) her kaydın tanıtıcı sütunlarını okur.

    Tablo iki sayfaya yayılır: sol sayfada (1)-(11), sağ sayfada (12)-(20) sütunları ve UN numarası
    yinelenir. Taşıma kategorisi ile tehlike tanım numarası sağ sayfadan, sıra eşleştirilerek alınır.
    """
    sol, sag = [], []
    with pdfplumber.open(pdf_yolu) as pdf:
        for sayfa in pdf.pages:
            metin = sayfa.extract_text() or ""
            if "(3a)" not in metin and "(20)" not in metin:
                continue
            tablo = sayfa.extract_table() or []
            baslik = next((s for s in tablo if s and "(1)" in s), None)
            if baslik is None:
                continue
            sutun = {(h or "").strip(): i for i, h in enumerate(baslik)}
            for s in tablo:
                un = (s[sutun["(1)"]] or "").strip()
                if not re.fullmatch(r"\d{4}", un):
                    continue
                hucre = lambda ad: tek_satir(s[sutun[ad]] or "") if ad in sutun else ""  # noqa: E731
                if "(3a)" in sutun:
                    sol.append({"un": un, "ad": _ad_duzelt(s[sutun["(2)"]]), "sinif": hucre("(3a)"), "kod": hucre("(3b)"),
                                "pg": hucre("(4)"), "etiket": hucre("(5)")})
                elif "(20)" in sutun:
                    sag.append({"un": un, "kategori": hucre("(15)"), "tehlikeNo": hucre("(20)"), "yasak": "YASAK" in hucre("(12)")})
    # Aynı UN numarası birden çok satırda (paketleme grubuna göre) geçer; sağ sayfa aynı sırayı izler.
    kuyruk = {}
    for s in sag:
        kuyruk.setdefault(s["un"], []).append(s)
    for kayit in sol:
        eslesen = kuyruk.get(kayit["un"], [])
        ek = eslesen.pop(0) if eslesen else {}
        kayit["kategori"] = ek.get("kategori", "")
        kayit["tehlikeNo"] = ek.get("tehlikeNo", "")
        if ek.get("yasak") or "YASAK" in kayit["sinif"].upper():
            kayit["yasak"] = True
    return sol


def olustur(cikti, pdf_klasoru=None):
    with open(os.path.join(BURASI, "kaynaklar.json"), encoding="utf-8") as f:
        kaynak = json.load(f)["basvuru"]
    os.makedirs(cikti, exist_ok=True)
    with tempfile.TemporaryDirectory() as gecici:
        klasor = pdf_klasoru or gecici
        kod_pdf = os.path.join(klasor, "kodtablosu.pdf")
        _indir(kaynak["surucu_kodlari"], kod_pdf)
        kodlar = surucu_kodlari(kod_pdf)
        adet = sum(len(b["kodlar"]) for b in kodlar["bolumler"])
        if adet < 100:
            raise SystemExit(f"Kod tablosu ayrıştırılamadı ({adet} kod). Kaynağın biçimi değişmiş olabilir.")
        yaz(cikti, "surucu_kodlari.json", {"kaynak": kaynak["surucu_kodlari"], **kodlar})
        print(f"surucu_kodlari.json: {len(kodlar['bolumler'])} bölüm, {adet} kod (tablo tarihi {kodlar['tarih']})")

        adr_pdf = os.path.join(klasor, "adr1.pdf")
        _indir(kaynak["adr"], adr_pdf)
        maddeler = un_kodlari(adr_pdf)
        if len(maddeler) < 2000:
            raise SystemExit(f"ADR Tablo A ayrıştırılamadı ({len(maddeler)} kayıt). Kaynağın biçimi değişmiş olabilir.")
        yaz(cikti, "un_kodlari.json", {"kaynak": kaynak["adr"], "surum": kaynak["adr_surumu"], "maddeler": maddeler})
        print(f"un_kodlari.json: {len(maddeler)} kayıt, {len({m['un'] for m in maddeler})} UN numarası; "
              f"tehlike tanım numarası olan {sum(1 for m in maddeler if m['tehlikeNo'])}")


if __name__ == "__main__":
    olustur(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
