import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'izin_kamera.dart';

class HalamanKamera extends StatefulWidget {
  const HalamanKamera({super.key});

  @override
  State<HalamanKamera> createState() => _HalamanKameraState();
}

class _HalamanKameraState extends State<HalamanKamera>
    with WidgetsBindingObserver {
  List<CameraDescription> _daftarKamera = [];
  CameraController? _controller;
  int _indexKameraAktif = 0;
  String? _pesanError;

  final List<File> _fotoTerakhir = [];
  static const int _maksFotoTerakhir = 3;

  /// Status izin kamera saat ini.
  StatusIzinKamera? _statusIzin;

  /// True jika sedang meminta izin (supaya tombol tidak ditekan ganda).
  bool _sedangMintaIzin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mulaiDenganCekIzin();
  }

  /// Alur awal: cek izin dulu → baru siapkan kamera.
  Future<void> _mulaiDenganCekIzin() async {
    final status = await cekStatusIzinKamera();

    if (!mounted) return;

    if (status != StatusIzinKamera.granted) {
      // Belum granted — tampilkan UI izin, JANGAN inisialisasi controller.
      setState(() => _statusIzin = status);
      return;
    }

    setState(() => _statusIzin = StatusIzinKamera.granted);
    await _siapkanKamera();
  }

  /// Minta izin lewat dialog sistem.
  Future<void> _mintaIzin() async {
    if (_sedangMintaIzin) return;
    setState(() => _sedangMintaIzin = true);

    try {
      final status = await mintaIzinKamera();
      if (!mounted) return;

      setState(() {
        _statusIzin = status;
        _sedangMintaIzin = false;
      });

      // Jika granted, baru inisialisasi kamera.
      if (status == StatusIzinKamera.granted) {
        await _siapkanKamera();
      }
    } catch (_) {
      // Jangan pernah crash — apapun errornya.
      if (!mounted) return;
      setState(() {
        _sedangMintaIzin = false;
        _pesanError = 'Terjadi kesalahan saat meminta izin kamera.';
      });
    }
  }

  /// Cek ulang status izin setelah user kembali dari pengaturan.
  Future<void> _cekJikaKembaliDariPengaturan() async {
    final status = await cekStatusIzinKamera();
    if (!mounted) return;

    if (status == StatusIzinKamera.granted) {
      setState(() {
        _statusIzin = StatusIzinKamera.granted;
        _pesanError = null;
      });
      await _siapkanKamera();
    } else {
      setState(() => _statusIzin = status);
    }
  }

  Future<void> _siapkanKamera() async {
    // Jangan pernah inisialisasi kamera tanpa izin.
    if (_statusIzin != StatusIzinKamera.granted) return;

    try {
      _daftarKamera = await availableCameras();
      if (_daftarKamera.isEmpty) {
        if (!mounted) return;
        setState(() => _pesanError = 'Tidak ada kamera pada perangkat ini');
        return;
      }
      await _buatController(_daftarKamera[_indexKameraAktif]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _pesanError = 'Kamera gagal disiapkan: ${e.code}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _pesanError = 'Kamera gagal disiapkan.');
    }
  }

  Future<void> _buatController(CameraDescription kamera) async {
    final controllerBaru = CameraController(
      kamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controllerBaru.initialize();

      final controllerLama = _controller;
      if (controllerLama != null) {
        await controllerLama.dispose();
      }

      if (!mounted) {
        await controllerBaru.dispose();
        return;
      }

      setState(() {
        _controller = controllerBaru;
        _pesanError = null;
      });
    } on CameraException catch (e) {
      await controllerBaru.dispose();
      if (!mounted) return;
      // Jika izin dicabut di tengah jalan (misal dari pengaturan), tangani.
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted') {
        final statusBaru = await cekStatusIzinKamera();
        if (!mounted) return;
        setState(() {
          _statusIzin = statusBaru;
          _controller = null;
        });
        return;
      }
      setState(() => _pesanError = 'Kamera gagal disiapkan: ${e.code}');
    }
  }

  Future<void> _gantiKamera() async {
    if (_daftarKamera.length < 2) return;
    if (_controller?.value.isTakingPicture ?? false) return;

    final kameraSekarang = _daftarKamera[_indexKameraAktif];
    final kameraLawan = _daftarKamera.indexWhere(
      (k) =>
          k.lensDirection != kameraSekarang.lensDirection &&
          k.lensDirection != CameraLensDirection.external,
    );

    if (kameraLawan == -1) return;

    setState(() => _indexKameraAktif = kameraLawan);
    await _buatController(_daftarKamera[kameraLawan]);
  }

  Future<void> _ambilFoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    try {
      final XFile berkas = await controller.takePicture();

      final dir = await getTemporaryDirectory();
      final namaBaru =
          '${DateTime.now().millisecondsSinceEpoch}_${berkas.name}';
      final filePermanen = await File(berkas.path)
          .copy('${dir.path}/$namaBaru');

      if (!mounted) return;

      setState(() {
        _fotoTerakhir.insert(0, filePermanen);
        while (_fotoTerakhir.length > _maksFotoTerakhir) {
          final fileLama = _fotoTerakhir.removeLast();
          fileLama.delete().catchError((_) => fileLama);
        }
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _pesanError = 'Gagal mengambil gambar: ${e.code}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _pesanError = 'Gagal mengambil gambar.');
    }
  }

  void _lihatFotoBesar(File foto) {
    showDialog(
      context: context,
      builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(foto))),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      // Saat kembali dari pengaturan, cek ulang izin dulu.
      _cekJikaKembaliDariPengaturan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ===== Kondisi 1: Izin belum granted =====
    if (_statusIzin != null && _statusIzin != StatusIzinKamera.granted) {
      return _buildUiIzin();
    }

    // ===== Kondisi 2: Error fatal =====
    if (_pesanError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kamera')),
        body: _buildError(),
      );
    }

    // ===== Kondisi 3: Controller belum siap =====
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kamera')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ===== Kondisi 4: Kamera siap =====
    return _buildKameraSiap();
  }

  // ========================================================
  // UI: Izin belum granted (inti Praktikum 3)
  // ========================================================
  Widget _buildUiIzin() {
    final status = _statusIzin!;

    // Konten berbeda tergantung status.
    String judul;
    String penjelasan;
    String labelTombol;
    VoidCallback? aksiTombol;
    IconData ikon;
    Color warna;

    switch (status) {
      case StatusIzinKamera.denied:
        judul = 'Izin Kamera Diperlukan';
        penjelasan =
            'Aplikasi memerlukan akses kamera untuk mengambil foto profil '
            'dan dokumentasi praktikum. Tanpa izin ini, fitur kamera tidak '
            'dapat digunakan.\n\n'
            'Kamu bisa memberikan izin sekarang — data foto hanya disimpan '
            'di perangkatmu dan tidak dikirim ke mana pun.';
        labelTombol = 'Izinkan Kamera';
        aksiTombol = _mintaIzin;
        ikon = Icons.camera_alt_outlined;
        warna = Colors.blue;
        break;
      case StatusIzinKamera.permanentlyDenied:
        judul = 'Izin Kamera Ditolak Permanen';
        penjelasan =
            'Kamu sebelumnya menolak izin kamera secara permanen. Untuk '
            'mengaktifkannya kembali, buka Pengaturan aplikasi, lalu pilih '
            'Perizinan → Kamera → Izinkan.\n\n'
            'Setelah izin diberikan, kembali ke aplikasi ini dan kamera akan '
            'aktif otomatis.';
        labelTombol = 'Buka Pengaturan';
        aksiTombol = () async {
          await bukaPengaturanAplikasi();
        };
        ikon = Icons.lock_outline;
        warna = Colors.orange;
        break;
      case StatusIzinKamera.restricted:
        judul = 'Kamera Dibatasi Sistem';
        penjelasan =
            'Akses kamera dibatasi oleh kebijakan perangkat (misalnya mode '
            'anak atau manajemen perangkat). Fitur kamera disembunyikan.\n\n'
            'Sebagai alternatif, kamu masih bisa memilih foto dari galeri '
            'lewat halaman Profil.';
        labelTombol = 'Kembali';
        aksiTombol = () => Navigator.of(context).maybePop();
        ikon = Icons.shield_outlined;
        warna = Colors.grey;
        break;
      case StatusIzinKamera.granted:
        // Tidak mungkin masuk sini.
        return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Izin Kamera')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: 72, color: warna),
                const SizedBox(height: 16),
                Text(
                  judul,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  penjelasan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 24),
                if (aksiTombol != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sedangMintaIzin ? null : aksiTombol,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _sedangMintaIzin
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(labelTombol),
                    ),
                  ),
                // Tombol cadangan: selalu ada jalan keluar.
                if (status != StatusIzinKamera.restricted) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Nanti Saja'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================
  // UI: Error fatal
  // ========================================================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_pesanError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _pesanError = null);
                _cekJikaKembaliDariPengaturan();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================
  // UI: Kamera siap (sama seperti Praktikum 2)
  // ========================================================
  Widget _buildKameraSiap() {
    final ukuran = MediaQuery.of(context).size;
    final tinggiPreview = ukuran.width * _controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kamera'),
        actions: [
          IconButton(
            tooltip: 'Ganti Kamera',
            onPressed: _daftarKamera.length >= 2 ? _gantiKamera : null,
            icon: const Icon(Icons.flip_camera_ios),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: ukuran.width,
                height: tinggiPreview,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: SizedBox(
              height: 80,
              child: _fotoTerakhir.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada foto',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fotoTerakhir.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final foto = _fotoTerakhir[i];
                        return GestureDetector(
                          onTap: () => _lihatFotoBesar(foto),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              foto,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ambilFoto,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
