import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

class PlacesStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  PlacesStore(this._pb, this._authStore) {
    _places = Paginated<PlacesRecord>((page, perPage) async {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return const PageResult([], 0);
      final res = await _pb
          .collection(Collections.places)
          .getList(
            page: page,
            perPage: perPage,
            filter: 'association="$assocId"',
          );
      return PageResult(
        res.items.map((r) => PlacesRecord.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  late final Paginated<PlacesRecord> _places;
  final _currentPlace = ref<PlacesRecord?>(null);
  final _bookings = ref<List<PlaceBookingsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<PlacesRecord>> get placesList => _places.items;
  Ref<PlacesRecord?> get currentPlace => _currentPlace;
  Ref<List<PlaceBookingsRecord>> get bookings => _bookings;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _places.loading;
  Ref<bool> get loadingMore => _places.loadingMore;
  Ref<bool> get hasMore => _places.hasMore;

  Future<void> getAllPlaces() => _places.refresh();
  Future<void> fetchNextPlaces() => _places.loadMore();

  Future<bool> getPlace(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.places).getOne(id);
      _currentPlace.value = PlacesRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error fetching place: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getBookings(String placeId) async {
    try {
      final records = await _pb
          .collection(Collections.placeBookings)
          .getFullList(filter: 'place="$placeId"', expand: 'residence');
      _bookings.value = records
          .map((r) => PlaceBookingsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error fetching bookings: $e');
      return false;
    }
  }

  Future<bool> createPlace({
    required String name,
    String? description,
    required String streetAddress,
    required String zipCode,
    required String locality,
    String? placeType,
    required String bookingStartTime,
    required String bookingEndTime,
    required int bookingSlotDurationLength,
    required String bookingSlotDurationType,
    int? maxRoomCapacity,
    double? pricePerSlot,
    String? allowedBookingPeriodType,
    int? allowedNumberOfBookingsPerPeriod,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';

      await _pb
          .collection(Collections.places)
          .create(
            body: {
              'name': name,
              'description': description ?? '',
              'association': assocId,
              'user': userId,
              'street_address': streetAddress,
              'zip_code': zipCode,
              'locality': locality,
              'place_type': placeType ?? '',
              'booking_start_time': bookingStartTime,
              'booking_end_time': bookingEndTime,
              'booking_slot_duration_length': bookingSlotDurationLength,
              'booking_slot_duration_type': bookingSlotDurationType,
              'max_room_capacity': maxRoomCapacity,
              'price_per_slot': pricePerSlot,
              'allowed_booking_period_type': allowedBookingPeriodType ?? '',
              'allowed_number_of_bookings_per_period':
                  allowedNumberOfBookingsPerPeriod,
            },
          );

      await getAllPlaces();
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error creating place: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updatePlace({
    required String id,
    required String name,
    String? description,
    required String streetAddress,
    required String zipCode,
    required String locality,
    String? placeType,
    required String bookingStartTime,
    required String bookingEndTime,
    required int bookingSlotDurationLength,
    required String bookingSlotDurationType,
    int? maxRoomCapacity,
    double? pricePerSlot,
    String? allowedBookingPeriodType,
    int? allowedNumberOfBookingsPerPeriod,
  }) async {
    _loading.value = true;
    try {
      await _pb
          .collection(Collections.places)
          .update(
            id,
            body: {
              'name': name,
              'description': description ?? '',
              'street_address': streetAddress,
              'zip_code': zipCode,
              'locality': locality,
              'place_type': placeType ?? '',
              'booking_start_time': bookingStartTime,
              'booking_end_time': bookingEndTime,
              'booking_slot_duration_length': bookingSlotDurationLength,
              'booking_slot_duration_type': bookingSlotDurationType,
              'max_room_capacity': maxRoomCapacity,
              'price_per_slot': pricePerSlot,
              'allowed_booking_period_type': allowedBookingPeriodType ?? '',
              'allowed_number_of_bookings_per_period':
                  allowedNumberOfBookingsPerPeriod,
            },
          );

      await getPlace(id);
      await getAllPlaces();
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error updating place: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deletePlace(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.places).delete(id);
      await getAllPlaces();
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error deleting place: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> addBooking({
    required String placeId,
    required String startAt,
    required String endAt,
    String? title,
    String? description,
    bool isAllDay = false,
    bool isBlock = false,
  }) async {
    try {
      final userId = _authStore.currentUser.value?.id ?? '';
      final residenceId = _authStore.residence.value?.id ?? '';

      await _pb
          .collection(Collections.placeBookings)
          .create(
            body: {
              'place': placeId,
              'residence': residenceId,
              'user': userId,
              'start_at': startAt,
              'end_at': endAt,
              'title': title ?? '',
              'description': description ?? '',
              'is_all_day': isAllDay,
              'is_block': isBlock,
            },
          );

      await getBookings(placeId);
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error adding booking: $e');
      return false;
    }
  }

  Future<bool> deleteBooking(String bookingId, String placeId) async {
    try {
      await _pb.collection(Collections.placeBookings).delete(bookingId);
      await getBookings(placeId);
      return true;
    } catch (e) {
      debugPrint('PlacesStore: Error deleting booking: $e');
      return false;
    }
  }

  static Color parseBookingColor(bool isBlock) {
    return isBlock ? const Color(0xFF808080) : const Color(0xFF2ed188);
  }
}
