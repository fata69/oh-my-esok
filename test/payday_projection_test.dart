import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/account.dart';
import 'package:jadwal/data/money_transaction.dart';
import 'package:jadwal/data/payday_dao.dart';
import 'package:jadwal/state/payday_projection.dart';

const _cash = Account(
  id: 'cash',
  name: 'Tunai',
  type: 'cash',
  sortOrder: 0,
  archived: false,
  createdAt: 0,
);

const _schedule = PaydaySchedule(
  accountId: 'cash',
  date: '2026-11-23',
  monthly: true,
);

PlannedBill _bill(
  String id,
  int amount,
  String date, {
  String accountId = 'cash',
}) => PlannedBill(
  id: id,
  name: id,
  amount: amount,
  accountId: accountId,
  date: date,
  monthly: false,
);

void main() {
  test(
    'estimate sums bills on the first deficit date in the selected wallet',
    () {
      final estimate = PaydayProjection.build(
        PaydayPlan(
          schedule: _schedule,
          bills: [
            _bill('Kos', 750000, '2026-11-20'),
            _bill('Internet', 200000, '2026-11-22'),
            _bill('Listrik', 50000, '2026-11-22'),
            _bill('Dompet lain', 100000, '2026-11-22', accountId: 'bank'),
            _bill('Saat gajian', 100000, '2026-11-23'),
          ],
        ),
        today: '2026-11-18',
        balance: 900000,
      );
      expect(estimate.payday, '2026-11-23');
      expect(estimate.items.map((item) => item.bill.id), [
        'Kos',
        'Internet',
        'Listrik',
      ]);
      expect(estimate.firstShort, (date: '2026-11-22', balance: -100000));
      expect(estimate.remaining, -100000);
    },
  );

  test(
    'linked expense is already in the balance and is not deducted twice',
    () {
      const payment = BillPayment(
        billId: 'Kos',
        dueDate: '2026-11-20',
        transactionId: 'cash-expense',
      );
      final estimate = PaydayProjection.build(
        PaydayPlan(
          schedule: _schedule,
          bills: [
            _bill('Kos', 750000, '2026-11-20'),
            _bill('Internet', 120000, '2026-11-22'),
          ],
          payments: const [payment],
        ),
        today: '2026-11-18',
        balance: 150000,
      );
      expect(estimate.items.first.payment, payment);
      expect(estimate.items.first.balanceAfter, 150000);
      expect(estimate.remaining, 30000);
      expect(estimate.firstShort, isNull);
    },
  );

  test(
    'monthly date clamps to February and returns to original day in March',
    () {
      const schedule = PaydaySchedule(
        accountId: 'cash',
        date: '2027-01-31',
        monthly: true,
      );
      const bill = PlannedBill(
        id: 'bill',
        name: 'Uji',
        amount: 100,
        accountId: 'cash',
        date: '2027-01-31',
        monthly: true,
      );
      expect(schedule.nextOnOrAfter('2027-02-02'), '2027-02-28');
      expect(schedule.nextOnOrAfter('2027-03-01'), '2027-03-31');
      expect(bill.occursOn('2027-02-28'), isTrue);
      expect(bill.occursOn('2027-03-28'), isFalse);
      expect(bill.dueBefore('2027-03-01', '2027-04-01'), [
        '2027-02-28',
        '2027-03-31',
      ]);
    },
  );

  test(
    'backup round-trip keeps payment and rejects repeated transaction IDs',
    () {
      const payment = BillPayment(
        billId: 'Kos',
        dueDate: '2026-11-20',
        transactionId: 'expense',
      );
      const expense = MoneyTransaction(
        id: 'expense',
        kind: 'expense',
        amount: 750000,
        accountId: 'cash',
        date: '2026-11-19',
        createdAt: 1,
      );
      final plan = PaydayPlan(
        schedule: _schedule,
        bills: [_bill('Kos', 750000, '2026-11-20')],
        payments: const [payment],
      );
      final restored = PaydayPlan.fromJson(plan.toJson());
      expect(restored.toJson(), plan.toJson());
      expect(
        () => restored.validate(accounts: [_cash], transactions: [expense]),
        returnsNormally,
      );
      final duplicate = PaydayPlan(
        bills: [
          _bill('Kos', 750000, '2026-11-20'),
          _bill('Listrik', 750000, '2026-11-21'),
        ],
        payments: const [
          payment,
          BillPayment(
            billId: 'Listrik',
            dueDate: '2026-11-21',
            transactionId: 'expense',
          ),
        ],
      );
      expect(
        () => duplicate.validate(accounts: [_cash], transactions: [expense]),
        throwsFormatException,
      );
      expect(
        () => restored.validate(
          accounts: [_cash],
          transactions: [expense.copyWith(amount: 20000)],
        ),
        throwsFormatException,
      );
    },
  );
}
