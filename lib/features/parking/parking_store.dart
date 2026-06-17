import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class ParkingStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  ParkingStore(this._pb, this._authStore);

  final _parkingLotsList = ref<List<ParkingLotsRecord>>([]);
  final _currentParkingLot = ref<ParkingLotsRecord?>(null);
  final _parkingSpaces = ref<List<ParkingSpacesRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<ParkingLotsRecord>> get parkingLotsList => _parkingLotsList;
  Ref<ParkingLotsRecord?> get currentParkingLot => _currentParkingLot;
  Ref<List<ParkingSpacesRecord>> get parkingSpaces => _parkingSpaces;
  Ref<bool> get loading => _loading;

  Future<bool> getAllParkingLots() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb.collection(Collections.parkingLots).getFullList(
        filter: 'association="$assocId"',
      );
      _parkingLotsList.value = records
          .map((r) => ParkingLotsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error fetching parking lots: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getParkingLot(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.parkingLots).getOne(id);
      _currentParkingLot.value = ParkingLotsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error fetching parking lot: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getParkingSpaces(String parkingLotId) async {
    try {
      final records = await _pb.collection(Collections.parkingSpaces).getFullList(
        filter: 'parking_lot="$parkingLotId"',
        expand: 'residence',
      );
      _parkingSpaces.value = records
          .map((r) => ParkingSpacesRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error fetching parking spaces: $e');
      return false;
    }
  }

  Future<bool> createParkingLot({
    required String name,
    String? description,
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String parkingType,
    int? capacity,
    String? bookingPeriodType,
    double? pricePerBookingPeriod,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';

      await _pb.collection(Collections.parkingLots).create(body: {
        'name': name,
        'description': description ?? '',
        'association': assocId,
        'user': userId,
        'street_address': streetAddress,
        'zip_code': zipCode,
        'locality': locality,
        'parking_type': parkingType,
        'capacity': capacity,
        'booking_period_type': bookingPeriodType ?? '',
        'price_per_booking_period': pricePerBookingPeriod,
      });

      await getAllParkingLots();
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error creating parking lot: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> createParkingSpace({
    required String parkingLotId,
    required String name,
    String? residence,
    bool hasChargingStation = false,
    String? parkingStartDate,
  }) async {
    try {
      await _pb.collection(Collections.parkingSpaces).create(body: {
        'parking_lot': parkingLotId,
        'name': name,
        'residence': residence ?? '',
        'has_charging_station': hasChargingStation,
        'parking_start_date': parkingStartDate ?? '',
      });

      await getParkingSpaces(parkingLotId);
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error creating parking space: $e');
      return false;
    }
  }

  Future<bool> updateParkingSpace({
    required String id,
    required String name,
    String? residence,
    bool hasChargingStation = false,
    String? parkingStartDate,
    required String parkingLotId,
  }) async {
    try {
      await _pb.collection(Collections.parkingSpaces).update(id, body: {
        'name': name,
        'residence': residence ?? '',
        'has_charging_station': hasChargingStation,
        'parking_start_date': parkingStartDate ?? '',
      });

      await getParkingSpaces(parkingLotId);
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error updating parking space: $e');
      return false;
    }
  }

  Future<bool> deleteParkingLot(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.parkingLots).delete(id);
      await getAllParkingLots();
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error deleting parking lot: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteParkingSpace(String id, String parkingLotId) async {
    try {
      await _pb.collection(Collections.parkingSpaces).delete(id);
      await getParkingSpaces(parkingLotId);
      return true;
    } catch (e) {
      debugPrint('ParkingStore: Error deleting parking space: $e');
      return false;
    }
  }
}
