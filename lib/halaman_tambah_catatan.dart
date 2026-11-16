import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'izin_kamera.dart';
import 'model_catatan.dart';

class HalamanTambahCatatan extends StatefulWidget {
  /// Jika `catatanAwal` diisi, halaman ini jadi mode edit.
  final Catatan? catatanAwal;

  const HalamanTambahCatatan({super.key, this.catatanAwal});

  @override
  State<HalamanTambahCatatan> createState() => _HalamanTambahCatatanState();
}

class _HalamanTambahCatatanState extends State<HalamanTambahCatatan> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulCtrl;
  late final TextEditingController _isiCtrl;

  final ImagePicker _picker = ImagePicker();

  String? _pathFoto;
  bool _sedangMemprosesGambar = false; // indikator loading
  bool _sedangMenyimpan = false;

  StatusIzinKamera? _statusIzin;
  bool _sedangMintaIzin = false;

  @override
  void initState() {
    super.initState();
    final awal = widget.catatanAwal;
    _judulCtrl = TextEditingController(text: awal?.judul ?? '');
    _isiCtrl = TextEditingController(text: awal?.isi ?? '');
    _pathFoto = awal?.pathFoto;
    _cekJikaAdaIzin();
  }

  @override
  void dispose() {
    // Selalu dispose controller teks.
    _judulCtrl.dispose();
    _isiCtrl.dispose();
    super.dispose();
  }

  // ========================================================
  // Alur izin
  // ========================================================
  Future<void> _cekJikaAdaIzin() async {
    final status = await cekStatusIzinKamera();
    if (!mounted) return;
    setState(() => _statusIzin = status);
  }

  Future<bool> _pastikanIzinKamera() async {
    final status = await cekStatusIzinKamera();
    if (!mounted) return false;

    if (status == StatusIzinKamera.granted) {
      setState(() => _statusIzin = status);
      return true;
    }

    // Minta izin lewat dialog sistem.
    setState(() => _sedangMintaIzin = true);
    final baru = await mintaIzinKamera();
    if (!mounted) return false;

    setState(() {
      _statusIzin = baru;
      _sedangMintaIzin = false;
    });

    if (baru == StatusIzinKamera.granted) return true;

    // Tampilkan penjelasan sesuai status.
    _tampilkanDialogIzin(baru);
    return false;
  }

  /// Dialog penjelasan izin (inti praktikum 3, dipakai di sini).
  void _tampilkanDialogIzin(StatusIzinKamera status) {
    String judul;
    String pesan;
    String labelTombol = 'Mengerti';
    VoidCallback? aksiTambahan;

    switch (status) {
      case StatusIzinKamera.denied:
        judul = 'Izin Kamera Ditolak';
        pesan =
            'Aplikasi memerlukan akses kamera untuk mengambil foto catatan. '
            'Tanpa izin ini, kamu tidak bisa mengambil foto dari kamera.\n\n'
            'Sebagai alternatif, kamu masih bisa memilih foto dari galeri.';
        break;
      case StatusIzinKamera.permanentlyDenied:
        judul = 'Izin Kamera Ditolak Permanen';
        pesan =
            'Kamu menolak izin kamera secara permanen. Untuk mengaktifkannya '
            'kembali, buka Pengaturan aplikasi → Perizinan → Kamera → Izinkan.';
        labelTombol = 'Buka Pengaturan';
        aksiTambahan = () async {
          await bukaPengaturanAplikasi();
        };
        break;
      case StatusIzinKamera.restricted:
        judul = 'Kamera Dibatasi Sistem';
        pesan =
            'Akses kamera dibatasi oleh kebijakan perangkat. '
            'Gunakan galeri sebagai alternatif untuk menambahkan foto.';
        break;
      case StatusIzinKamera.granted:
        return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: Text(pesan),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (aksiTambahan != null) aksiTambahan();
            },
            child: Text(labelTombol),
          ),
          if (labelTombol != 'Mengerti')
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Nanti Saja'),
            ),
        ],
      ),
    );
  }

  // ========================================================
  // Ambil gambar
  // ========================================================
  Future<void> _ambilDariKamera() async {
    if (_sedangMemprosesGambar) return;

    // Izin hanya diperlukan untuk kamera.
    final diizinkan = await _pastikanIzinKamera();
    if (!diizinkan) return;

    await _prosesAmbilGambar(ImageSource.camera);
  }

  Future<void> _pilihDariGaleri() async {
    if (_sedangMemprosesGambar) return;
    // Galeri tidak butuh izin kamera, langsung saja.
    await _prosesAmbilGambar(ImageSource.gallery);
  }

  Future<void> _prosesAmbilGambar(ImageSource source) async {
    setState(() => _sedangMemprosesGambar = true);

    try {
      final XFile? berkas = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );

      // User membatalkan → tidak ada error, tidak crash.
      if (berkas == null) {
        if (mounted) setState(() => _sedangMemprosesGambar = false);
        return;
      }

      // Salin ke direktori permanen agar aman.
      final dir = await getApplicationDocumentsDirectory();
      final namaFile = 'catatan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePermanen = await File(berkas.path)
          .copy('${dir.path}/$namaFile');

      if (!mounted) return;

      setState(() {
        _pathFoto = filePermanen.path;
        _sedangMemprosesGambar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMemprosesGambar = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memproses gambar: $e')));
    }
  }

  void _hapusFoto() {
    setState(() => _pathFoto = null);
  }

  // ========================================================
  // Simpan catatan
  // ========================================================
  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sedangMenyimpan) return;

    setState(() => _sedangMenyimpan = true);

    try {
      final catatanBaru = Catatan(
        id:
            widget.catatanAwal?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        judul: _judulCtrl.text.trim(),
        isi: _isiCtrl.text.trim(),
        pathFoto: _pathFoto,
        dibuatPada: widget.catatanAwal?.dibuatPada,
      );

      if (!mounted) return;
      Navigator.of(context).pop(catatanBaru);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  // ========================================================
  // Build
  // ========================================================
  @override
  Widget build(BuildContext context) {
    final modeEdit = widget.catatanAwal != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(modeEdit ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          IconButton(
            onPressed: _sedangMenyimpan ? null : _simpan,
            icon: _sedangMenyimpan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _judulCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Catatan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _isiCtrl,
              decoration: const InputDecoration(
                labelText: 'Isi Catatan',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Isi wajib diisi' : null,
            ),
            const SizedBox(height: 24),

            // ===== Bagian foto =====
            const Text(
              'Foto Catatan (opsional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildAreaFoto(),
            const SizedBox(height: 16),

            // Tombol ambil/pilih foto
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sedangMemprosesGambar ? null : _ambilDariKamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sedangMemprosesGambar ? null : _pilihDariGaleri,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),

            // Info status izin kalau belum granted
            if (_statusIzin != null &&
                _statusIzin != StatusIzinKamera.granted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusIzin == StatusIzinKamera.permanentlyDenied
                            ? 'Izin kamera ditolak permanen. Buka pengaturan untuk mengaktifkan.'
                            : 'Izin kamera belum diberikan. Kamu masih bisa memilih dari galeri.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAreaFoto() {
    if (_sedangMemprosesGambar) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Memproses gambar...'),
            ],
          ),
        ),
      );
    }

    if (_pathFoto == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Belum ada foto', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_pathFoto!),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(child: Text('Foto tidak dapat dimuat')),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: _hapusFoto,
              tooltip: 'Hapus foto',
            ),
          ),
        ),
      ],
    );
  }
}
