import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

class GadgetsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  GadgetsStore(this._pb, this._authStore) {
    _gadgets = Paginated<GadgetsRecord>((page, perPage) async {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return const PageResult([], 0);
      final res = await _pb
          .collection(Collections.gadgets)
          .getList(
            page: page,
            perPage: perPage,
            filter: 'association="$assocId"',
          );
      return PageResult(
        res.items.map((r) => GadgetsRecord.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  late final Paginated<GadgetsRecord> _gadgets;
  final _currentGadget = ref<GadgetsRecord?>(null);
  final _bookings = ref<List<GadgetBookingsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<GadgetsRecord>> get gadgetsList => _gadgets.items;
  Ref<GadgetsRecord?> get currentGadget => _currentGadget;
  Ref<List<GadgetBookingsRecord>> get bookings => _bookings;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _gadgets.loading;
  Ref<bool> get loadingMore => _gadgets.loadingMore;
  Ref<bool> get hasMore => _gadgets.hasMore;

  Future<void> getAllGadgets() => _gadgets.refresh();
  Future<void> fetchNextGadgets() => _gadgets.loadMore();

  Future<bool> getGadget(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.gadgets).getOne(id);
      _currentGadget.value = GadgetsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error fetching gadget: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getBookings(String gadgetId) async {
    try {
      final records = await _pb
          .collection(Collections.gadgetBookings)
          .getFullList(filter: 'gadget="$gadgetId"', expand: 'residence');
      _bookings.value = records
          .map((r) => GadgetBookingsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error fetching bookings: $e');
      return false;
    }
  }

  Future<bool> createGadget({
    required String name,
    String? description,
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String bookingStartTime,
    required String bookingEndTime,
    required int bookingSlotDurationLength,
    required String bookingSlotDurationType,
    double? pricePerSlot,
    String? allowedBookingPeriodType,
    int? allowedNumberOfBookingsPerPeriod,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';

      await _pb
          .collection(Collections.gadgets)
          .create(
            body: {
              'name': name,
              'description': description ?? '',
              'association': assocId,
              'user': userId,
              'street_address': streetAddress,
              'zip_code': zipCode,
              'locality': locality,
              'booking_start_time': bookingStartTime,
              'booking_end_time': bookingEndTime,
              'booking_slot_duration_length': bookingSlotDurationLength,
              'booking_slot_duration_type': bookingSlotDurationType,
              'price_per_slot': pricePerSlot,
              'allowed_booking_period_type': allowedBookingPeriodType ?? '',
              'allowed_number_of_bookings_per_period':
                  allowedNumberOfBookingsPerPeriod,
            },
          );

      await getAllGadgets();
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error creating gadget: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteGadget(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.gadgets).delete(id);
      await getAllGadgets();
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error deleting gadget: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> addBooking({
    required String gadgetId,
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
          .collection(Collections.gadgetBookings)
          .create(
            body: {
              'gadget': gadgetId,
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

      await getBookings(gadgetId);
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error adding booking: $e');
      return false;
    }
  }

  Future<bool> deleteBooking(String bookingId, String gadgetId) async {
    try {
      await _pb.collection(Collections.gadgetBookings).delete(bookingId);
      await getBookings(gadgetId);
      return true;
    } catch (e) {
      debugPrint('GadgetsStore: Error deleting booking: $e');
      return false;
    }
  }

  static Color parseBookingColor(bool isBlock) {
    return isBlock ? const Color(0xFF808080) : const Color(0xFF2ed188);
  }
}
