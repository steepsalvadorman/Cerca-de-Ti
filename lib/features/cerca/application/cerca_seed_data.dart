import '../domain/entities/category.dart';
import '../domain/entities/client_address.dart';
import '../domain/entities/client_history_entry.dart';
import '../domain/entities/doc_requirement.dart';
import '../domain/entities/fee_type.dart';
import '../domain/entities/job_offer.dart';
import '../domain/entities/service_provider.dart';
import '../domain/entities/timeline_step.dart';
import '../domain/entities/week_day.dart';

/// Seed data mirrored 1:1 from the Cerca App.dc.html prototype
/// (claude.ai/design project c9b3052a-5884-4c72-bbe1-c4a55a0943c9).
///
/// MONEY IS IN SOLES (S/). This file used to carry the prototype's
/// Chilean-peso figures ($15.000, laborCost 780000…), which survived the
/// move to the Peru market: the same team would render as
/// "S/ 1,265,000.00" from here while the backend served "S/ 5,110.00"
/// from migration `0007_peru_currency_seed_data.sql`. Whenever these
/// values duplicate something the backend owns, they must agree with it.
class CercaSeedData {
  CercaSeedData._();

  static const List<Category> categories = [
    Category(id: 'gasfiteria', label: 'Gasfitería', mono: 'GA'),
    Category(id: 'electricidad', label: 'Electricidad', mono: 'EL'),
    Category(id: 'carpinteria', label: 'Carpintería', mono: 'CA'),
    Category(id: 'pintura', label: 'Pintura', mono: 'PI'),
    Category(id: 'cerrajeria', label: 'Cerrajería', mono: 'CE'),
    Category(id: 'electrodomesticos', label: 'Electrodom.', mono: 'ED'),
    Category(id: 'jardineria', label: 'Jardinería', mono: 'JA'),
    Category(id: 'climatizacion', label: 'Climatiz.', mono: 'CL'),
  ];

  static const List<Category> projectCategories = [
    Category(id: 'piscinas', label: 'Piscinas', mono: 'PI'),
    Category(id: 'pozos', label: 'Pozos y conexiones', mono: 'PO'),
    Category(id: 'tarrajeo', label: 'Tarrajeo', mono: 'TA'),
    Category(id: 'construccion', label: 'Construcción', mono: 'CO'),
  ];

  // priceLabel mirrors `technician_profiles.price_label` after migration
  // 0007 (S/ 60 / 70 / 80 / 50).
  static const List<Technician> technicians = [
    Technician(
      id: 1, name: 'Marcelo Reyes', mono: 'MR', oficio: 'Gasfitero',
      rating: 4.9, reviews: 132, distance: '0.6 km', priceLabel: 'Desde S/ 60',
      pinTop: 0.30, pinLeft: 0.60,
    ),
    Technician(
      id: 2, name: 'Ana Fuentes', mono: 'AF', oficio: 'Electricista',
      rating: 4.8, reviews: 97, distance: '1.1 km', priceLabel: 'Desde S/ 70',
      pinTop: 0.55, pinLeft: 0.25,
    ),
    Technician(
      id: 3, name: 'Jorge Salinas', mono: 'JS', oficio: 'Carpintero',
      rating: 4.7, reviews: 64, distance: '1.4 km', priceLabel: 'Desde S/ 80',
      pinTop: 0.20, pinLeft: 0.20,
    ),
    Technician(
      id: 4, name: 'Patricia Vega', mono: 'PV', oficio: 'Cerrajera',
      rating: 4.9, reviews: 210, distance: '2.0 km', priceLabel: 'Desde S/ 50',
      pinTop: 0.65, pinLeft: 0.75,
    ),
  ];

  // laborCost/materialsCost/mobilityCost mirror `tech_teams` after
  // migration 0007, and priceLabel is their sum (3.150 + 1.700 + 260).
  static const List<TechTeam> teams = [
    TechTeam(
      id: 1, name: 'Equipo AquaBuild', mono: 'AB', oficio: 'Piscinas y obras de agua',
      rating: 4.9, reviews: 41, distance: '3.2 km', priceLabel: 'Desde S/ 5,110',
      pinTop: 0.35, pinLeft: 0.58,
      crew: 5, projects: 118, laborCost: 3150, materialsCost: 1700, mobilityCost: 260,
    ),
    TechTeam(
      id: 2, name: 'Equipo Terra Sur', mono: 'TS', oficio: 'Pozos y conexiones',
      rating: 4.8, reviews: 29, distance: '5.8 km', priceLabel: 'Desde S/ 2,320',
      pinTop: 0.22, pinLeft: 0.28,
      crew: 4, projects: 76, laborCost: 1360, materialsCost: 600, mobilityCost: 360,
    ),
    TechTeam(
      id: 3, name: 'Equipo Muro Firme', mono: 'MF', oficio: 'Tarrajeo y construcción',
      rating: 4.7, reviews: 53, distance: '4.1 km', priceLabel: 'Desde S/ 1,700',
      pinTop: 0.62, pinLeft: 0.70,
      crew: 6, projects: 94, laborCost: 1040, materialsCost: 440, mobilityCost: 220,
    ),
  ];

  static const List<JobOffer> offers = [
    JobOffer(id: 1, name: 'Marcelo Reyes', mono: 'MR', oficio: 'Gasfitero', rating: 4.9, price: 130, eta: 'Hoy, 16:00', verified: true),
    JobOffer(id: 2, name: 'Felipe Correa', mono: 'FC', oficio: 'Gasfitero', rating: 4.6, price: 110, eta: 'Mañana, 09:00', verified: true),
    JobOffer(id: 3, name: 'Ana Fuentes', mono: 'AF', oficio: 'Técnica multioficio', rating: 4.8, price: 140, eta: 'Hoy, 18:30', verified: true),
    JobOffer(id: 4, name: 'Diego Muñoz', mono: 'DM', oficio: 'Gasfitero', rating: 4.5, price: 95, eta: 'Mañana, 14:00', verified: false),
  ];

  static const List<DocRequirement> docRequirements = [
    DocRequirement(key: 'cedula', label: 'Cédula de identidad', mono: 'CI'),
    DocRequirement(key: 'antecedentes', label: 'Certificado de antecedentes', mono: 'CA'),
    DocRequirement(key: 'especialidad', label: 'Certificado de especialidad', mono: 'CE'),
    DocRequirement(key: 'seguro', label: 'Seguro de responsabilidad (opcional)', mono: 'SR', mandatory: false),
  ];

  /// The documents that actually gate verification. The backend owns this
  /// list (`MANDATORY_DOCUMENT_KEYS`); `seguro` is optional and must never
  /// be counted toward progress, or a technician with all three required
  /// documents still reads "3 de 4".
  static List<DocRequirement> get mandatoryDocRequirements =>
      docRequirements.where((d) => d.mandatory).toList(growable: false);

  static const List<TimelineStepDef> timelineSteps = [
    TimelineStepDef(step: 0, label: 'Confirmado'),
    TimelineStepDef(step: 1, label: 'En camino'),
    TimelineStepDef(step: 2, label: 'En el trabajo'),
    TimelineStepDef(step: 3, label: 'Finalizado'),
  ];

  /// `amount` is only a fallback for when the job has not loaded yet: the
  /// charged fee is whatever the backend put in `job.fee_amount`
  /// (see `AppFeeScreen`). Keep it in sync with
  /// `fee_amount_for` in `backend/src/features/job/domain/job_request.rs`.
  static const Map<FeeType, FeeConfig> feeConfig = {
    FeeType.direct: FeeConfig(
      title: 'Contacto directo gratuito',
      amount: 0,
      desc: 'Contactar directamente con un técnico es gratis. El trabajo se acuerda y se paga directamente al profesional.',
    ),
    FeeType.bidding: FeeConfig(
      title: 'Tarifa de licitación',
      amount: 4,
      desc: 'Cerca cobra una tarifa por gestionar la licitación entre varios técnicos verificados. El trabajo se paga directamente al técnico elegido.',
    ),
    FeeType.project: FeeConfig(
      title: 'Solicitud de proyecto gratuita',
      amount: 0,
      desc: 'Solicitar una cotización de proyecto es gratis. La obra y la movilización se pagan directamente al equipo.',
    ),
  };

  static const List<WeekDay> weekDays = [
    WeekDay(key: 'lun', label: 'Lun'),
    WeekDay(key: 'mar', label: 'Mar'),
    WeekDay(key: 'mie', label: 'Mié'),
    WeekDay(key: 'jue', label: 'Jue'),
    WeekDay(key: 'vie', label: 'Vie'),
    WeekDay(key: 'sab', label: 'Sáb'),
    WeekDay(key: 'dom', label: 'Dom'),
  ];

  static const List<ClientAddress> clientAddresses = [
    ClientAddress(label: 'Casa', detail: 'Av. Providencia 1234, depto 502'),
    ClientAddress(label: 'Oficina', detail: 'Av. Apoquindo 4500, piso 8'),
  ];

  static const List<ClientPaymentMethod> clientPaymentMethods = [
    ClientPaymentMethod(label: 'Tarjeta terminada en 4231', detail: 'Visa · vence 08/28'),
    ClientPaymentMethod(label: 'Efectivo', detail: 'Pago directo al técnico'),
  ];

  static const List<ClientHistoryEntry> clientHistory = [
    ClientHistoryEntry(category: 'Fuga de agua', tech: 'Marcelo Reyes', date: '2 jul', status: ClientHistoryStatus.completed, price: 'S/ 130.00'),
    ClientHistoryEntry(category: 'Instalación eléctrica', tech: 'Ana Fuentes', date: '18 jun', status: ClientHistoryStatus.completed, price: 'S/ 110.00'),
    ClientHistoryEntry(category: 'Cerradura', tech: 'Patricia Vega', date: '30 may', status: ClientHistoryStatus.cancelled, price: '—'),
  ];
}
