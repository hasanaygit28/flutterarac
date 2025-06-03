import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'map_page.dart';

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  @override
  CarsPageState createState() => CarsPageState();
}

class CarsPageState extends State<CarsPage> {
  Map<String, DateTimeRange?> carDateRanges = {};

  Future<void> _handleReservation(
      String carId, String carTitle, double carLat, double carLng) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: carDateRanges[carId],
      firstDate: DateTime(2023),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8D6E63),
              onPrimary: Colors.white,
              surface: Color(0xFFFDF6ED),
              onSurface: Colors.black,
              secondary: Color(0xFFBCAAA4),
            ),
            dialogTheme: const DialogTheme(
              backgroundColor: Color(0xFFFDF6ED),
            ),
            scaffoldBackgroundColor: Color(0xFFFDF6ED),
            canvasColor: Color(0xFFFDF6ED),
            cardColor: Color(0xFFFDF6ED),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF8D6E63),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || picked == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen giriş yapın!')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reservations').add({
        'userId': user.uid,
        'carId': carId,
        'carTitle': carTitle,
        'carLat': carLat,
        'carLng': carLng,
        'reservationStartDate': Timestamp.fromDate(picked.start),
        'reservationEndDate': Timestamp.fromDate(picked.end),
        'timestamp': Timestamp.now(),
      });

      if (!mounted) return;
      showSuccessDialog(context, carTitle);
    } catch (e) {
      developer.log("Hata:", error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon sırasında hata oluştu.')),
      );
    }
  }

  void showSuccessDialog(BuildContext context, String carTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDF6ED),
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            '$carTitle başarıyla rezerve edildi!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Tamam'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Listesi'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Hiç araç eklenmemiş.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (ctx, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>?;

                    if (data == null) return const SizedBox.shrink();

                    final title = data['title'] ?? 'Bilinmeyen Araç';
                    final lat = data['latitude'] ?? 0.0;
                    final lng = data['longitude'] ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.all(8),
                      color: const Color(0xFFFDF6ED),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.black),
                        title: Text(
                          title,
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          'Konum: ($lat, $lng)',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        onTap: () {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => MapPage(
                                initialLat: lat,
                                initialLng: lng,
                                selectedCarTitle: title,
                              ),
                            ),
                          );
                        },
                        trailing: ElevatedButton(
                          onPressed: () {
                            _handleReservation(doc.id, title, lat, lng);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8D6E63),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Rezerve Et'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
