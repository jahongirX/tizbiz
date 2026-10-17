import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A counter that data providers watch; a mutation bumps it so every list refetches.
final class Revision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Appointment create/status (also bump [clientsRevisionProvider]: CRM counters change).
final appointmentsRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Order status changes.
final ordersRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Client create/edit/delete/categories.
final clientsRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Services + service categories.
final servicesRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Staff rows, commission, team links.
final staffRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Working hours + time-off.
final scheduleRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// `bump(ref, appointmentsRevisionProvider)` from a provider / actions class.
void bump(Ref ref, NotifierProvider<Revision, int> p) => ref.read(p.notifier).bump();

/// The same from a widget.
void bumpFromWidget(WidgetRef ref, NotifierProvider<Revision, int> p) => ref.read(p.notifier).bump();
