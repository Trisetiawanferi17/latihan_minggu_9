import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class HalamanProfil extends StatefulWidget {
  const HalamanProfil({super.key});

  @override
  State<HalamanProfil> createState() => _HalamanProfilState();
}

class _HalamanProfilState extends State<HalamanProfil> {
  final ImagePicker _picker = ImagePicker();
  File? _fotoProfil;
  bool _sedangMemproses = false;

  /// Ambil foto dari kamera sistem.
  Future<void> _ambilDariKamera() async {
    await _pilihFoto(ImageSource.camera);
  }

  /// Pilih foto dari galeri.
  Future<void> _pilihDariGaleri() async {
    await _pilihFoto(ImageSource.gallery);
  }

  /// Fungsi umum untuk mengambil/memilih foto.
  Future<void> _pilihFoto(ImageSource source) async {
    if (_sedangMemproses) return;

    setState(() => _sedangMemproses = true);

    try {
      final XFile? berkas = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );

      // Pengguna membatalkan → berkas null, tidak perlu error.
      if (berkas == null) return;

      // Cek mounted sebelum setState setelah operasi async.
      if (!mounted) return;
      setState(() => _fotoProfil = File(berkas.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    } finally {
      if (mounted) setState(() => _sedangMemproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar lingkaran
            CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _fotoProfil != null
                  ? FileImage(_fotoProfil!)
                  : null,
              child: _fotoProfil == null
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 24),

            // Loading indicator kecil saat memproses
            if (_sedangMemproses)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              ),

            // Tombol ambil dari kamera
            ElevatedButton.icon(
              onPressed: _sedangMemproses ? null : _ambilDariKamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Ambil dari Kamera'),
            ),
            const SizedBox(height: 12),

            // Tombol pilih dari galeri
            OutlinedButton.icon(
              onPressed: _sedangMemproses ? null : _pilihDariGaleri,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pilih dari Galeri'),
            ),
          ],
        ),
      ),
    );
  }
}
