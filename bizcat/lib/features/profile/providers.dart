import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Copy of the profile screens (BIZCAT-SPEC §9.12).
abstract final class ProfileCopy {
  static const nameTooShort = "Ism kamida 2 ta harf bo'lsin.";
  static const nameTooLong = 'Ism 64 ta belgidan oshmasin.';
}

/// Trimmed 2..64 characters; returns the error text or null.
String? validateProfileName(String raw) {
  final n = raw.trim();
  if (n.length < 2) return ProfileCopy.nameTooShort;
  if (n.length > 64) return ProfileCopy.nameTooLong;
  return null;
}

/// GET Endpoints.consumerMe -> ConsumerUser (with stats); also refreshes the session copy.
/// Re-read after sign-in/out, bookings and reviews change.
final profileProvider = FutureProvider.autoDispose<ConsumerUser>((ref) async {
  final consumerId = ref.watch(consumerIdProvider);
  ref
    ..watch(bookingsRevisionProvider)
    ..watch(reviewsRevisionProvider);
  if (consumerId == null) throw StateError('signed out');
  final user = await ref
      .read(apiProvider)
      .get<ConsumerUser>(Endpoints.consumerMe, decode: (d) => ConsumerUser.fromJson(JsonRead.object(d)));
  if (ref.mounted) ref.read(sessionProvider.notifier).updateConsumer(user);
  return user;
});

const Object _keep = Object();

/// The edit form: the loaded [original] and the draft values.
@immutable
final class ProfileEditState {
  const ProfileEditState({
    required this.original,
    required this.name,
    this.birthday,
    this.gender,
    this.city,
    this.saving = false,
    this.fieldErrors = const {},
    this.error,
  });

  factory ProfileEditState.of(ConsumerUser u) =>
      ProfileEditState(original: u, name: u.name ?? '', birthday: u.birthday, gender: u.gender, city: u.city);

  final ConsumerUser original;
  final String name;
  final LocalDate? birthday;
  final Gender? gender;

  /// null = not set.
  final String? city;
  final bool saving;

  /// 422 pointer -> message (name, birthday, gender, city, locale).
  final Map<String, String> fieldErrors;
  final String? error;

  String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  bool get nameChanged => name.trim() != (original.name ?? '').trim();
  bool get birthdayChanged => birthday != original.birthday;
  bool get genderChanged => gender != original.gender;
  bool get cityChanged => _clean(city) != _clean(original.city);
  bool get changed => nameChanged || birthdayChanged || genderChanged || cityChanged;

  /// ONLY the changed fields. A cleared birthday/gender/city is sent as an explicit null.
  Map<String, dynamic> patchBody() {
    final patch = ConsumerProfilePatch(
      name: nameChanged ? name.trim() : null,
      birthday: birthdayChanged ? birthday : null,
      gender: genderChanged ? gender : null,
      city: cityChanged ? _clean(city) : null,
    ).toJson();
    if (birthdayChanged && birthday == null) patch['birthday'] = null;
    if (genderChanged && gender == null) patch['gender'] = null;
    if (cityChanged && _clean(city) == null) patch['city'] = null;
    return patch;
  }

  ProfileEditState copyWith({
    ConsumerUser? original,
    String? name,
    Object? birthday = _keep,
    Object? gender = _keep,
    Object? city = _keep,
    bool? saving,
    Map<String, String>? fieldErrors,
    Object? error = _keep,
  }) => ProfileEditState(
    original: original ?? this.original,
    name: name ?? this.name,
    birthday: identical(birthday, _keep) ? this.birthday : birthday as LocalDate?,
    gender: identical(gender, _keep) ? this.gender : gender as Gender?,
    city: identical(city, _keep) ? this.city : city as String?,
    saving: saving ?? this.saving,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    error: identical(error, _keep) ? this.error : error as String?,
  );
}

/// null while no consumer is known (the route requires auth, so only for a moment).
final profileEditControllerProvider = NotifierProvider.autoDispose<ProfileEditController, ProfileEditState?>(
  ProfileEditController.new,
);

class ProfileEditController extends Notifier<ProfileEditState?> {
  @override
  ProfileEditState? build() {
    final u = ref.read(currentConsumerProvider);
    // The session may still be restoring: seed the form once the consumer arrives.
    ref.listen<ConsumerUser?>(currentConsumerProvider, (_, next) {
      if (state == null && next != null) state = ProfileEditState.of(next);
    });
    return u == null ? null : ProfileEditState.of(u);
  }

  void _edit(ProfileEditState Function(ProfileEditState s) f) {
    final s = state;
    if (s != null) state = f(s);
  }

  Map<String, String> _without(String key) => {...?state?.fieldErrors}..remove(key);

  void setName(String v) => _edit((s) => s.copyWith(name: v, fieldErrors: _without('name'), error: null));
  void setBirthday(LocalDate? v) =>
      _edit((s) => s.copyWith(birthday: v, fieldErrors: _without('birthday'), error: null));
  void setGender(Gender? v) => _edit((s) => s.copyWith(gender: v, fieldErrors: _without('gender'), error: null));
  void setCity(String? v) => _edit((s) => s.copyWith(city: v, fieldErrors: _without('city'), error: null));

  /// PATCH Endpoints.consumerMe with only the changed fields -> ConsumerUser -> session.updateConsumer.
  /// 422 pointers -> fieldErrors; other failures -> error. Returns true on success.
  Future<bool> save() async {
    final s = state;
    if (s == null || s.saving || !s.changed) return false;
    final invalid = validateProfileName(s.name);
    if (invalid != null) {
      state = s.copyWith(fieldErrors: {...s.fieldErrors, 'name': invalid});
      return false;
    }
    state = s.copyWith(saving: true, fieldErrors: const {}, error: null);
    try {
      final user = await ref
          .read(apiProvider)
          .patch<ConsumerUser>(
            Endpoints.consumerMe,
            body: s.patchBody(),
            decode: (d) => ConsumerUser.fromJson(JsonRead.object(d)),
          );
      if (!ref.mounted) return true;
      ref.read(sessionProvider.notifier).updateConsumer(user);
      state = ProfileEditState.of(user);
      return true;
    } on ApiException catch (e) {
      if (!ref.mounted) return false;
      state = e.isValidation && e.hasFieldErrors
          ? state!.copyWith(saving: false, fieldErrors: e.fieldErrors)
          : state!.copyWith(saving: false, error: e.message);
      return false;
    } on Object catch (e) {
      debugPrint('profile: save failed: $e');
      if (ref.mounted) state = state!.copyWith(saving: false, error: 'Xatolik yuz berdi.');
      return false;
    }
  }
}

/// DELETE Endpoints.consumerMe -> 204 -> session.signOut(reason: deleted). Throws on failure.
Future<void> deleteAccount(WidgetRef ref) async {
  await ref.read(apiProvider).delete<Object?>(Endpoints.consumerMe);
  await ref.read(sessionProvider.notifier).signOut(reason: SignOutReason.deleted);
}
