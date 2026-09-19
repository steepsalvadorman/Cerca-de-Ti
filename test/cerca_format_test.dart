import 'package:flutter_test/flutter_test.dart';

import 'package:cerca/features/cerca/application/cerca_format.dart';
import 'package:cerca/features/cerca/application/cerca_seed_data.dart';
import 'package:cerca/features/cerca/domain/entities/fee_type.dart';
import 'package:cerca/features/cerca/domain/entities/service_provider.dart';

/// `formatSoles` is pure and had no test at all, which is how the CLP/S
/// mix-up in the seed data survived (GAP-95): money formatting and money
/// literals were both unverified.
void main() {
  group('formatSoles', () {
    test('groups thousands the es-PE way', () {
      expect(formatSoles(1234), 'S/ 1,234.00');
      expect(formatSoles(999), 'S/ 999.00');
      expect(formatSoles(1000), 'S/ 1,000.00');
      expect(formatSoles(1000000), 'S/ 1,000,000.00');
    });

    test('handles zero and single digits', () {
      expect(formatSoles(0), 'S/ 0.00');
      expect(formatSoles(7), 'S/ 7.00');
    });

    test('puts the sign before the digits, after the symbol', () {
      expect(formatSoles(-5), 'S/ -5.00');
      expect(formatSoles(-1234), 'S/ -1,234.00');
    });

    test('does not overflow on the largest amount the backend can send', () {
      // The backend stores fee/price/agreed_price as i32.
      expect(formatSoles(2147483647), 'S/ 2,147,483,647.00');
    });
  });

  group('formatShortDate', () {
    test('renders a short local date', () {
      expect(formatShortDate('2026-07-02T12:00:00Z'), contains('jul'));
    });

    test('throws on an unparseable timestamp', () {
      // Documented as-is: unlike formatSoles this one is not defensive, and
      // `client_account_screen.dart` calls it straight on server data. The
      // fix belongs with GAP-50; this test pins today's behaviour so a
      // change is deliberate.
      expect(() => formatShortDate('not-a-date'), throwsA(isA<FormatException>()));
    });
  });

  /// The regression test for GAP-95.
  ///
  /// The seed carried the prototype's Chilean-peso figures while the
  /// backend had already been migrated to soles, so the same team rendered
  /// as "S/ 1,265,000.00" from the client and "S/ 5,110.00" from the API.
  /// These assertions tie the two representations together: the displayed
  /// label must equal the sum of the cost components, and both must be in
  /// soles.
  group('seed money is coherent and in soles', () {
    /// Strips the "Desde " prefix and the trailing ".00" that
    /// `formatSoles` always appends, so a label and the sum of the parts
    /// can be compared as amounts.
    String normalize(String label) {
      final withoutPrefix = label.replaceFirst('Desde ', '').trim();
      return withoutPrefix.endsWith('.00')
          ? withoutPrefix.substring(0, withoutPrefix.length - 3)
          : withoutPrefix;
    }

    test('every team price label matches the sum of its cost components', () {
      for (final TechTeam team in CercaSeedData.teams) {
        final total = team.laborCost + team.materialsCost + team.mobilityCost;
        expect(
          normalize(team.priceLabel),
          normalize(formatSoles(total)),
          reason: '${team.name} advertises "${team.priceLabel}" but its parts add up to '
              '${formatSoles(total)}',
        );
      }
    });

    test('no seed money literal is still in Chilean pesos', () {
      final moneyStrings = <String>[
        ...CercaSeedData.technicians.map((t) => t.priceLabel),
        ...CercaSeedData.teams.map((t) => t.priceLabel),
        ...CercaSeedData.clientHistory.map((h) => h.price),
      ];

      for (final value in moneyStrings) {
        if (value == '—') continue; // "no price", not an amount
        expect(
          value,
          contains('S/'),
          reason: '"$value" is not a soles amount — the CLP prototype figures were '
              'left behind once and rendered ~250x too large',
        );
        expect(
          value,
          isNot(contains(r'$')),
          reason: '"$value" still uses the Chilean peso symbol',
        );
      }
    });

    test('cost components are in a plausible soles range', () {
      for (final TechTeam team in CercaSeedData.teams) {
        for (final amount in [team.laborCost, team.materialsCost, team.mobilityCost]) {
          expect(
            amount,
            lessThan(100000),
            reason: 'a cost component of $amount looks like the old CLP scale',
          );
          expect(amount, greaterThan(0));
        }
      }
    });
  });

  /// The regression test for GAP-96: progress must count the mandatory
  /// documents only. The backend verifies a technician on three of them
  /// (`MANDATORY_DOCUMENT_KEYS`), so dividing by the full list left anyone
  /// who had uploaded everything required reading "3 de 4" forever.
  group('document requirements', () {
    test('the optional document is excluded from the mandatory list', () {
      expect(CercaSeedData.docRequirements.length, 4);
      expect(CercaSeedData.mandatoryDocRequirements.length, 3);

      final keys = CercaSeedData.mandatoryDocRequirements.map((d) => d.key).toList();
      expect(keys, containsAll(<String>['cedula', 'antecedentes', 'especialidad']));
      expect(
        keys,
        isNot(contains('seguro')),
        reason: 'seguro is optional and must not gate verification',
      );
    });

    test('every mandatory document appears in the full list', () {
      final allKeys = CercaSeedData.docRequirements.map((d) => d.key).toSet();
      for (final requirement in CercaSeedData.mandatoryDocRequirements) {
        expect(allKeys, contains(requirement.key));
      }
    });
  });

  /// The bidding fee is owned by the backend (`fee_amount_for`); the client
  /// copy is only a fallback for before the job has loaded. If it drifts,
  /// the button advertises one price and the API charges another (GAP-55).
  group('fee fallback', () {
    test('matches the backend schedule: bidding 4, everything else free', () {
      expect(CercaSeedData.feeConfig[FeeType.bidding]!.amount, 4);
      expect(CercaSeedData.feeConfig[FeeType.direct]!.amount, 0);
      expect(CercaSeedData.feeConfig[FeeType.project]!.amount, 0);
    });
  });
}
