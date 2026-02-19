import 'package:flutter/material.dart';

// 1. FUNGSI MENAMPILKAN LOADING SCENE
void showLoading(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // User tidak bisa klik luar untuk tutup
    builder: (context) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD32F2F)),
              SizedBox(height: 16),
              Text(
                "Mohon Tunggu...",
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none, // Hilangkan garis bawah kuning
                  fontFamily: 'Arial', // Font standar biar aman
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// 2. FUNGSI TUTUP LOADING
void hideLoading(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

// 3. FUNGSI PINDAH HALAMAN DENGAN ANIMASI (SLIDE)
void navigateTo(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animasi Slide dari Kanan ke Kiri
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}