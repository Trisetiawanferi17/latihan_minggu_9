import 'package:permission_handler/permission_handler.dart';

/// Status izin yang sudah disederhanakan untuk UI.
enum StatusIzinKamera { granted, denied, permanentlyDenied, restricted }

/// Minta izin kamera & kembalikan status yang sudah disederhanakan.
Future<StatusIzinKamera> mintaIzinKamera() async {
  final status = await Permission.camera.request();

  if (status.isGranted) return StatusIzinKamera.granted;
  if (status.isPermanentlyDenied) return StatusIzinKamera.permanentlyDenied;
  if (status.isRestricted) return StatusIzinKamera.restricted;
  return StatusIzinKamera.denied;
}

/// Cek status izin tanpa meminta (untuk kondisi awal).
Future<StatusIzinKamera> cekStatusIzinKamera() async {
  final status = await Permission.camera.status;

  if (status.isGranted) return StatusIzinKamera.granted;
  if (status.isPermanentlyDenied) return StatusIzinKamera.permanentlyDenied;
  if (status.isRestricted) return StatusIzinKamera.restricted;
  return StatusIzinKamera.denied;
}

/// Buka pengaturan aplikasi di sistem.
Future<bool> bukaPengaturanAplikasi() async {
  return openAppSettings();
}

/// Cek apakah izin bisa diminta ulang lewat dialog.
bool bisaMintaUlang(StatusIzinKamera status) {
  return status == StatusIzinKamera.denied;
}
