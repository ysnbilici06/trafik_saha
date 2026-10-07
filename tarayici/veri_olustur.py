"""İndirilen resmî kaynak PDF'lerinden uygulamanın veri dosyalarını üretir.

Kullanım:  python veri_olustur.py <kaynak_klasoru> <cikti_klasoru>

Kaynak klasöründe beklenen dosyalar: rehber.pdf, 2918.pdf, 4925.pdf, 4925_ceza.pdf
"""
import collections
import json
import os
import re
import sys

import pdfplumber

from rehber_ayristir import ayristir

TUTAR = re.compile(r"(\d{1,3}(?:\.\d{3})*(?:,\d+)?)\s*-?\s*TL", re.I)
MADDE_BASI = re.compile(r"^((?:Ek Geçici |Ek |Geçici |Mükerrer )?Madde) (\d+)(/[A-Z])? ?[–-] ?", re.I)
BOLUM = re.compile(r"^[A-ZÇĞİÖŞÜ ]+ (KISIM|BÖLÜM)\s*\d*$")


def sayi(metin):
    return float(metin.replace(".", "").replace(",", "."))


def tek_satir(metin):
    return re.sub(r"\s+", " ", metin or "").strip()


def baslik_bicimi(metin):
    """Türkçe büyük/küçük harf kurallarıyla 'BİRİNCİ KISIM' -> 'Birinci Kısım'."""
    kucuk = metin.replace("I", "ı").replace("İ", "i").lower()
    return " ".join(
        ("İ" if k[0] == "i" else "I" if k[0] == "ı" else k[0].upper()) + k[1:] for k in kucuk.split())


def kimlik(madde):
    k = madde.lower().replace("ı", "i")
    return re.sub(r"[^a-z0-9]+", "-", k).strip("-")


# ---------------------------------------------------------------- 2918 cezalar
def cezalar_2918(pdf_yolu):
    kalemler = []
    gorulen = collections.Counter()
    for h in ayristir(pdf_yolu):
        madde = tek_satir(h["madde"]).replace("Ek 2/", "Ek-2/")
        if not madde:
            continue
        puan_metni = tek_satir(h["puan"])
        belge = tek_satir(h["belge_geri_alma"])
        diger = h["diger"].strip()
        kullanmaktan_men = tek_satir(h["kullanmaktan_men"])
        mulki = tek_satir(h["mulki_amir"])
        mulki_ek = tek_satir(h["mulki_amir_indirimli"])
        puan = None
        # Birleştirilmiş hücreler komşu sütuna kayabiliyor; metni ait olduğu alana geri al.
        if puan_metni.isdigit():
            puan = int(puan_metni)
        elif puan_metni:
            belge = belge or puan_metni
        if mulki_ek.isdigit() and puan is None:
            puan, mulki_ek = int(mulki_ek), ""
        if kullanmaktan_men.startswith("*"):
            diger = (h["kullanmaktan_men"].strip() + "\n" + diger).strip()
            kullanmaktan_men = ""
        ceza_metni = h["ceza"].strip()
        indirimli_metni = h["indirimli"].strip()
        tutarlar = [sayi(t) for t in TUTAR.findall(ceza_metni)]
        tek_tutar = bool(re.fullmatch(r"[\d.,]+ ?TL\.?", tek_satir(ceza_metni)))
        if not tek_tutar and indirimli_metni and "\n" in ceza_metni:
            ceza_metni = ceza_metni + "\n" + indirimli_metni
        temel = kimlik(madde)
        gorulen[temel] += 1
        kalemler.append({
            "id": temel if gorulen[temel] == 1 else f"{temel}-{gorulen[temel]}",
            "madde": madde,
            "konu": tek_satir(h["konu"]),
            "kime": tek_satir(h["kime"]),
            "tutar": tutarlar[0] if tutarlar else None,
            "kademeli": not tek_tutar and bool(tutarlar),
            "cezaMetin": "" if tek_tutar else ceza_metni,
            "puan": puan,
            "belge": belge,
            "mahkeme": tek_satir(h["belge_mahkeme"]),
            "men": tek_satir(h["trafikten_men"]),
            "kullanmaktanMen": kullanmaktan_men,
            "mulkiAmir": tek_satir(f"{mulki} {mulki_ek}"),
            "diger": diger,
            "sayfa": h["sayfa"],
        })
    return kalemler


# ---------------------------------------------------------------- 4925 cezalar
def _duz_karakterler(sayfa):
    """Çapraz basılmış filigran rakamlarını ayıklar."""
    return sayfa.filter(lambda o: o.get("object_type") != "char" or (
        abs(o["matrix"][1]) < 0.01 and o["matrix"][0] > 0))


def cezalar_4925(pdf_yolu):
    kalemler = []
    with pdfplumber.open(pdf_yolu) as pdf:
        bent = ""
        tablo_adi = ""
        for sayfa_no, sayfa in enumerate(pdf.pages, start=1):
            temiz = _duz_karakterler(sayfa)
            for tablo in temiz.extract_tables():
                for satir in tablo:
                    hucreler = [(h or "").strip() for h in satir]
                    if len(hucreler) < 4:
                        continue
                    ilk = tek_satir(hucreler[0])
                    if not any(hucreler[1:4]):
                        if "CEZALARI" in ilk.upper() or "TABLO" in ilk.upper():
                            tablo_adi = ilk
                        else:
                            m = re.match(r"\(?\s*([a-zçğıöşü]{1,2})\s*\)\s*bend", ilk, re.I)
                            if m:
                                bent = m.group(1).lower()
                        continue
                    if not re.search(r"\d", hucreler[1] + hucreler[2]):
                        continue
                    # 26 ncı madde tablosunun satırları parantezli açıklamayla başlar; diğer tablolar alınmaz.
                    if "26" not in tablo_adi or "(" not in ilk[:40]:
                        continue
                    cumle = ""
                    m = re.match(r"(.*?c[üu]mlesindeki) ceza miktarı:?\s*(.*)", ilk, re.I)
                    aciklama = ilk
                    if m:
                        cumle, aciklama = m.group(1), m.group(2)

                    def tl(h):
                        b = re.search(r"\d{1,3}(?:\.\d{3})*,\d{2}", h.replace(" ", ""))
                        return sayi(b.group(0)) if b else None

                    kalemler.append({
                        "id": f"26-{bent}-{len(kalemler) + 1}",
                        "madde": f"26/{bent}" if bent else "26",
                        "cumle": cumle,
                        "konu": aciklama,
                        "tutar": tl(hucreler[1]),
                        "altSinir": tl(hucreler[2]),
                        "ustSinir": tl(hucreler[3]),
                        "sayfa": sayfa_no,
                    })
    return kalemler


# ---------------------------------------------------------------- kanun metinleri
def _govde_metni(pdf_yolu):
    """Dipnotları ve üst simgeleri (küçük punto) atarak gövde metnini satır satır verir."""
    satirlar = []
    with pdfplumber.open(pdf_yolu) as pdf:
        puntolar = collections.Counter()
        for sayfa in pdf.pages[:5]:
            for k in sayfa.chars:
                puntolar[round(k["size"], 1)] += 1
        govde = puntolar.most_common(1)[0][0]
        for sayfa in pdf.pages:
            temiz = sayfa.filter(lambda o: o.get("object_type") != "char" or o["size"] >= govde - 0.6)
            satirlar.extend((temiz.extract_text() or "").split("\n"))
    return [s.strip() for s in satirlar if s.strip()]


def _paragrafla(satirlar):
    paragraflar = []
    for s in satirlar:
        yeni = (not paragraflar
                or re.match(r"^(\(|[a-zçğıöşü]{1,2}\)|\d{1,2}[.)] |[A-Z]\) )", s)
                or paragraflar[-1].rstrip().endswith((".", ":", ";")))
        if yeni:
            paragraflar.append(s)
        else:
            paragraflar[-1] += " " + s
    return "\n".join(paragraflar)


def kanun_metni(pdf_yolu):
    satirlar = _govde_metni(pdf_yolu)
    maddeler = []
    bolum = ""
    kisim = ""
    i = 0
    bekleyen_baslik = ""
    while i < len(satirlar):
        s = satirlar[i]
        m = MADDE_BASI.match(s)
        if BOLUM.match(s):
            ad = satirlar[i + 1] if i + 1 < len(satirlar) and not MADDE_BASI.match(satirlar[i + 1]) else ""
            etiket = f"{baslik_bicimi(s)} – {ad}" if ad else baslik_bicimi(s)
            if "KISIM" in s:
                kisim, bolum = etiket, ""
            else:
                bolum = etiket
            i += 2 if ad else 1
            bekleyen_baslik = ""
            continue
        if m:
            tur = m.group(1).title()
            no = m.group(2) + (m.group(3) or "")
            maddeler.append({
                "id": kimlik(f"{tur} {no}".replace("Madde ", "m")),
                "no": no if tur == "Madde" else f"{tur.replace(' Madde', '')} {no}",
                "baslik": bekleyen_baslik.rstrip(":").strip(),
                "kisim": " / ".join(x for x in (kisim, bolum) if x),
                "_satirlar": [s[m.end():]],
            })
            bekleyen_baslik = ""
        else:
            sonraki = satirlar[i + 1] if i + 1 < len(satirlar) else ""
            if MADDE_BASI.match(sonraki) and len(s) < 160 and not s.endswith((".", ";", ",")):
                bekleyen_baslik = s
                # İki satıra bölünmüş başlığın ilk yarısı önceki maddeye eklenmişse geri al.
                onceki = maddeler[-1]["_satirlar"] if maddeler else []
                if s[:1].islower() and len(onceki) > 1 and len(onceki[-1]) < 110 \
                        and not onceki[-1].endswith((".", ";", ",", ":")):
                    bekleyen_baslik = onceki.pop() + " " + s
            elif MADDE_BASI.match(satirlar[i + 2] if i + 2 < len(satirlar) else "") \
                    and sonraki.endswith(":") and not s.endswith((".", ";", ",", ":")) and len(s) < 110 \
                    and s[:1].isupper() and not re.match(r"^[a-zçğıöşü]\)", s):
                bekleyen_baslik = s + " " + sonraki
                i += 1
            elif maddeler:
                maddeler[-1]["_satirlar"].append(s)
        i += 1
    for madde in maddeler:
        madde["metin"] = _paragrafla(madde.pop("_satirlar"))
    return maddeler


# ---------------------------------------------------------------- çalıştırma
def yaz(klasor, ad, veri):
    yol = os.path.join(klasor, ad)
    with open(yol, "w", encoding="utf-8", newline="\n") as f:
        json.dump(veri, f, ensure_ascii=False, indent=1)
    return yol


def olustur(kaynak, cikti):
    os.makedirs(cikti, exist_ok=True)
    sonuc = {}
    isler = [
        ("cezalar_2918.json", "rehber.pdf", cezalar_2918),
        ("cezalar_4925.json", "4925_ceza.pdf", cezalar_4925),
        ("mevzuat_2918.json", "2918.pdf", kanun_metni),
        ("mevzuat_4925.json", "4925.pdf", kanun_metni),
    ]
    for ad, pdf, islev in isler:
        yol = os.path.join(kaynak, pdf)
        if not os.path.exists(yol):
            print(f"atlandı (kaynak yok): {pdf}")
            continue
        veri = islev(yol)
        if not veri:
            raise SystemExit(f"{pdf} ayrıştırılamadı: boş sonuç. Kaynağın biçimi değişmiş olabilir.")
        yaz(cikti, ad, veri)
        sonuc[ad] = len(veri)
        print(f"{ad}: {len(veri)} kayıt")
    return sonuc


if __name__ == "__main__":
    olustur(sys.argv[1], sys.argv[2])
