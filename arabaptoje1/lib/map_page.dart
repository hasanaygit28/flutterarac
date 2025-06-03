import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class MapPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? selectedCarTitle;

  const MapPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.selectedCarTitle,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  LatLng? selectedCarPosition;
  String? selectedCarTitle;
  LatLng? userPosition;

  DateTimeRange? selectedDateRange;
  final Set<Marker> markers = {};
  final LatLng defaultPosition = const LatLng(41.0082, 28.9784);

  @override
  void initState() {
    super.initState();
    _loadCarMarkers();
  }

  void _loadCarMarkers() async {
    try {
      final carsSnapshot = await FirebaseFirestore.instance.collection('cars').get();

      for (var car in carsSnapshot.docs) {
        final carData = car.data();
        final lat = carData['latitude'] as double?;
        final lng = carData['longitude'] as double?;

        if (lat != null && lng != null) {
          setState(() {
            markers.add(
              Marker(
                markerId: MarkerId(car.id),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: carData['title'],
                  snippet: 'Bu aracı rezerve et',
                  onTap: () {
                    setState(() {
                      selectedDateRange = null;
                      selectedCarPosition = LatLng(lat, lng);
                      selectedCarTitle = carData['title'];
                    });
                    _showReserveDialog();
                  },
                ),
              ),
            );
          });
        }
      }
    } catch (e) {
      developer.log('Error loading cars from Firestore: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation();
    _goToInitialCarIfProvided();
  }

  Future<void> _goToInitialCarIfProvided() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      final latLng = LatLng(widget.initialLat!, widget.initialLng!);
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 14),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      if (!mounted) return;
      setState(() {
        userPosition = LatLng(position.latitude, position.longitude);
        markers.add(
          Marker(
            markerId: const MarkerId('userLocation'),
            position: userPosition!,
            infoWindow: const InfoWindow(title: 'Benim Konumum'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userPosition!, zoom: 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      developer.log('Error getting user location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum alınırken hata oluştu.')),
      );
    }
  }

  Future<void> _reserveCar() async {
    if (selectedCarPosition == null || selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir araç seçin ve tarih aralığı belirleyin!'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen giriş yapın!')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reservations').add({
        'userId': user.uid,
        'userEmail': user.email,
        'timestamp': Timestamp.now(),
        'carLat': selectedCarPosition!.latitude,
        'carLng': selectedCarPosition!.longitude,
        'carTitle': selectedCarTitle,
        'reservationStartDate': Timestamp.fromDate(selectedDateRange!.start),
        'reservationEndDate': Timestamp.fromDate(selectedDateRange!.end),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$selectedCarTitle başarıyla rezerve edildi!')),
      );

      _showSuccessDialog(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyon işlemi sırasında hata oluştu.')),
      );
      developer.log('Rezervasyon hatası: $e');
    }
  }

  Future<void> _showSuccessDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDF6ED),
          title: const Text('Rezervasyon Başarılı!'),
          content: const Text('Rezervasyon başarıyla kaydedildi!'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF92766B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  void _showReserveDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDF6ED),
              title: Text('Araç: $selectedCarTitle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bu aracı rezerve etmek için tarih aralığı seçin:'),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: dialogContext,
                        initialDateRange: selectedDateRange,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2101),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF92766B),
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
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          selectedDateRange = picked;
                        });
                      }
                    },
                    child: Text(
                      selectedDateRange == null
                          ? 'Tarih Aralığı Seçin'
                          : 'Başlangıç: ${selectedDateRange!.start.toLocal().toString().split(' ')[0]}\n'
                              'Bitiş: ${selectedDateRange!.end.toLocal().toString().split(' ')[0]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF92766B)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF92766B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _reserveCar();
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.selectedCarTitle ?? 'Harita';

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: defaultPosition,
              zoom: 10,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
        ],
      ),
    );
  }
}
