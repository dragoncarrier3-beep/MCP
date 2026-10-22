// Typed domain models. All demo values are fictional and in AUD unless stated.

enum EntityType { smsf, company, individual }

extension EntityTypeX on EntityType {
  String get label => switch (this) { EntityType.smsf => 'SMSF', EntityType.company => 'Company', EntityType.individual => 'Individual' };
}

class Client {
  final String id, firstName, lastName, clientType, adviserName;
  const Client({required this.id, required this.firstName, required this.lastName, required this.clientType, required this.adviserName});
  String get initials => '${firstName[0]}${lastName[0]}';
  String get fullName => '$firstName $lastName';
}

class Security {
  final String code, name, sector, exchange;
  final double price, prevClose, open, high, low, marketCapB, yieldPct;
  final int volume;
  const Security({
    required this.code,
    required this.name,
    required this.sector,
    this.exchange = 'ASX',
    required this.price,
    required this.prevClose,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.marketCapB,
    required this.yieldPct,
  });
  double get change => price - prevClose;
  double get changePct => prevClose == 0 ? 0 : change / prevClose * 100;
}

/// Delayed quote snapshot with explicit as-at time.
class Quote {
  final Security security;
  final DateTime asAt;
  final int delayMinutes;
  const Quote(this.security, this.asAt, {this.delayMinutes = 20});
}

class EquityHolding {
  final String entityId, code;
  final int units;
  final double avgCost;
  const EquityHolding({required this.entityId, required this.code, required this.units, required this.avgCost});
  double get costBase => units * avgCost;
}

class StructuredHolding {
  final String entityId, name, type;
  final double invested, currentValue;
  final DateTime maturity;
  const StructuredHolding({required this.entityId, required this.name, required this.type, required this.invested, required this.currentValue, required this.maturity});
  double get pnl => currentValue - invested;
}

class CashAccount {
  final String entityId, name;
  final double balance;
  final double? ratePct;
  final bool availableToTrade;
  const CashAccount({required this.entityId, required this.name, required this.balance, this.ratePct, this.availableToTrade = false});
}

class Entity {
  final String id, name, maskedHin;
  final EntityType type;
  const Entity({required this.id, required this.name, required this.type, required this.maskedHin});
}

/// Valued holding: holding joined with its delayed price.
class Position {
  final EquityHolding holding;
  final Security security;
  const Position(this.holding, this.security);
  double get value => holding.units * security.price;
  double get dayChange => holding.units * security.change;
  double get pnl => value - holding.costBase;
  double get pnlPct => holding.costBase == 0 ? 0 : pnl / holding.costBase * 100;
}

class EntitySummary {
  final Entity entity;
  final List<Position> positions;
  final List<StructuredHolding> structured;
  final List<CashAccount> cash;
  const EntitySummary(this.entity, this.positions, this.structured, this.cash);
  double get equities => positions.fold(0, (a, p) => a + p.value);
  double get structuredValue => structured.fold(0, (a, s) => a + s.currentValue);
  double get cashValue => cash.fold(0, (a, c) => a + c.balance);
  double get total => equities + structuredValue + cashValue;
  double get dayChange => positions.fold(0, (a, p) => a + p.dayChange);
  /// Cost base of invested assets (equities + structured). Cash has no P&L.
  double get costBase => positions.fold<double>(0, (a, p) => a + p.holding.costBase) + structured.fold<double>(0, (a, s) => a + s.invested);
  double get unrealised => positions.fold<double>(0, (a, p) => a + p.pnl) + structured.fold<double>(0, (a, s) => a + s.pnl);
}

class Allocation {
  final double equities, structured, cash;
  const Allocation(this.equities, this.structured, this.cash);
  double get total => equities + structured + cash;
  double pct(double v) => total == 0 ? 0 : v / total * 100;
}

class PortfolioSummary {
  final List<EntitySummary> entities;
  final DateTime asAt;
  const PortfolioSummary(this.entities, this.asAt);
  double get total => entities.fold(0, (a, e) => a + e.total);
  double get dayChange => entities.fold(0, (a, e) => a + e.dayChange);
  double get dayChangePct => (total - dayChange) == 0 ? 0 : dayChange / (total - dayChange) * 100;
  double get unrealised => entities.fold(0, (a, e) => a + e.unrealised);
  double get costBase => entities.fold(0, (a, e) => a + e.costBase);
  double get unrealisedPct => costBase == 0 ? 0 : unrealised / costBase * 100;
  Allocation get allocation => Allocation(
        entities.fold(0, (a, e) => a + e.equities),
        entities.fold(0, (a, e) => a + e.structuredValue),
        entities.fold(0, (a, e) => a + e.cashValue),
      );
  int get accountCount => entities.fold(0, (a, e) => a + 1 + e.cash.length + e.structured.length);
  List<Position> get allPositions => [for (final e in entities) ...e.positions];
  EntitySummary byId(String id) => entities.firstWhere((e) => e.entity.id == id);
}

class PricePoint {
  final DateTime t;
  final double v;
  const PricePoint(this.t, this.v);
}

class PriceHistory {
  final String code, range;
  final List<PricePoint> points;
  final double? previousClose;
  const PriceHistory(this.code, this.range, this.points, {this.previousClose});
  double get first => points.first.v;
  double get last => points.last.v;
  double get change => last - first;
  double get changePct => change / first * 100;
}

class Announcement {
  final String id, code, title, body, kaiSummary;
  final DateTime at;
  final bool priceSensitive;
  final int pages;
  const Announcement({required this.id, required this.code, required this.title, required this.body, required this.at, this.priceSensitive = false, this.kaiSummary = '', this.pages = 4});
}

/// A security the client watches and/or has alerts on.
/// `watched == false` means alerts only (for a held security not on the watchlist).
class WatchlistItem {
  final String code;
  final bool alerts, watched;
  const WatchlistItem(this.code, {this.alerts = false, this.watched = true});
  WatchlistItem copyWith({bool? alerts, bool? watched}) => WatchlistItem(code, alerts: alerts ?? this.alerts, watched: watched ?? this.watched);
  Map<String, dynamic> toJson() => {'code': code, 'alerts': alerts, 'watched': watched};
  factory WatchlistItem.fromJson(Map<String, dynamic> j) => WatchlistItem(j['code'] as String, alerts: j['alerts'] as bool? ?? false, watched: j['watched'] as bool? ?? true);
}

enum ContentType { morningCall, bullsBears, article, thematic, companyInsight, webinar, video }

extension ContentTypeX on ContentType {
  String get label => switch (this) {
        ContentType.morningCall => 'Morning Call',
        ContentType.bullsBears => 'Bulls vs. Bears',
        ContentType.article => 'Article',
        ContentType.thematic => 'Thematic',
        ContentType.companyInsight => 'Company Insight',
        ContentType.webinar => 'Webinar',
        ContentType.video => 'Video',
      };
}

class ResearchContent {
  final String id, title, summary, author;
  final List<String> body;
  final ContentType type;
  final DateTime published;
  final int minutes;
  final List<String> related;
  final String? audioUrl, videoUrl;
  final int hue;
  const ResearchContent({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    required this.body,
    required this.type,
    required this.published,
    required this.minutes,
    this.related = const [],
    this.audioUrl,
    this.videoUrl,
    this.hue = 0,
  });
}

enum RecStatus { pending, accepted, declined }

enum RecCategory { auStocks, globalStocks, structured, highConviction }

extension RecCategoryX on RecCategory {
  String get label => switch (this) {
        RecCategory.auStocks => 'AU Stocks',
        RecCategory.globalStocks => 'Global Stocks',
        RecCategory.structured => 'Structured Investments',
        RecCategory.highConviction => 'High Conviction',
      };
}

class Recommendation {
  final String id, code, name, action, entityId, commentary, currency;
  final List<String> whyWeLikeIt;
  final RecCategory category;
  final double entryLow, entryHigh, target, stop;
  final DateTime issued;
  final RecStatus status;
  final DateTime? actionedAt;
  const Recommendation({
    required this.id,
    required this.code,
    required this.name,
    required this.action,
    required this.entityId,
    required this.commentary,
    required this.whyWeLikeIt,
    required this.category,
    required this.entryLow,
    required this.entryHigh,
    required this.target,
    required this.stop,
    required this.issued,
    this.currency = 'A\$',
    this.status = RecStatus.pending,
    this.actionedAt,
  });
  Recommendation withStatus(RecStatus s, DateTime at) => Recommendation(
      id: id, code: code, name: name, action: action, entityId: entityId, commentary: commentary, whyWeLikeIt: whyWeLikeIt,
      category: category, entryLow: entryLow, entryHigh: entryHigh, target: target, stop: stop, issued: issued, currency: currency,
      status: s, actionedAt: at);
}

enum OfferStatus { open, interestRegistered, closed }

class StructuredOffer {
  final String id, type, title, description, tenor;
  final List<String> features;
  final double minInvestment;
  final DateTime closes;
  final OfferStatus status;
  const StructuredOffer({required this.id, required this.type, required this.title, required this.description, required this.tenor, required this.features, required this.minInvestment, required this.closes, this.status = OfferStatus.open});
  StructuredOffer withStatus(OfferStatus s) => StructuredOffer(id: id, type: type, title: title, description: description, tenor: tenor, features: features, minInvestment: minInvestment, closes: closes, status: s);
}

enum ThreadKind { assistantPreview, broker }

class MessageThread {
  final String id, displayName, org, role, initials;
  final ThreadKind kind;
  const MessageThread({required this.id, required this.displayName, required this.org, required this.role, required this.initials, required this.kind});
}

enum Sender { client, staff, system }

enum Delivery { sending, sent, delivered, read, failed }

/// Message body is a typed payload so new message types can be added later.
sealed class MessageBody {
  const MessageBody();
}

class TextBody extends MessageBody {
  final String text;
  const TextBody(this.text);
}

class RecCardBody extends MessageBody {
  final String recId;
  final String note;
  const RecCardBody(this.recId, this.note);
}

class ChatMessage {
  final String id, threadId;
  final Sender sender;
  final MessageBody body;
  final DateTime at;
  final Delivery delivery;
  final bool simulated;
  const ChatMessage({required this.id, required this.threadId, required this.sender, required this.body, required this.at, this.delivery = Delivery.read, this.simulated = false});
  ChatMessage withDelivery(Delivery d) => ChatMessage(id: id, threadId: threadId, sender: sender, body: body, at: at, delivery: d, simulated: simulated);

  Map<String, dynamic> toJson() => {
        'id': id,
        'threadId': threadId,
        'sender': sender.name,
        'text': body is TextBody ? (body as TextBody).text : '',
        'at': at.toIso8601String(),
        'delivery': delivery.name,
        'simulated': simulated,
      };
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        threadId: j['threadId'],
        sender: Sender.values.byName(j['sender']),
        body: TextBody(j['text']),
        at: DateTime.parse(j['at']),
        delivery: Delivery.values.byName(j['delivery']),
        simulated: j['simulated'] ?? false,
      );
}

enum AlertKind { priceMove, announcement, recommendation, message }

class AppNotification {
  final String id, title, body, route;
  final AlertKind kind;
  final DateTime at;
  final bool read;
  final bool simulated;
  const AppNotification({required this.id, required this.title, required this.body, required this.route, required this.kind, required this.at, this.read = false, this.simulated = false});
  AppNotification markRead() => AppNotification(id: id, title: title, body: body, route: route, kind: kind, at: at, read: true, simulated: simulated);
}

class AlertPreference {
  final bool announcements, priceMoves;
  const AlertPreference({this.announcements = true, this.priceMoves = true});
  AlertPreference copyWith({bool? announcements, bool? priceMoves}) =>
      AlertPreference(announcements: announcements ?? this.announcements, priceMoves: priceMoves ?? this.priceMoves);
}

class AuditEvent {
  final String id, action, subject;
  final DateTime at;
  final bool simulated;
  const AuditEvent({required this.id, required this.action, required this.subject, required this.at, this.simulated = true});
}

class Trade {
  final String side, code, entityId;
  final int qty;
  final double price;
  final DateTime date;
  const Trade(this.side, this.qty, this.code, this.price, this.entityId, this.date);
}

class MarketIndex {
  final String name, unit;
  final double value, changePct;
  const MarketIndex(this.name, this.value, this.changePct, {this.unit = ''});
}
