"""Resmî kaynakları tarar, veri dosyalarını yeniler ve değişiklik duyurularını üretir.

Kullanım:  python guncelle.py [veri_klasoru]      (varsayılan: ../assets/veri)

Zamanlanmış olarak (GitHub Actions) çalışır. Bir kaynak indirilemez veya ayrıştırılamazsa
o kaynağın mevcut verisine dokunulmaz; böylece bozuk veri yayımlanmaz.
"""
import datetime
import hashlib
import json
import os
import re
import sys
import tempfile
import urllib.parse

import requests

import haberler
import veri_olustur

BURASI = os.path.dirname(os.path.abspath(__file__))
TARAYICI_KIMLIGI = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                  "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"}
ANAHTAR_KELIMELER = ["2918", "4925", "karayolları trafik", "karayolu taşıma", "trafik kanunu",
                     "karayolları trafik yönetmeliği", "karayolu taşıma yönetmeliği"]
DUYURU_SINIRI = 150


def indir(url, hedef):
    yanit = requests.get(url, headers=TARAYICI_KIMLIGI, timeout=90)
    yanit.raise_for_status()
    if not yanit.content.startswith(b"%PDF"):
        raise ValueError("PDF değil")
    with open(hedef, "wb") as f:
        f.write(yanit.content)


def rehber_adresleri(kaynaklar):
    """EGM sayfalarındaki en güncel ceza rehberi bağlantısını, bulunamazsa bilinen adresleri verir."""
    bulunan = []
    for sayfa in kaynaklar["rehber_sayfalari"]:
        try:
            html = requests.get(sayfa, headers=TARAYICI_KIMLIGI, timeout=60).text
        except requests.RequestException as hata:
            print(f"  uyarı: {sayfa} okunamadı ({hata})")
            continue
        for bag in re.findall(r'href="([^"]*Ceza-Rehberi[^"]*\.pdf)"', html, flags=re.I):
            bulunan.append(urllib.parse.urljoin(sayfa, bag))
    yil = datetime.date.today().year
    tahmin = [k.format(yil=y) for y in (yil, yil - 1) for k in kaynaklar["rehber_kaliplari"]]

    def yil_degeri(adres):
        m = re.search(r"(20\d\d)", adres)
        return int(m.group(1)) if m else 0

    sirali = sorted(set(bulunan), key=yil_degeri, reverse=True) + tahmin
    return list(dict.fromkeys(sirali))


def kaynaklari_indir(kaynaklar, klasor):
    indirilen = {}
    hedefler = {
        "rehber.pdf": rehber_adresleri(kaynaklar),
        "2918.pdf": kaynaklar["kanun_2918"],
        "4925.pdf": kaynaklar["kanun_4925"],
        "4925_ceza.pdf": kaynaklar["ceza_4925"],
    }
    for ad, adresler in hedefler.items():
        for adres in adresler:
            try:
                indir(adres, os.path.join(klasor, ad))
                indirilen[ad] = adres
                print(f"  indirildi: {ad}  <-  {adres}")
                break
            except (requests.RequestException, ValueError) as hata:
                print(f"  denendi, olmadı: {adres} ({hata})")
        else:
            print(f"  UYARI: {ad} hiçbir adresten indirilemedi; mevcut veri korunacak")
    return indirilen


def oku(yol, varsayilan):
    if not os.path.exists(yol):
        return varsayilan
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def para(deger):
    if deger is None:
        return "-"
    return f"{deger:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".").replace(",00", "") + " TL"


def ceza_farklari(kanun, eski, yeni):
    eski_s = {k["id"]: k for k in eski}
    yeni_s = {k["id"]: k for k in yeni}
    satirlar = []
    for kimlik, k in yeni_s.items():
        e = eski_s.get(kimlik)
        if e is None:
            satirlar.append(f"Yeni: md. {k['madde']} – {k['konu'][:90]} ({para(k.get('tutar'))})")
        elif e.get("tutar") != k.get("tutar"):
            satirlar.append(f"md. {k['madde']}: {para(e.get('tutar'))} → {para(k.get('tutar'))}")
        elif any(e.get(a) != k.get(a) for a in ("puan", "belge", "men", "cezaMetin", "konu")):
            satirlar.append(f"md. {k['madde']}: açıklama/yaptırım bilgisi güncellendi")
    for kimlik, e in eski_s.items():
        if kimlik not in yeni_s:
            satirlar.append(f"Kaldırıldı: md. {e['madde']} – {e['konu'][:90]}")
    return satirlar


def madde_farklari(eski, yeni):
    eski_s = {m["id"]: m for m in eski}
    yeni_s = {m["id"]: m for m in yeni}
    satirlar = [f"Madde {m['no']} ({m['baslik'] or 'başlıksız'}) metni değişti"
                for k, m in yeni_s.items() if k in eski_s and eski_s[k]["metin"] != m["metin"]]
    satirlar += [f"Yeni madde: {m['no']} {m['baslik']}" for k, m in yeni_s.items() if k not in eski_s]
    satirlar += [f"Kaldırılan madde: {m['no']} {m['baslik']}" for k, m in eski_s.items() if k not in yeni_s]
    return satirlar


def resmi_gazete_duyurulari(kaynaklar, bilinen_adresler):
    """Günün Resmî Gazete fihristinde trafik mevzuatına değinen başlıkları toplar."""
    duyurular = []
    try:
        yanit = requests.get(kaynaklar["resmi_gazete"], headers=TARAYICI_KIMLIGI, timeout=60)
        yanit.encoding = yanit.apparent_encoding or "utf-8"
    except requests.RequestException as hata:
        print(f"  uyarı: Resmî Gazete okunamadı ({hata})")
        return duyurular
    for bag, metin in re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', yanit.text, flags=re.S | re.I):
        baslik = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", metin)).strip()
        kucuk = baslik.replace("İ", "i").replace("I", "ı").lower()
        adres = urllib.parse.urljoin(kaynaklar["resmi_gazete"], bag)
        if len(baslik) > 25 and any(a in kucuk for a in ANAHTAR_KELIMELER) and adres not in bilinen_adresler:
            duyurular.append({"tur": "resmi-gazete", "baslik": "Resmî Gazete: " + baslik[:200],
                              "ozet": "Resmî Gazete'de trafik mevzuatıyla ilgili yeni bir yayın var.",
                              "satirlar": [], "url": adres})
    return duyurular


def surum_yaz(veri_klasoru, simdi, haber_zamani=None):
    dosyalar = {}
    for ad in sorted(os.listdir(veri_klasoru)):
        if ad.endswith(".json") and ad != "surum.json":
            with open(os.path.join(veri_klasoru, ad), "rb") as f:
                icerik = f.read()
            dosyalar[ad] = {"sha256": hashlib.sha256(icerik).hexdigest(), "boyut": len(icerik)}
    eski = oku(os.path.join(veri_klasoru, "surum.json"), {})
    if eski.get("dosyalar") == dosyalar:
        eski["sonKontrol"] = simdi
        surum = eski
    else:
        surum = {"guncelleme": simdi, "sonKontrol": simdi, "dosyalar": dosyalar}
    # Haberlerin en son ne zaman toplandığı; günde bir kez (06:00) yenileme buna göre yapılır.
    haber_zamani = haber_zamani or eski.get("haberZamani")
    if haber_zamani:
        surum["haberZamani"] = haber_zamani
    veri_olustur.yaz(veri_klasoru, "surum.json", surum)
    return surum


def calistir(veri_klasoru, haberleri_zorla=False):
    kaynaklar = oku(os.path.join(BURASI, "kaynaklar.json"), None)
    simdi = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    duyurular = oku(os.path.join(veri_klasoru, "duyurular.json"), [])
    yeni_duyurular = []

    with tempfile.TemporaryDirectory() as gecici:
        kaynak_klasoru = os.path.join(gecici, "kaynak")
        cikti_klasoru = os.path.join(gecici, "cikti")
        os.makedirs(kaynak_klasoru)
        print("Kaynaklar indiriliyor…")
        indirilen = kaynaklari_indir(kaynaklar, kaynak_klasoru)
        print("Ayrıştırılıyor…")
        veri_olustur.olustur(kaynak_klasoru, cikti_klasoru)

        tanimlar = [
            ("cezalar_2918.json", "rehber.pdf", "2918 ceza rehberi güncellendi", lambda e, y: ceza_farklari("2918", e, y)),
            ("cezalar_4925.json", "4925_ceza.pdf", "4925 idari para cezaları güncellendi", lambda e, y: ceza_farklari("4925", e, y)),
            ("mevzuat_2918.json", "2918.pdf", "2918 sayılı Kanun metni değişti", madde_farklari),
            ("mevzuat_4925.json", "4925.pdf", "4925 sayılı Kanun metni değişti", madde_farklari),
        ]
        for ad, pdf, baslik, fark in tanimlar:
            yeni_yol = os.path.join(cikti_klasoru, ad)
            if not os.path.exists(yeni_yol):
                continue
            yeni = oku(yeni_yol, [])
            eski = oku(os.path.join(veri_klasoru, ad), None)
            if eski is not None and len(yeni) < 0.6 * len(eski):
                print(f"  UYARI: {ad} beklenenden çok küçük ({len(yeni)} < {len(eski)}); yayımlanmadı")
                continue
            if eski == yeni:
                continue
            veri_olustur.yaz(veri_klasoru, ad, yeni)
            if eski is not None:
                satirlar = fark(eski, yeni)
                if satirlar:
                    yeni_duyurular.append({"tur": "veri", "baslik": baslik,
                                           "ozet": f"{len(satirlar)} değişiklik saptandı.",
                                           "satirlar": satirlar[:60], "url": indirilen.get(pdf, "")})

    yeni_duyurular += resmi_gazete_duyurulari(kaynaklar, {d.get("url") for d in duyurular})
    for d in yeni_duyurular:
        d["tarih"] = simdi
        d["id"] = hashlib.sha1((d["baslik"] + d["url"] + simdi).encode("utf-8")).hexdigest()[:12]
        print(f"  DUYURU: {d['baslik']}")
    veri_olustur.yaz(veri_klasoru, "duyurular.json", (yeni_duyurular + duyurular)[:DUYURU_SINIRI])
    # Haberler her çalıştırmada değil, günde bir kez sabah 06:00'dan (Türkiye saati) sonraki ilk çalıştırmada toplanır.
    haber_zamani = None
    eski_surum = oku(os.path.join(veri_klasoru, "surum.json"), {})
    try:
        son = datetime.datetime.strptime(eski_surum["haberZamani"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    except (KeyError, ValueError):
        son = None
    if haberleri_zorla or haberler.yenileme_zamani_mi(son, datetime.datetime.now(datetime.timezone.utc)):
        print("Haberler toplanıyor…")
        guncel_haberler = haberler.topla(kaynaklar)
        if guncel_haberler:
            veri_olustur.yaz(veri_klasoru, "haberler.json", guncel_haberler)
            haber_zamani = simdi
            print(f"  {len(guncel_haberler)} haber")
        else:
            print("  UYARI: haber toplanamadı; mevcut liste korunuyor")
    else:
        print("Haberler bugün 06:00'da toplandı; atlanıyor.")
    surum = surum_yaz(veri_klasoru, simdi, haber_zamani)
    print(f"Bitti. Veri sürümü: {surum['guncelleme']}  ({len(yeni_duyurular)} yeni duyuru)")


if __name__ == "__main__":
    # --haber: 06:00 beklenmeden haberleri hemen yeniden topla.
    yollar = [a for a in sys.argv[1:] if not a.startswith("--")]
    calistir(yollar[0] if yollar else os.path.join(BURASI, "..", "assets", "veri"), haberleri_zorla="--haber" in sys.argv)
