import 'dart:io';

import 'package:flutter/material.dart';

import 'model_catatan.dart';

class HalamanDetailCatatan extends StatelessWidget {
  final Catatan catatan;

  const HalamanDetailCatatan({super.key, required this.catatan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(catatan.judul)),
      body: ListView(
        children: [
          if (catatan.pathFoto != null)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.file(File(catatan.pathFoto!)),
                  ),
                ),
              ),
              child: Image.file(
                File(catatan.pathFoto!),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('Foto tidak dapat dimuat')),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catatan.judul,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dibuat: ${catatan.dibuatPada.day}/${catatan.dibuatPada.month}/${catatan.dibuatPada.year}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  catatan.isi,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
