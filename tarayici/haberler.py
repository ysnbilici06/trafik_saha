"""Türkiye'deki trafik kazaları ve trafik mevzuatı haberlerini RSS akışlarından toplar.

Yalnızca başlık, kaynak, tarih, kısa özet, görsel adresi ve haberin bağlantısı alınır;
haber metni kopyalanmaz, okuyucu yayıncının sayfasına yönlendirilir.
"""
import datetime
import email.utils
import hashlib
import html
import re

import requests

TARAYICI_KIMLIGI = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                                  "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"}
# Her başlık altında yalnızca en güncel birkaç haber tutulur.
KATEGORI_SINIRI = 5
# Kaza haberi çabuk eskir; mevzuat haberi seyrek çıkar ve daha uzun süre geçerlidir.
EN_ESKI_GUN = {"kaza": 2, "mevzuat": 14}
# Haber listesi günde bir kez, Türkiye saatiyle (UTC+3) bu saatte yenilenir.
YENILEME_SAATI = 6
TURKIYE = datetime.timezone(datetime.timedelta(hours=3))


def son_yenileme_siniri(simdi):
    """Verilen andan önceki en son 06:00'yı (Türkiye saati) UTC olarak döndürür."""
    yerel = simdi.astimezone(TURKIYE)
    sinir = yerel.replace(hour=YENILEME_SAATI, minute=0, second=0, microsecond=0)
    if yerel < sinir:
        sinir -= datetime.timedelta(days=1)
    return sinir.astimezone(datetime.timezone.utc)


def yenileme_zamani_mi(son, simdi):
    """Son toplama, en son 06:00'dan önceyse (ya da hiç yapılmadıysa) yeniden toplanmalıdır."""
    return son is None or son < son_yenileme_siniri(simdi)

ARAC = r"\b(otomobil|araç|araba|t[ıi]r|kamyon|kamyonet|otobüs|minibüs|midibüs|motosiklet|traktör)\w*"
KAZA_KESIN = re.compile(r"trafik kazas|zincirleme kaza|kafa kafaya|şarampol|takla att", re.I)
# "kazanç", "kazandı" gibi kelimeler kaza sayılmasın.
KAZA_KELIME = re.compile(r"\bkaza(?!n|k)\w*|\bçarp\w*|\bdevril\w*", re.I)
ARAC_KELIME = re.compile(ARAC, re.I)
KAZA_DEGIL = re.compile(r"uçak|helikopter|gemi|vapur|tekne|maden|iş kazası|\btren|füze|deprem|\bdizi|\bfilm|kktc|kıbrıs", re.I)
TRAFIK_KONUSU = re.compile(r"trafi[kğ]|ehliyet|sürücü belge|karayollar|plaka|hız sınır|muayene|\bradar", re.I)
MEVZUAT_KELIME = re.compile(
    r"kanun|\byasa\w*|yönetmelik|yeni düzenleme|kanun teklifi|tbmm|meclis|resm[îi] gazete|genelge|yürürlü|\bzam\b|yeniden değerleme|cezalar[ıi]", re.I)
# Yerel yol düzenlemeleri, sigorta ilanları ve yurt dışı haberleri mevzuat sayılmaz.
MEVZUAT_DEGIL = re.compile(r"trafik akış|sigorta|caddesi|bulvarı|kavşa[kğ]|vietnam|hanoi|hollanda|almanya|fransa|abd|rusya|kktc|kıbrıs", re.I)


def kaza_mi(metin):
    if KAZA_DEGIL.search(metin):
        return False
    return bool(KAZA_KESIN.search(metin) or (KAZA_KELIME.search(metin) and ARAC_KELIME.search(metin)))


def mevzuat_mi(metin):
    return bool(TRAFIK_KONUSU.search(metin) and MEVZUAT_KELIME.search(metin) and not MEVZUAT_DEGIL.search(metin))

def _temiz(metin):
    metin = re.sub(r"<!\[CDATA\[|\]\]>", "", metin or "")
    metin = html.unescape(re.sub(r"<[^>]+>", " ", html.unescape(metin)))
    return re.sub(r"\s+", " ", metin).strip()


def _alan(oge, ad):
    m = re.search(rf"<{ad}\b[^>]*>(.*?)</{ad}>", oge, flags=re.S)
    return m.group(1) if m else ""


def _gorsel(oge):
    for kalip in (r'<enclosure[^>]+url="([^"]+)"', r'<media:content[^>]+url="([^"]+)"',
                  r"<image>\s*(https?://[^<\s]+)", r'<img[^>]+src="([^"]+)"'):
        m = re.search(kalip, html.unescape(oge))
        if m and m.group(1).startswith("https://"):
            return m.group(1)
    return ""


def _tarih(oge):
    try:
        t = email.utils.parsedate_to_datetime(_temiz(_alan(oge, "pubDate")))
        return t.astimezone(datetime.timezone.utc)
    except (TypeError, ValueError):
        return None


def kategori(metin, zorunlu=None):
    """Metnin 'kaza' mı 'mevzuat' mı olduğunu, hiçbiri değilse None döndürür."""
    if zorunlu in (None, "kaza") and kaza_mi(metin):
        return "kaza"
    if zorunlu in (None, "mevzuat") and mevzuat_mi(metin) and not kaza_mi(metin):
        return "mevzuat"
    return None

def _akis_oku(url):
    yanit = requests.get(url, headers=TARAYICI_KIMLIGI, timeout=30)
    yanit.raise_for_status()
    if "charset" not in yanit.headers.get("content-type", "").lower():
        yanit.encoding = "utf-8"
    return re.findall(r"<item\b.*?</item>", yanit.text, flags=re.S)


def topla(kaynaklar, simdi=None):
    simdi = simdi or datetime.datetime.now(datetime.timezone.utc)
    haberler = {}

    def ekle(baslik, kaynak, tarih, url, ozet, gorsel, kat):
        en_eski = simdi - datetime.timedelta(days=EN_ESKI_GUN[kat])
        if not baslik or not url or tarih is None or tarih < en_eski or tarih > simdi + datetime.timedelta(hours=1):
            return
        anahtar = re.sub(r"[^a-z0-9çğıöşü]+", "", baslik.lower())[:60]
        onceki = haberler.get(anahtar)
        # Aynı haberin görselli ve özetli sürümü (yayıncının kendi akışı) tercih edilir.
        if onceki and (onceki["gorsel"] or not gorsel):
            return
        haberler[anahtar] = {
            "id": hashlib.sha1(anahtar.encode("utf-8")).hexdigest()[:12],
            "kategori": kat, "baslik": baslik, "kaynak": kaynak,
            "tarih": tarih.strftime("%Y-%m-%dT%H:%M:%SZ"), "url": url,
            "ozet": ozet[:280], "gorsel": gorsel,
        }

    for kat, url in kaynaklar.get("haber_aramalari", {}).items():
        try:
            ogeler = _akis_oku(url)
        except requests.RequestException as hata:
            print(f"  uyarı: {kat} haber araması okunamadı ({hata})")
            continue
        for oge in ogeler:
            tam = _temiz(_alan(oge, "title"))
            kaynak = _temiz(_alan(oge, "source"))
            if kaynak.startswith("http"):
                kaynak = re.sub(r"^https?://(www\.)?", "", kaynak).split("/")[0]
            baslik = tam[: -len(kaynak) - 3] if kaynak and tam.endswith(" - " + kaynak) else tam
            # Bazı siteler başlığa kendi adını veya adresini ekler.
            baslik = re.sub(r"\s+[-|]\s+(https?://\S+|[^-|]{0,60}(Haber|Dakika|Gazete)[^-|]{0,40})$", "", baslik).strip()
            if kategori(baslik, zorunlu=kat) == kat:
                ekle(baslik, kaynak, _tarih(oge), _temiz(_alan(oge, "link")), "", "", kat)

    for akis in kaynaklar.get("haber_akislari", []):
        try:
            ogeler = _akis_oku(akis["url"])
        except requests.RequestException as hata:
            print(f"  uyarı: {akis['ad']} akışı okunamadı ({hata})")
            continue
        for oge in ogeler:
            baslik = _temiz(_alan(oge, "title"))
            ozet = _temiz(_alan(oge, "description"))
            # Yayıncı akışları genel haber içerir; ilgisiz eşleşmeyi önlemek için yalnızca başlığa bakılır.
            kat = kategori(baslik) or kategori(baslik + " " + ozet[:160], zorunlu="kaza")
            if kat:
                ekle(baslik, akis["ad"], _tarih(oge), _temiz(_alan(oge, "link")), ozet, _gorsel(oge), kat)

    sirali = sorted(haberler.values(), key=lambda h: h["tarih"], reverse=True)
    kazalar = [h for h in sirali if h["kategori"] == "kaza"][:KATEGORI_SINIRI]
    mevzuat = [h for h in sirali if h["kategori"] == "mevzuat"][:KATEGORI_SINIRI]
    return sorted(kazalar + mevzuat, key=lambda h: h["tarih"], reverse=True)


if __name__ == "__main__":
    import json
    import os
    import sys

    # Süzgeçleri denerken sınır kaldırılır ki elenen/geçen haberlerin tamamı görülsün.
    KATEGORI_SINIRI = 1000
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "kaynaklar.json"), encoding="utf-8") as f:
        sonuc = topla(json.load(f))
    for h in sonuc[: int(sys.argv[1]) if len(sys.argv) > 1 else 40]:
        print(f"[{h['kategori']:7}] {h['tarih'][5:16]} {'G' if h['gorsel'] else ' '} {h['kaynak'][:14]:14} {h['baslik'][:95]}")
    print(len(sonuc), "haber;", sum(1 for h in sonuc if h["kategori"] == "mevzuat"), "mevzuat;", sum(1 for h in sonuc if h["gorsel"]), "görselli")
