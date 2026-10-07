import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trafik_saha/ekranlar/egitim.dart';
import 'package:trafik_saha/ekranlar/ek_araclar.dart';
import 'package:trafik_saha/ekranlar/islemler.dart';
import 'package:trafik_saha/ekranlar/kaza_kaydi.dart';
import 'package:trafik_saha/ekranlar/yeni_araclar.dart';
import 'package:trafik_saha/veri/haberler.dart';
import 'package:trafik_saha/veri/hava.dart';
import 'package:trafik_saha/main.dart';
import 'package:trafik_saha/veri/asistan.dart';
import 'package:trafik_saha/veri/depo.dart';
import 'package:trafik_saha/veri/hesap.dart';
import 'package:trafik_saha/veri/modeller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final depo = Depo.i;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await depo.baslat();
  });

  group('veri', () {
    test('paketlenen veri yüklenir', () {
      expect(depo.cezalar.where((c) => c.kanun == '2918').length, greaterThan(250));
      expect(depo.cezalar.where((c) => c.kanun == '4925').length, greaterThan(20));
      expect(depo.madde('2918', '84')!.metin, contains('Arkadan çarpma'));
      expect(depo.madde('4925', '26'), isNotNull);
    });

    test('içerikteki tüm ceza bağlantıları veride karşılık bulur', () {
      for (final k in depo.kazalar) {
        for (final id in k['ihlaller'] as List<dynamic>) {
          expect(depo.ceza('2918:$id'), isNotNull, reason: 'kaza ${k['id']} -> $id');
        }
      }
      for (final l in depo.listeler) {
        for (final m in (l['maddeler'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          if (m['ceza'] != null) expect(depo.ceza('2918:${m['ceza']}'), isNotNull, reason: '${m['ceza']}');
          if (m['ceza4925'] != null) {
            expect(depo.cezalar.any((c) => c.kanun == '4925' && c.madde == m['ceza4925']), isTrue, reason: '${m['ceza4925']}');
          }
        }
      }
    });

    test('para biçimi', () {
      expect(para(1246), '1.246 TL');
      expect(para(934.5), '934,50 TL');
      expect(para(140000), '140.000 TL');
    });
  });

  group('hesap', () {
    test('hız kademeleri rehberden okunur', () {
      final ici = hizHesapla(depo.cezalar, yerlesimIci: true, sinir: 50, olculen: 82);
      expect(ici.asim, 32);
      expect(ici.kalem!.id, '51-2-a-5');
      expect(hizHesapla(depo.cezalar, yerlesimIci: true, sinir: 50, olculen: 54).kalem, isNull);
      expect(hizHesapla(depo.cezalar, yerlesimIci: false, sinir: 110, olculen: 190).kalem!.id, '51-2-b-9');
      expect(hizHesapla(depo.cezalar, yerlesimIci: false, sinir: 90, olculen: 100).kalem, isNull);
    });

    test('yasal hız sınırları tablosu', () {
      Map<String, dynamic> arac(String ad) => depo.hizAraclari.firstWhere((a) => (a['ad'] as String).startsWith(ad));
      expect(depo.hizAraclari.length, 16);
      expect(depo.hizYollari.length, 4);
      expect(depo.yasalHizSiniri(arac('Otomobil'), 3), 130);
      expect(depo.yasalHizSiniri(arac('Otomobil'), 3, otoyolUstSinir: true), 140);
      expect(depo.yasalHizSiniri(arac('Otomobil'), 2, otoyolUstSinir: true), 110);
      expect(depo.yasalHizSiniri(arac('Kamyon (N2'), 1), 80);
      expect(depo.yasalHizSiniri(arac('Lastik'), 3), isNull);
      for (final a in depo.hizAraclari) {
        expect((a['sinirlar'] as List<dynamic>).length, 4, reason: a['ad'] as String);
      }
    });

    test('alkol kademeleri', () {
      final kalem = depo.ceza('2918:48-5');
      expect(alkolHesapla(kalem, hususiOtomobil: true, promil: 0.45, kacinci: 1).ihlal, isFalse);
      expect(alkolHesapla(kalem, hususiOtomobil: false, promil: 0.45, kacinci: 1).ihlal, isTrue);
      expect(alkolHesapla(kalem, hususiOtomobil: true, promil: 0.8, kacinci: 1).tutar, 25000);
      expect(alkolHesapla(kalem, hususiOtomobil: true, promil: 0.8, kacinci: 2).tutar, 50000);
      final ucuncu = alkolHesapla(kalem, hususiOtomobil: true, promil: 1.2, kacinci: 3);
      expect(ucuncu.tutar, 150000);
      expect(ucuncu.tckUygulanir, isTrue);
    });

    test('gecikme faizi cezanın iki katını geçmez', () {
      expect(gecikmeFaizi(1000, 2), 100);
      expect(gecikmeFaizi(1000, 100), 2000);
    });

    test('takograf kademeleri', () {
      TakografSonucu h(TakografTuru t, int dk) => takografHesapla(depo.cezalar, t, dk);
      expect(h(TakografTuru.surekli, 270).kalem, isNull);
      expect(h(TakografTuru.surekli, 300).kalem!.id, '49-3-a-1');
      expect(h(TakografTuru.surekli, 331).kalem!.id, '49-3-a-2');
      expect(h(TakografTuru.gunluk, 600).kalem!.id, '49-3-b-1');
      expect(h(TakografTuru.gunluk, 660).kalem!.id, '49-3-b-2');
      expect(h(TakografTuru.gunluk, 720).kalem!.id, '49-3-b-3');
      expect(h(TakografTuru.ikiHaftalik, 5400 + 240).kalem!.id, '49-3-c-1');
      expect(h(TakografTuru.ikiHaftalik, 5400 + 900).kalem!.id, '49-3-c-3');
    });

    test('fren izi ve alkol birimleri', () {
      expect(frenIzindenHiz(izMetre: 20, surtunme: 0.7), closeTo(59.7, 0.1));
      expect(alkolDonustur(0.5, 0, 1), 50);
      expect(alkolDonustur(100, 1, 0), 1);
      expect(alkolDonustur(1, 0, 3), closeTo(0.476, 0.001));
    });

    test('fazla yük toleransı', () {
      expect(yukHesapla(depo.cezalar, azami: 26000, tartilan: 27000).kalem, isNull);
      expect(yukHesapla(depo.cezalar, azami: 26000, tartilan: 28000).kalem!.id, '65-1-b-a');
      expect(yukHesapla(depo.cezalar, azami: 26000, tartilan: 34000).kalem!.id, '65-1-b-e');
    });
  });

  group('asistan', () {
    final asistan = Asistan(depo);

    test('hız sorusu', () {
      final c = asistan.cevapla('50 sınırında 82 ile gidersem cezası ne?');
      expect(c.cezalar.single.id, '51-2-a-5');
      expect(c.metin, contains('32 km/s'));
      expect(asistan.cevapla('otoyolda 120 hız sınırında 175').cezalar.single.id, '51-2-b-7');
    });

    test('araç sınıfına göre hız sorusu', () {
      final c = asistan.cevapla('otoyolda kamyon 110 ile giderse cezası');
      expect(c.metin, contains('yasal sınır 90 km/s'));
      expect(c.cezalar.single.id, '51-2-b-2');
      expect(asistan.cevapla('kamyonet hız sınırı').metin, contains('Otoyol: 95 km/s'));
      expect(asistan.cevapla('traktör otoyolda hız sınırı').metin, contains('giremez'));
      expect(asistan.cevapla('bölünmüş yolda otobüs 97 hız').metin, contains('alt eşiğinin altında'));
    });

    test('alkol sorusu', () {
      final c = asistan.cevapla('0,80 promil alkol cezası');
      expect(c.metin, contains('25.000 TL'));
      expect(asistan.cevapla('alkol ölçümünü reddetme').cezalar.first.id, '48-9');
    });

    test('madde sorusu', () {
      expect(asistan.cevapla('madde 84').maddeler.single.no, '84');
      expect(asistan.cevapla('47/1-b').cezalar.first.id, '47-1-b');
    });

    test('günlük dille ihlal sorusu', () {
      expect(asistan.cevapla('ehliyetsiz araç kullanma').cezalar.first.id, '36-3-a');
      expect(asistan.cevapla('kırmızı ışık cezası').cezalar.first.id, '47-1-b');
      expect(asistan.cevapla('emniyet kemeri kaç puan').cezalar.first.id, '78-1-a');
      expect(asistan.cevapla('muayenesiz araç').cezalar.first.anaMadde, '34');
      expect(asistan.cevapla('seyir halinde telefon kullanmak').cezalar.first.id, '73-c');
    });

    test('kusur sorusu kaza örneğine bağlanır', () {
      final c = asistan.cevapla('arkadan çarpan kusurlu mu');
      expect(c.kazalar.first['id'], 'k2');
      expect(c.metin, contains('84/d'));
    });

    test('100 puan sorusu', () {
      expect(asistan.cevapla('100 puan dolarsa ne olur').cezalar.single.id, '118');
    });

    test('çalışma olan yollar bağlantısı ile göre bölge sayfasına gider', () {
      // Her il tam bir Karayolları bölgesine bağlıdır.
      for (final il in PlakaKodlari.iller) {
        expect(kgmBolgesi(katla(il)), isNotNull, reason: il);
      }
      expect(calismaYollariAdresi(katla('Ankara')), endsWith('?Bolge=4'));
      expect(calismaYollariAdresi(katla('Iğdır')), endsWith('?Bolge=18'));
      expect(calismaYollariAdresi(katla('Konumum')), endsWith('CalismaYapilanYollar.aspx'));
    });

    test('sohbet ve yorum', () {
      expect(asistan.cevapla('merhaba').cezalar, isEmpty);
      expect(asistan.cevapla('teşekkürler').cezalar, isEmpty);
      expect(asistan.cevapla('sen kimsin').metin, contains('insan yok'));
      // Yorumdaki rakamlar veriden türetilir: 20 puan -> 5 ihlalde 100 puan.
      final isik = asistan.cevapla('kırmızı ışık cezası');
      expect(isik.yorum, contains('5 tane'));
      final hiz = asistan.cevapla('50 sınırında 82 ile gidersem cezası ne?');
      expect(hiz.yorum, contains('durur'));
      expect(asistan.cevapla('bugün hava nasıl olacak').yorum, isEmpty);
      for (final s in ['muayenesiz araç', '0,80 promil alkol', '100 puan dolarsa ne olur', 'arkadan çarpan kusurlu mu', 'madde 84', 'SRC belgesi olmadan taşıma']) {
        final c = asistan.cevapla(s);
        expect(c.yorum, isNotEmpty, reason: s);
      }
    });

    test('neden sorusunda yorum soruya cevap verir, kitaplıktaki metni bulur', () async {
      final kitapli = Asistan(depo)..kitaplik = await depo.kitaplikYukle();
      final c = kitapli.cevapla('kışlık lastiği neden otomobile değil de büyük araçlara zorunlu');
      expect(c.cezalar.first.id, '65-a');
      expect(c.maddeler.map((m) => m.kanun), contains('kis-lastigi'));
      expect(c.metin, contains('Kış Lastiği Kullanma Zorunluluğu'));
      expect(c.yorum, startsWith('Neden böyle diye sormuşsunuz'));
      expect(c.yorum, contains('kaygan zeminde'));
      // Ceza kalemi olan soruda da "neden" görüşü öne geçer; rakamlar yine veriden gelir.
      final kemer = kitapli.cevapla('emniyet kemeri neden zorunlu');
      expect(kemer.cezalar.first.id, '78-1-a');
      expect(kemer.yorum, contains('kemer o hareketi'));
      // Kitaplık yüklüyken de ceza soruları aynı kalemi bulur, konu dışı soru cevapsız kalır.
      expect(kitapli.cevapla('kırmızı ışık cezası').cezalar.first.id, '47-1-b');
      expect(kitapli.cevapla('muayenesiz araç').cezalar.first.anaMadde, '34');
      expect(kitapli.cevapla('bugün hava nasıl olacak').maddeler, isEmpty);
      expect(Asistan.nedenYorumu('bilinmeyen konu'), contains('uydurmak istemem'));
    });

    test('ilgisiz soruda veri uydurmaz', () {
      final c = asistan.cevapla('bugün hava nasıl olacak');
      expect(c.cezalar, isEmpty);
      expect(c.metin, contains('bulamadım'));
    });
  });

  test('işlem kaydı, dönem süzgeci ve rapor', () async {
    final simdi = DateTime(2026, 10, 7, 14);
    await depo.islemEkle(depo.ceza('2918:47-1-b')!, plaka: '06 abc 123', zaman: simdi);
    await depo.islemEkle(depo.ceza('2918:78-1-a')!, zaman: simdi.subtract(const Duration(days: 3)));
    await depo.islemEkle(depo.ceza('2918:47-1-b')!, zaman: simdi.subtract(const Duration(days: 20)));
    expect(donemKayitlari(depo.islemler, 1, simdi: simdi).length, 1);
    expect(donemKayitlari(depo.islemler, 7, simdi: simdi).length, 2);
    final ozet = IslemOzeti(donemKayitlari(depo.islemler, null));
    expect(ozet.adet, 3);
    expect(ozet.toplam, 12500);
    expect(ozet.enCok.first.key, '2918 md. 47/1-b');
    expect(raporMetni(depo.islemler, 'Tümü', {}), contains('06 ABC 123'));
    await depo.islemSil(depo.islemler.first['id'] as String);
    expect(depo.islemler.length, 2);
  });

  group('hava ve kaza kaydı', () {
    Map<String, dynamic> ornek({double sicaklik = 18.9, int kod = 1, double yagis = 0, double gorus = 41540, double hamle = 11}) => {
          'current': {
            'time': '2026-10-07T13:00',
            'temperature_2m': sicaklik,
            'apparent_temperature': sicaklik - 1,
            'precipitation': yagis,
            'weather_code': kod,
            'wind_speed_10m': 3.8,
            'wind_gusts_10m': hamle,
            'visibility': gorus,
            'relative_humidity_2m': 46,
            'is_day': 1,
          },
          'hourly': {
            'time': ['2026-10-07T13:00', '2026-10-07T14:00', '2026-10-07T15:00'],
            'temperature_2m': [18.9, 19.9, 20.3],
            'weather_code': [1, 1, 61],
            'precipitation_probability': [0, 0, 60],
          },
        };

    test('servis yanıtı okunur', () {
      final h = Hava.fromJson(ornek());
      expect(h.durum, 'Az bulutlu');
      expect(h.sicaklik, 18.9);
      expect(h.saatlik.length, 2);
      expect(h.saatlik.last, ('15:00', 20.3, 61, 60));
      expect(yolUyarilari(h), isEmpty);
      expect(havaOzeti(h), 'Az bulutlu, 19°C, rüzgâr 4 km/s, görüş 10 km+');
    });

    test('olumsuz koşullar yol uyarısı üretir', () {
      expect(yolUyarilari(Hava.fromJson(ornek(kod: 63, yagis: 1.2))).single, contains('Yağış'));
      expect(yolUyarilari(Hava.fromJson(ornek(sicaklik: -2, kod: 73))).length, 2);
      expect(yolUyarilari(Hava.fromJson(ornek(kod: 45, gorus: 300))).single, contains('300 m'));
      expect(yolUyarilari(Hava.fromJson(ornek(hamle: 70))).single, contains('rüzgâr'));
    });

    test('kaza kaydı saklanır ve metne dönüşür', () async {
      await depo.kazaKaydet({
        'zaman': '2026-10-07T14:30:00',
        'tur': 'Yaralanmalı',
        'enlem': 39.925533,
        'boylam': 32.866287,
        'dogruluk': 6.4,
        'yer': 'D-750 Ankara yönü km 12',
        'araclar': '06 ABC 123, 34 XYZ 45',
        'yarali': 2,
        'olu': 0,
        'zemin': 'Islak',
      });
      final k = depo.kazaKayitlari.single;
      final metin = kazaMetni(k);
      expect(metin, contains('Koordinat: 39.925533, 32.866287 (± 6 m)'));
      expect(metin, contains('Yaralı: 2 · Ölü: 0'));
      // Taraf alanı olmayan eski kayıtta plaka sayısından çıkarılır.
      expect(kazaPlakalari(k), ['06 ABC 123', '34 XYZ 45']);
      expect(metin, contains('Kaza şekli: Çift taraflı'));
      expect(metin, contains('Araçlar: 06 ABC 123, 34 XYZ 45'));
      final tek = kazaMetni({'zaman': '2026-10-07T14:30:00', 'tur': 'Maddi hasarlı', 'taraf': 'Tek taraflı', 'araclar': '06 ABC 123', 'olus': 'Devrilme'});
      expect(tek, contains('Kaza şekli: Tek taraflı'));
      expect(tek, contains('Araç: 06 ABC 123'));
      expect(tek, contains('Oluş: Devrilme'));
      expect(metin, contains('07.10.2026 14:30'));
      await depo.kazaKaydet({...k, 'olu': 1});
      expect(depo.kazaKayitlari.single['olu'], 1);
      await depo.kazaKaydiSil(k['id'] as String);
      expect(depo.kazaKayitlari, isEmpty);
    });
  });

  group('haberler', () {
    const rss = '''
<rss><channel>
<item><title>Çorum'da trafik kazası: 4 ölü - Örnek Ajans</title><link>https://ornek.test/a</link>
<pubDate>Wed, 07 Oct 2026 10:14:46 GMT</pubDate><source url="https://ornek.test">Örnek Ajans</source></item>
<item><title>KKTC'de trafik kazası: 2 yaralı - Örnek Ajans</title><link>https://ornek.test/b</link>
<pubDate>Wed, 07 Oct 2026 09:00:00 GMT</pubDate><source url="https://ornek.test">Örnek Ajans</source></item>
<item><title>Uçak kazası sonrası inceleme - Örnek Ajans</title><link>https://ornek.test/c</link>
<pubDate>Wed, 07 Oct 2026 08:00:00 GMT</pubDate><source url="https://ornek.test">Örnek Ajans</source></item>
<item><title><![CDATA[Trafik cezaları Meclis gündeminde &amp; yeni teklif]]></title><link>https://ornek.test/d</link>
<pubDate>Tue, 06 Oct 2026 12:30:00 +0300</pubDate><source url="https://ornek.test">Haber</source></item>
</channel></rss>''';

    test('RSS çözülür; yurt dışı ve ilgisiz haberler elenir', () {
      final kazalar = rssCoz(rss, 'kaza');
      expect(kazalar.single['baslik'], "Çorum'da trafik kazası: 4 ölü");
      expect(kazalar.single['kaynak'], 'Örnek Ajans');
      expect(kazalar.single['tarih'], '2026-10-07T10:14:46.000Z');
      final mevzuat = rssCoz(rss, 'mevzuat');
      expect(mevzuat.single['baslik'], 'Trafik cezaları Meclis gündeminde & yeni teklif');
      expect(mevzuat.single['tarih'], '2026-10-06T09:30:00.000Z');
    });

    test('birleştirme tekilleştirir, görselliyi korur, yeniyi başa alır', () {
      final a = [
        {'baslik': 'Aynı haber', 'tarih': '2026-10-06T10:00:00Z', 'gorsel': '', 'kategori': 'kaza'},
        {'baslik': 'Eski haber', 'tarih': '2026-10-01T10:00:00Z', 'gorsel': '', 'kategori': 'kaza'},
      ];
      final b = [
        {'baslik': 'Aynı Haber!', 'tarih': '2026-10-06T11:00:00Z', 'gorsel': 'https://x/y.jpg', 'kategori': 'kaza'},
        {'baslik': 'Yeni haber', 'tarih': '2026-10-07T10:00:00Z', 'gorsel': '', 'kategori': 'mevzuat'},
      ];
      final s = haberleriBirlestir(a, b);
      expect(s.map((h) => h['baslik']), ['Yeni haber', 'Aynı Haber!', 'Eski haber']);
    });

    test('göreli zaman', () {
      final simdi = DateTime(2026, 10, 7, 12);
      expect(neZaman(DateTime(2026, 10, 7, 11, 40), simdi: simdi), '20 dk önce');
      expect(neZaman(DateTime(2026, 10, 7, 7), simdi: simdi), '5 sa önce');
      expect(neZaman(DateTime(2026, 10, 4, 12), simdi: simdi), '3 gün önce');
    });

    test('her başlıkta en çok 5 haber kalır ve yenileme sınırı sabah 06:00 olur', () {
      final liste = [
        for (var i = 0; i < 8; i++) {'baslik': 'Kaza $i', 'kategori': 'kaza'},
        for (var i = 0; i < 3; i++) {'baslik': 'Yasa $i', 'kategori': 'mevzuat'},
      ];
      final s = haberleriSinirla(liste);
      expect(s.where((h) => h['kategori'] == 'kaza').map((h) => h['baslik']), ['Kaza 0', 'Kaza 1', 'Kaza 2', 'Kaza 3', 'Kaza 4']);
      expect(s.where((h) => h['kategori'] == 'mevzuat').length, 3);
      expect(sonSabahAlti(DateTime(2026, 10, 7, 14, 30)), DateTime(2026, 10, 7, 6));
      expect(sonSabahAlti(DateTime(2026, 10, 7, 5, 59)), DateTime(2026, 10, 6, 6));
      expect(sonSabahAlti(DateTime(2026, 10, 7, 6)), DateTime(2026, 10, 7, 6));
      for (final k in ['kaza', 'mevzuat']) {
        expect(depo.haberler.where((h) => h['kategori'] == k).length, lessThanOrEqualTo(haberSiniri));
      }
    });

    test('paketlenen haberler yüklenir ve iki kategoriyi içerir', () {
      expect(depo.haberler, isNotEmpty);
      expect(depo.haberler.map((h) => h['kategori']).toSet(), {'kaza', 'mevzuat'});
      for (final h in depo.haberler) {
        expect((h['url'] as String).startsWith('https://'), isTrue, reason: h['baslik'] as String);
      }
    });
  });

  group('mevzuat kitaplığı', () {
    test('dizindeki her metin yüklenir ve madde sayısı tutar', () async {
      expect(depo.kitaplik.length, greaterThan(20));
      expect(depo.kitaplik.first['kod'], '2918');
      final tumu = await depo.kitaplikYukle();
      for (final k in depo.kitaplik) {
        final maddeler = tumu[k['kod']]!;
        expect(maddeler.length, k['madde'], reason: k['ad'] as String);
        expect(maddeler.map((m) => m.id).toSet().length, maddeler.length, reason: '${k['ad']} madde kimlikleri tekil olmalı');
      }
      expect(depo.mevzuatAdi('kty'), 'Karayolları Trafik Yönetmeliği');
    });

    test('arama bütün metinlerde geçen yerleri bulur', () async {
      final tumu = await depo.kitaplikYukle();
      List<String> gecenler(String q) => [
            for (final e in tumu.entries)
              if (e.value.any((m) => m.arama.contains(katla(q)))) e.key,
          ];
      expect(gecenler('kış lastiği'), containsAll(['2918', 'kis-lastigi']));
      expect(gecenler('plaka').length, greaterThan(8));
      expect(gecenler('takograf'), containsAll(['2918', 'kty', 'takograf']));
      final zorunluluk = tumu['kis-lastigi']!.firstWhere((m) => m.no == '5');
      expect(zorunluluk.baslik, 'Kış lastiği zorunluluğu');
      expect(zorunluluk.metin, contains('şehirlerarası karayollarında yolcu ve eşya taşımalarında'));
    });
  });

  group('ceza araması', () {
    List<String> ara(String q, {bool asil = false}) => [
          for (final c in depo.cezalar.where((c) => c.kanun == '2918'))
            if (c.eslesenler(aramaKelimeleri(q), asil: asil) != null) c.madde,
        ];

    test('yazılan kelimeyi içeren kalemler bulunur', () {
      expect(ara('plaka', asil: true), containsAll(['21/1', '23/4', '25', '28']));
      // Yalnızca diğer hususlarda geçenler de gelir, ama ihlal tanımında geçenlerden ayrı tutulur.
      expect(ara('plaka'), contains('31/5'));
      expect(ara('plaka', asil: true), isNot(contains('31/5')));
      expect(ara('34/a'), contains('34/a'));
      expect(ara('zzzyok'), isEmpty);
    });

    test('gündelik söyleyiş rehberdeki karşılığıyla aranır', () {
      expect(ara('kask', asil: true), contains('78/1-b'));
      expect(ara('ehliyetsiz', asil: true), contains('36/3-a'));
    });

    test('men gerektiren kalemler işaretlenir', () {
      expect(depo.ceza('2918:34-a')!.menGerektirir, isTrue);
      expect(depo.ceza('2918:48-5')!.menGerektirir, isTrue);
      expect(depo.ceza('2918:32-1')!.menGerektirir, isTrue);
      expect(depo.ceza('2918:13')!.menGerektirir, isFalse);
    });

    test('diğer hususlar madde madde ayrılır', () {
      final m = maddelereAyir(depo.ceza('2918:32-1')!.diger);
      expect(m.length, 2);
      expect(m.first, contains('ek-33 düzenlenmek'));
      expect(m.every((p) => !p.contains('\n')), isTrue);
      expect(maddelereAyir(depo.ceza('2918:47-1-b')!.diger).length, 3);
      expect(maddelereAyir('*Bir not.\n*İkinci\nnot.'), ['Bir not.', 'İkinci not.']);
    });

    test('eşleşen yer Türkçe harflere rağmen doğru işaretlenir', () {
      const metin = 'İşaretsiz ÇEKİCİ plakası';
      final a = eslesenAraliklar(metin, ['cekici', 'plaka']);
      expect([for (final (b, s) in a) metin.substring(b, s)], ['ÇEKİCİ', 'plaka']);
    });
  });

  test('yaş hesabı', () {
    expect(yasHesapla(DateTime(2008, 10, 8), DateTime(2026, 10, 7)), (17, 11, 29));
    expect(yasHesapla(DateTime(2008, 10, 7), DateTime(2026, 10, 7)), (18, 0, 0));
    expect(yasHesapla(DateTime(2000, 1, 31), DateTime(2026, 3, 1)), (26, 1, 1));
    expect(yasDoldurma(DateTime(2008, 10, 7), 18), DateTime(2026, 10, 7));
  });

  test('kroki ve türlü not saklanır', () async {
    await depo.krokiKaydet({'baslik': 'Deneme', 'tarih': '2026-10-07T10:00:00', 'sahne': {'yol': 'kavsak', 'araclar': [{'ad': 'A', 'x': 0.5, 'y': 0.5, 'yon': 0}]}});
    final k = depo.krokiler.single;
    await depo.krokiKaydet({...k, 'baslik': 'Yeni ad'});
    expect(depo.krokiler.single['baslik'], 'Yeni ad');
    await depo.krokiSil(k['id'] as String);
    expect(depo.krokiler, isEmpty);
    await depo.notKaydet(null, 'Radar noktası', 'km 12', tur: 'Radar');
    final n = depo.notlar.first;
    expect(n['tur'], 'Radar');
    await depo.notKaydet(n['id'] as String, 'Radar noktası', 'km 14');
    expect(depo.notlar.first['tur'], 'Radar');
    await depo.notSil(n['id'] as String);
  });

  testWidgets('kroki çizim ekranı açılır, araç eklenir ve çizilir', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: KrokiDuzenle(null)));
    await tester.tap(find.text('Araç ekle'));
    await tester.pumpAndSettle();
    expect(find.text('C aracı'), findsOneWidget);
    await tester.tap(find.text('Hareket oku'));
    await tester.tap(find.text('Kamyon / otobüs'));
    await tester.tap(find.text('Çarpışma noktası'));
    await tester.tap(find.text('Fren izi çiz'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomPaint).first, const Offset(60, 80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('bilgi bankası', () {
    test('konulardaki her gönderme bir maddeye çıkar', () async {
      expect(depo.bilgi.length, greaterThan(15));
      for (final k in depo.bilgi) {
        for (final g in k['maddeler'] as List<dynamic>) {
          expect(await depo.maddeBul(g as String), isNotNull, reason: '${k['id']} -> $g');
        }
      }
      final ehliyet = await depo.bilgiMaddeleri(depo.bilgi.firstWhere((k) => k['id'] == 'ehliyet'));
      expect(ehliyet.any((m) => m.baslik == 'Sürücü Belgelerinin Sınıfları'), isTrue);
    });

    test('UN numaraları ve sürücü belgesi kodları resmî tablodan gelir', () async {
      final un = ((await depo.basvuruDosyasi('un_kodlari.json'))['maddeler'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(un.length, greaterThan(2500));
      final benzin = un.firstWhere((m) => m['un'] == '1203');
      expect(benzin['ad'], contains('BENZİN'));
      expect(benzin['sinif'], '3');
      expect(benzin['tehlikeNo'], '33');
      final kodlar = await depo.basvuruDosyasi('surucu_kodlari.json');
      final hepsi = [for (final b in kodlar['bolumler'] as List<dynamic>) ...(b as Map<String, dynamic>)['kodlar'] as List<dynamic>];
      expect(hepsi.length, greaterThan(150));
      expect(hepsi.firstWhere((k) => (k as Map<String, dynamic>)['kod'] == '78')['aciklama'], contains('otomatik vitesli'));
    });
  });

  test('plaka kodları 81 ildir', () {
    expect(PlakaKodlari.iller.length, 81);
    expect(PlakaKodlari.iller[5], 'Ankara');
    expect(PlakaKodlari.iller[33], 'İstanbul');
    expect(PlakaKodlari.iller[80], 'Düzce');
  });

  test('quiz turu geçerli sorular üretir', () {
    for (final kategori in [null, 'İhlal Puanları', 'Ceza Tutarları', 'Alkol']) {
      final tur = turHazirla(depo, kategori, rastgele: Random(7));
      expect(tur, isNotEmpty, reason: '$kategori');
      for (final s in tur) {
        final secenekler = s['secenekler'] as List<dynamic>;
        expect(secenekler.toSet().length, secenekler.length, reason: 'yinelenen seçenek: ${s['id']}');
        expect(s['dogru'] as int, inInclusiveRange(0, secenekler.length - 1));
      }
    }
  });

  testWidgets('kaza kaydında plaka alanları tek ya da çift tarafa göre açılır', (tester) async {
    // Sayfanın tamamı kaydırmadan görünsün diye uzun bir ekran kullanılır.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: KazaKaydiDuzenle(null)));
    expect(find.text('Araç plakası'), findsNothing);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Galeriden ekle'), findsOneWidget);
    await tester.tap(find.text('Çift taraflı'));
    await tester.pumpAndSettle();
    expect(find.text('1. araç plakası'), findsOneWidget);
    expect(find.text('2. araç plakası'), findsOneWidget);
    await tester.tap(find.text('Tek taraflı'));
    await tester.pumpAndSettle();
    expect(find.text('Araç plakası'), findsOneWidget);
    expect(find.text('2. araç plakası'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uygulama açılır ve sekmeler gezilir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await depo.karsilamayiGec();
    await tester.pumpWidget(const TrafikSahaUygulamasi());
    await tester.pumpAndSettle();
    expect(find.text('Trafik Asistanı'), findsOneWidget);
    // Ayarlarda seçilen birim ve kısayollar ana sayfaya yansır.
    expect(find.text('Kaza kaydı'), findsOneWidget);
    await depo.birimSec('otoyol-jandarmasi');
    await depo.kisayollariKaydet(['Alkol', 'Mevzuat', 'İl plaka kodları']);
    await tester.pumpAndSettle();
    expect(find.text('Otoyol Jandarması'), findsOneWidget);
    expect(find.text('Plaka kodları'), findsOneWidget);
    expect(find.text('Kaza kaydı'), findsNothing);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Birim logosu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await depo.kisayollariKaydet(null);
    await depo.birimSec('genel');
    await tester.pumpAndSettle();
    for (final sekme in ['Cezalar', 'Mevzuat', 'Araçlar', 'Eğitim']) {
      await tester.tap(find.text(sekme));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: sekme);
    }
  });
}
