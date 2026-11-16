import 'dart:io';

import 'package:flutter/material.dart';

import 'halaman_tambah_catatan.dart';
import 'halaman_detail_catatan.dart';
import 'model_catatan.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Bergambar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HalamanDaftarCatatan(),
    );
  }
}

class HalamanDaftarCatatan extends StatefulWidget {
  const HalamanDaftarCatatan({super.key});

  @override
  State<HalamanDaftarCatatan> createState() => _HalamanDaftarCatatanState();
}

class _HalamanDaftarCatatanState extends State<HalamanDaftarCatatan> {
  // Catatan disimpan di memori (in-memory). Untuk persistensi, sambungkan ke
  // shared_preferences / sqflite / hive — di luar cakupan tugas ini.
  final List<Catatan> _daftarCatatan = [];

  Future<void> _bukaFormTambah() async {
    final hasil = await Navigator.of(context).push<Catatan>(
      MaterialPageRoute(builder: (_) => const HalamanTambahCatatan()),
    );
    if (hasil == null) return;
    if (!mounted) return;
    setState(() => _daftarCatatan.insert(0, hasil));
  }

  Future<void> _bukaFormEdit(Catatan catatan) async {
    final hasil = await Navigator.of(context).push<Catatan>(
      MaterialPageRoute(
        builder: (_) => HalamanTambahCatatan(catatanAwal: catatan),
      ),
    );
    if (hasil == null) return;
    if (!mounted) return;
    setState(() {
      final idx = _daftarCatatan.indexWhere((c) => c.id == hasil.id);
      if (idx != -1) _daftarCatatan[idx] = hasil;
    });
  }

  Future<void> _konfirmasiHapus(Catatan catatan) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: Text('Catatan "${catatan.judul}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    setState(() => _daftarCatatan.removeWhere((c) => c.id == catatan.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Bergambar'), centerTitle: true),
      body: _daftarCatatan.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _daftarCatatan.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final catatan = _daftarCatatan[i];
                return Card(
                  child: ListTile(
                    leading: _thumb(catatan.pathFoto),
                    title: Text(
                      catatan.judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      catatan.isi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _bukaFormEdit(catatan);
                        if (v == 'hapus') _konfirmasiHapus(catatan);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HalamanDetailCatatan(catatan: catatan),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormTambah,
        icon: const Icon(Icons.add),
        label: const Text('Catatan Baru'),
      ),
    );
  }

  Widget _thumb(String? path) {
    if (path == null) {
      return const CircleAvatar(child: Icon(Icons.note));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const CircleAvatar(child: Icon(Icons.broken_image)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 96, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Belum ada catatan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk memulai',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
