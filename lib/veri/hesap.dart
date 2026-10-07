import 'dart:math' as math;

import 'modeller.dart';

/// Hız ihlali hesabının sonucu. [kalem] boşsa aşım ceza kademelerinin altındadır.
class HizSonucu {
  HizSonucu(this.asim, this.kalem);
  final int asim;
  final Ceza? kalem;
}

/// Hız kademelerini ceza rehberindeki madde 51/2 kalemlerinin metninden okur; böylece
/// kademeler veya tutarlar değiştiğinde hesap da kendiliğinden güncellenir.
HizSonucu hizHesapla(List<Ceza> cezalar, {required bool yerlesimIci, required int sinir, required int olculen}) {
  final asim = olculen - sinir;
  final onEk = yerlesimIci ? '51-2-a-' : '51-2-b-';
  final aralik = RegExp(r"(\d+)\s*-\s*(\d+)\s*km/s");
  final ustu = RegExp(r"(\d+)\s*km/s\s*ve daha fazla");
  for (final c in cezalar) {
    if (c.kanun != '2918' || !c.id.startsWith(onEk)) continue;
    final a = aralik.firstMatch(c.konu);
    if (a != null) {
      if (asim >= int.parse(a.group(1)!) && asim <= int.parse(a.group(2)!)) return HizSonucu(asim, c);
      continue;
    }
    final u = ustu.firstMatch(c.konu);
    if (u != null && asim >= int.parse(u.group(1)!)) return HizSonucu(asim, c);
  }
  return HizSonucu(asim, null);
}

/// "1. defada 25.000 TL … 2. defada 50.000 TL …" biçimindeki kademeli ceza metninden
/// indirimli olmayan tutarları sırasıyla çıkarır.
List<double> kademeTutarlari(String cezaMetin) {
  final tutar = RegExp(r'(\d{1,3}(?:\.\d{3})*(?:,\d+)?)\s*TL');
  final sonuc = <double>[];
  for (final satir in cezaMetin.split('\n')) {
    if (satir.toLowerCase().contains('ndirimli')) continue;
    final m = tutar.firstMatch(satir);
    if (m != null) sonuc.add(double.parse(m.group(1)!.replaceAll('.', '').replaceAll(',', '.')));
  }
  return sonuc;
}

class AlkolSonucu {
  AlkolSonucu(this.sinir, this.ihlal, this.tutar, this.tckUygulanir);
  final double sinir;
  final bool ihlal;
  final double? tutar;

  /// 1,00 promilin üzerinde ayrıca TCK md. 179 uygulanır.
  final bool tckUygulanir;
}

AlkolSonucu alkolHesapla(Ceza? kalem, {required bool hususiOtomobil, required double promil, required int kacinci}) {
  final sinir = hususiOtomobil ? 0.50 : 0.20;
  final ihlal = promil > sinir;
  double? tutar;
  if (ihlal && kalem != null) {
    final kademeler = kademeTutarlari(kalem.cezaMetin);
    if (kademeler.isEmpty) {
      tutar = kalem.tutar;
    } else {
      tutar = kademeler[(kacinci - 1).clamp(0, kademeler.length - 1)];
    }
  }
  return AlkolSonucu(sinir, ihlal, tutar, promil > 1.0);
}

class YukSonucu {
  YukSonucu(this.fazlaKg, this.yuzde, this.toleransSiniri, this.kalem);
  final double fazlaKg;
  final double yuzde;
  final double toleransSiniri;
  final Ceza? kalem;
}

/// Azami yüklü ağırlık aşımı. Tolerans (%3,75 + 500 kg) aşılmadıkça kalem dönmez.
YukSonucu yukHesapla(List<Ceza> cezalar, {required double azami, required double tartilan}) {
  final fazla = tartilan - azami;
  final yuzde = azami <= 0 ? 0.0 : fazla / azami * 100;
  final tolerans = azami * 1.0375 + 500;
  Ceza? kalem;
  if (tartilan > tolerans) {
    final kadar = RegExp(r"%\s*(\d+)\s*fazlasına kadar");
    final kalemler = cezalar.where((c) => c.kanun == '2918' && c.id.startsWith('65-1-b-')).toList();
    for (final c in kalemler) {
      final m = kadar.firstMatch(c.konu);
      if (m == null || yuzde <= int.parse(m.group(1)!)) {
        kalem = c;
        break;
      }
    }
  }
  return YukSonucu(fazla, yuzde, tolerans, kalem);
}

class DurmaSonucu {
  DurmaSonucu(this.reaksiyon, this.fren);
  final double reaksiyon;
  final double fren;
  double get toplam => reaksiyon + fren;
}

/// Fiziksel durma mesafesi: reaksiyon süresinde alınan yol + sürtünmeyle fren mesafesi.
DurmaSonucu durmaMesafesi({required double hizKmS, required double reaksiyonSn, required double surtunme}) {
  final v = hizKmS / 3.6;
  return DurmaSonucu(v * reaksiyonSn, v * v / (2 * surtunme * 9.81));
}

/// Fren izi uzunluğundan, frenleme başındaki en düşük hızı (km/s) verir: v = √(2·μ·g·d).
double frenIzindenHiz({required double izMetre, required double surtunme}) =>
    math.sqrt(2 * surtunme * 9.81 * izMetre) * 3.6;

enum TakografTuru {
  surekli('Sürekli sürüş', 270, ['49-3-a-1', '49-3-a-2'], [60]),
  gunluk('Günlük toplam sürüş', 540, ['49-3-b-1', '49-3-b-2', '49-3-b-3'], [60, 179]),
  ikiHaftalik('İki haftalık toplam sürüş', 5400, ['49-3-c-1', '49-3-c-2', '49-3-c-3'], [240, 899]);

  const TakografTuru(this.ad, this.sinirDakika, this.kalemler, this.esikler);
  final String ad;

  /// Yönetmelikteki azami süre (dakika): 4,5 saat, 9 saat, 90 saat.
  final int sinirDakika;

  /// Aşım kademelerine karşılık gelen ceza kalemi kimlikleri.
  final List<String> kalemler;

  /// Her kademenin dâhil olduğu en yüksek aşım (dakika); son kademe üst sınırsızdır.
  final List<int> esikler;
}

class TakografSonucu {
  TakografSonucu(this.asimDakika, this.kalem);
  final int asimDakika;
  final Ceza? kalem;
}

TakografSonucu takografHesapla(List<Ceza> cezalar, TakografTuru tur, int surulenDakika) {
  final asim = surulenDakika - tur.sinirDakika;
  if (asim <= 0) return TakografSonucu(asim, null);
  var sira = tur.esikler.indexWhere((e) => asim <= e);
  if (sira < 0) sira = tur.kalemler.length - 1;
  final kimlik = tur.kalemler[sira];
  Ceza? kalem;
  for (final c in cezalar) {
    if (c.kanun == '2918' && c.id == kimlik) kalem = c;
  }
  return TakografSonucu(asim, kalem);
}

/// Alkol ölçü birimleri; katsayı, 1 promilin o birimdeki karşılığıdır.
/// Nefes dönüşümünde kan/nefes oranı 2100:1 kabul edilir.
const alkolBirimleri = [
  ('Promil (g/L kan)', 1.0),
  ('mg/100 mL kan', 100.0),
  ('% BAC', 0.1),
  ('mg/L nefes', 1 / 2.1),
];

double alkolDonustur(double deger, int kaynakBirim, int hedefBirim) =>
    deger / alkolBirimleri[kaynakBirim].$2 * alkolBirimleri[hedefBirim].$2;

/// Gecikme faizi: her ay %5, ay kesirleri tam ay; toplam faiz cezanın iki katını geçemez (md. 115).
double gecikmeFaizi(double tutar, int ay) {
  final faiz = tutar * 0.05 * ay;
  return faiz > tutar * 2 ? tutar * 2 : faiz;
}

// ---------------------------------------------------------------- yaş
/// [dogum] tarihli kişinin [tarih] günündeki yaşı: (yıl, ay, gün).
(int, int, int) yasHesapla(DateTime dogum, DateTime tarih) {
  // Doğum gününe tam ay eklenir (ayın o günü yoksa ayın son günü alınır); artan kısım gün olarak sayılır.
  DateTime ayEkle(int ay) {
    final ilk = DateTime.utc(dogum.year, dogum.month + ay, 1);
    final sonGun = DateTime.utc(ilk.year, ilk.month + 1, 0).day;
    return DateTime.utc(ilk.year, ilk.month, dogum.day > sonGun ? sonGun : dogum.day);
  }

  final gun = DateTime.utc(tarih.year, tarih.month, tarih.day);
  var ay = (tarih.year - dogum.year) * 12 + tarih.month - dogum.month;
  if (ayEkle(ay).isAfter(gun)) ay--;
  return (ay ~/ 12, ay % 12, gun.difference(ayEkle(ay)).inDays);
}

/// [yas] yaşının doldurulduğu gün (doğum gününün o yıldaki karşılığı).
DateTime yasDoldurma(DateTime dogum, int yas) => DateTime(dogum.year + yas, dogum.month, dogum.day);
