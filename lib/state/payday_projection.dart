import '../data/payday_dao.dart';

typedef ProjectedBill = ({
  PlannedBill bill,
  String dueDate,
  BillPayment? payment,
  int balanceAfter,
});

class PaydayProjection {
  const PaydayProjection._({
    required this.payday,
    required this.remaining,
    required this.items,
    this.firstShort,
  });

  final String? payday;
  final int remaining;
  final List<ProjectedBill> items;
  final ({String date, int balance})? firstShort;

  factory PaydayProjection.build(
    PaydayPlan plan, {
    required String today,
    required int balance,
  }) {
    final schedule = plan.schedule;
    final payday = schedule?.nextOnOrAfter(today);
    if (schedule == null || payday == null) {
      return PaydayProjection._(
        payday: null,
        remaining: balance,
        items: const [],
      );
    }
    final payments = {
      for (final payment in plan.payments)
        (payment.billId, payment.dueDate): payment,
    };
    final occurrences =
        [
          for (final bill in plan.bills)
            if (bill.accountId == schedule.accountId)
              for (final dueDate in bill.dueBefore(today, payday))
                if (dueDate.compareTo(today) >= 0 ||
                    !payments.containsKey((bill.id, dueDate)))
                  (bill: bill, date: dueDate),
        ]..sort((a, b) {
          final date = a.date.compareTo(b.date);
          return date == 0 ? a.bill.id.compareTo(b.bill.id) : date;
        });

    var remaining = balance;
    ({String date, int balance})? firstShort = balance < 0
        ? (date: today, balance: balance)
        : null;
    final items = <ProjectedBill>[];
    for (var i = 0; i < occurrences.length; i++) {
      final occurrence = occurrences[i];
      final bill = occurrence.bill;
      final due = occurrence.date;
      final payment = payments[(bill.id, due)];
      if (payment == null) remaining -= bill.amount;
      items.add((
        bill: bill,
        dueDate: due,
        payment: payment,
        balanceAfter: remaining,
      ));
      if (remaining >= 0) continue;
      final day = due.compareTo(today) < 0 ? today : due;
      // Sum all bills on the first deficit date, including overdue items.
      if (firstShort == null || firstShort.date == day) {
        firstShort = (date: day, balance: remaining);
      }
    }

    return PaydayProjection._(
      payday: payday,
      remaining: remaining,
      items: items,
      firstShort: firstShort,
    );
  }
}
