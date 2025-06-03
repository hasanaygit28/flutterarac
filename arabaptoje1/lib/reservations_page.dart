import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rezervasyonlarım')),
        body: const Center(child: Text('Lütfen giriş yapın.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyonlarım')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('Henüz rezervasyon yok.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final docSnapshot = docs[index];
              final data = docSnapshot.data() as Map<String, dynamic>;

              Future<void> deleteReservation() async {
                await FirebaseFirestore.instance
                    .collection('reservations')
                    .doc(docSnapshot.id)
                    .delete();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rezervasyon silindi')),
                );
              }

              void showDeleteDialog() {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFFFDF6ED),
                    title: const Text(
                      'Rezervasyonu Sil',
                      style: TextStyle(color: Colors.black),
                    ),
                    content: const Text(
                      'Bu rezervasyonu silmek istiyor musunuz?',
                      style: TextStyle(color: Colors.black87),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('İptal', style: TextStyle(color: Color(0xFF8D6E63))),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await deleteReservation();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D6E63),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Evet'),
                      ),
                    ],
                  ),
                );
              }

              final startTS = data['reservationStartDate'] as Timestamp?;
              final endTS = data['reservationEndDate'] as Timestamp?;
              final startDate = startTS?.toDate();
              final endDate = endTS?.toDate();

              final String formattedStart = startDate == null
                  ? '---'
                  : '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
              final String formattedEnd = endDate == null
                  ? '---'
                  : '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

              final timestamp = data['timestamp'] as Timestamp?;
              final createdTime = timestamp != null
                  ? timestamp.toDate().toLocal().toString()
                  : 'Zaman yok';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.black),
                  title: Text(
                    'Araç: ${data['carTitle']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Başlangıç: $formattedStart\nBitiş: $formattedEnd',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        'Oluşturma Zamanı: $createdTime',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: showDeleteDialog,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
