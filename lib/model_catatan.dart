class Catatan {
  final String id;
  String judul;
  String isi;
  String? pathFoto; // null = tidak ada foto
  DateTime dibuatPada;

  Catatan({
    required this.id,
    required this.judul,
    required this.isi,
    this.pathFoto,
    DateTime? dibuatPada,
  }) : dibuatPada = dibuatPada ?? DateTime.now();
}
