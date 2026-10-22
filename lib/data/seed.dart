// FICTIONAL DEMO DATA. Not real client data. Not live or current market prices.
// Fixed demo timeline: market data as at Tue 20 Oct 2026, 4:20 pm AEDT (20 min delayed).
import 'models.dart';

class Seed {
  /// 4:20 pm AEDT on 20 Oct 2026 == 05:20 UTC.
  static final asAt = DateTime.utc(2026, 10, 20, 5, 20);
  static DateTime aedt(int m, int d, int h, [int min = 0]) => DateTime.utc(2026, m, d, h, min).subtract(const Duration(hours: 11));

  static const client = Client(id: 'demo-001', firstName: 'Alex', lastName: 'Morgan', clientType: 'MPC private wealth client', adviserName: 'Your Adviser');

  static const entities = [
    Entity(id: 'smsf', name: 'Sample Family Super Fund', type: EntityType.smsf, maskedHin: '••••4821'),
    Entity(id: 'company', name: 'Sample Holdings Pty Ltd', type: EntityType.company, maskedHin: '••••7310'),
    Entity(id: 'individual', name: 'Sample Client', type: EntityType.individual, maskedHin: '••••2259'),
  ];

  static Security _s(String code, String name, String sector, double price, double prev, double capB, double yld, int vol, {String ex = 'ASX'}) {
    final spread = (price - prev).abs();
    final o = double.parse((prev + (price - prev) * 0.25).toStringAsFixed(2));
    final hi = double.parse(((price > prev ? price : prev) + spread * 0.18 + price * 0.004).toStringAsFixed(2));
    final lo = double.parse(((price < prev ? price : prev) - spread * 0.15 - price * 0.003).toStringAsFixed(2));
    return Security(code: code, name: name, sector: sector, exchange: ex, price: price, prevClose: prev, open: o, high: hi, low: lo, volume: vol, marketCapB: capB, yieldPct: yld);
  }

  static final securities = <String, Security>{
    for (final s in [
      _s('BHP', 'BHP Group Limited', 'Materials', 44.20, 47.63, 224.1, 4.9, 21840500),
      _s('CBA', 'Commonwealth Bank of Australia', 'Financials', 158.40, 157.12, 265.0, 3.0, 2604100),
      _s('CSL', 'CSL Limited', 'Health Care', 238.10, 236.45, 115.3, 1.7, 1120300),
      _s('WES', 'Wesfarmers Limited', 'Consumer Discretionary', 78.65, 78.98, 89.2, 2.6, 1873400),
      _s('MQG', 'Macquarie Group Limited', 'Financials', 212.30, 209.85, 81.1, 3.1, 902800),
      _s('NAB', 'National Australia Bank Limited', 'Financials', 38.95, 38.71, 119.6, 4.4, 5430900),
      _s('WDS', 'Woodside Energy Group Ltd', 'Energy', 24.10, 24.42, 45.8, 6.8, 7215600),
      _s('RIO', 'Rio Tinto Limited', 'Materials', 121.80, 125.36, 197.4, 5.2, 3108200),
      _s('FMG', 'Fortescue Ltd', 'Materials', 19.35, 19.88, 59.6, 7.1, 9480700),
      _s('TLS', 'Telstra Group Limited', 'Communication Services', 4.82, 4.79, 55.4, 3.9, 30120400),
      _s('XRO', 'Xero Limited', 'Information Technology', 168.50, 164.20, 25.7, 0.0, 811200),
      _s('ANZ', 'ANZ Group Holdings Limited', 'Financials', 30.20, 30.05, 90.2, 5.5, 6310500),
      _s('WOW', 'Woolworths Group Limited', 'Consumer Staples', 33.40, 33.62, 40.8, 2.8, 2950100),
      _s('COL', 'Coles Group Limited', 'Consumer Staples', 19.80, 19.66, 26.5, 3.4, 3402800),
      _s('WTC', 'WiseTech Global Limited', 'Information Technology', 82.40, 79.10, 27.5, 0.2, 1204400),
      _s('PLS', 'Pilbara Minerals Limited', 'Materials', 3.42, 3.21, 10.3, 0.0, 41208300),
      _s('MIN', 'Mineral Resources Limited', 'Materials', 38.75, 36.90, 7.6, 0.0, 3950700),
      _s('LYC', 'Lynas Rare Earths Limited', 'Materials', 9.84, 9.31, 9.2, 0.0, 12409600),
      _s('NST', 'Northern Star Resources Ltd', 'Materials', 18.20, 18.66, 20.9, 2.4, 6702100),
      _s('S32', 'South32 Limited', 'Materials', 3.36, 3.47, 15.2, 2.9, 18904500),
      _s('REA', 'REA Group Ltd', 'Communication Services', 248.60, 245.30, 32.8, 0.9, 300500),
      _s('TCL', 'Transurban Group', 'Industrials', 13.05, 13.12, 40.4, 4.8, 4980200),
      _s('QBE', 'QBE Insurance Group Limited', 'Financials', 21.40, 21.22, 32.1, 3.8, 3802600),
      _s('ALL', 'Aristocrat Leisure Limited', 'Consumer Discretionary', 66.10, 64.95, 41.6, 1.2, 1120900),
    ])
      s.code: s,
  };

  static const equities = [
    EquityHolding(entityId: 'smsf', code: 'BHP', units: 6850, avgCost: 38.50),
    EquityHolding(entityId: 'smsf', code: 'CBA', units: 1420, avgCost: 112.30),
    EquityHolding(entityId: 'smsf', code: 'CSL', units: 1012, avgCost: 265.00),
    EquityHolding(entityId: 'smsf', code: 'WES', units: 3100, avgCost: 61.20),
    EquityHolding(entityId: 'smsf', code: 'MQG', units: 820, avgCost: 178.90),
    EquityHolding(entityId: 'smsf', code: 'NAB', units: 4200, avgCost: 31.40),
    EquityHolding(entityId: 'company', code: 'WDS', units: 5200, avgCost: 27.85),
    EquityHolding(entityId: 'company', code: 'RIO', units: 900, avgCost: 108.40),
    EquityHolding(entityId: 'company', code: 'FMG', units: 4000, avgCost: 17.10),
    EquityHolding(entityId: 'company', code: 'TLS', units: 20000, avgCost: 4.05),
    EquityHolding(entityId: 'individual', code: 'XRO', units: 300, avgCost: 132.60),
    EquityHolding(entityId: 'individual', code: 'ANZ', units: 2500, avgCost: 26.90),
    EquityHolding(entityId: 'individual', code: 'WOW', units: 1200, avgCost: 35.10),
    EquityHolding(entityId: 'individual', code: 'COL', units: 2000, avgCost: 17.45),
  ];

  static final structured = [
    StructuredHolding(entityId: 'smsf', name: 'ASX 200 Growth Note – Series 9', type: 'Growth Note', invested: 250000, currentValue: 268400, maturity: DateTime.utc(2028, 3, 15)),
    StructuredHolding(entityId: 'company', name: 'Big Four Banks Fixed Coupon Note', type: 'Fixed Coupon Note', invested: 200000, currentValue: 204600, maturity: DateTime.utc(2027, 6, 30)),
    StructuredHolding(entityId: 'individual', name: 'BHP Smart Entry Note', type: 'Smart Entry Note', invested: 100000, currentValue: 96800, maturity: DateTime.utc(2027, 2, 26)),
  ];

  static const cash = [
    CashAccount(entityId: 'smsf', name: 'SMSF Cash Management Account', balance: 158450.35, ratePct: 4.10, availableToTrade: true),
    CashAccount(entityId: 'smsf', name: 'SMSF Term Deposit (90 day)', balance: 24000.00, ratePct: 4.55),
    CashAccount(entityId: 'company', name: 'Company Cash Management Account', balance: 98210.60, ratePct: 4.05, availableToTrade: true),
    CashAccount(entityId: 'individual', name: 'Individual Trading Account', balance: 35147.45, ratePct: 3.90, availableToTrade: true),
  ];

  static const watchlist = ['BHP', 'CBA', 'CSL', 'FMG', 'WOW', 'TLS', 'XRO', 'ANZ'];

  static final trades = [
    Trade('BUY', 300, 'XRO', 161.20, 'individual', aedt(10, 14, 11, 4)),
    Trade('SELL', 1500, 'WDS', 25.90, 'company', aedt(10, 8, 14, 31)),
    Trade('BUY', 820, 'MQG', 201.75, 'smsf', aedt(9, 29, 10, 22)),
    Trade('BUY', 4000, 'FMG', 18.42, 'company', aedt(9, 18, 15, 12)),
    Trade('SELL', 600, 'CSL', 251.30, 'smsf', aedt(9, 3, 12, 45)),
    Trade('BUY', 2000, 'COL', 18.95, 'individual', aedt(8, 27, 13, 18)),
  ];

  static const indices = [
    MarketIndex('ASX 200', 8412.60, -0.84),
    MarketIndex('S&P 500', 6705.30, 0.41),
    MarketIndex('Gold', 4120.50, 0.62, unit: 'US\$/oz'),
    MarketIndex('Iron Ore', 104.20, -1.35, unit: 'US\$/t'),
  ];

  static final announcements = [
    Announcement(
      id: 'ann-rio-1',
      code: 'RIO',
      title: 'Third quarter operations review and revised shipments guidance',
      priceSensitive: true,
      at: aedt(10, 20, 9, 32),
      pages: 18,
      kaiSummary: 'Rio Tinto shipped slightly less iron ore than expected this quarter because of wet weather in the Pilbara. It has trimmed the top end of its full-year shipments range. Copper output rose. In plain terms: a softer iron ore quarter, partly offset by copper. (Fictional K.ai preview summary. Not financial advice.)',
      body: 'Rio Tinto Limited (fictional demo announcement) reports third quarter Pilbara iron ore shipments of 79.1 Mt, down 3% on the prior corresponding period, reflecting weather impacts in September. Full-year shipments guidance is revised to 323–330 Mt (previously 323–338 Mt). Copper production increased 11% on the prior quarter as underground ramp-up continued. Unit cost guidance is unchanged.',
    ),
    Announcement(id: 'ann-rio-2', code: 'RIO', title: 'Notice of dividend reinvestment plan pricing', at: aedt(10, 9, 8, 45), pages: 2, body: 'Fictional demo notice regarding dividend reinvestment plan pricing for the interim dividend.'),
    Announcement(id: 'ann-rio-3', code: 'RIO', title: 'Change of director\'s interest notice', at: aedt(10, 2, 17, 10), pages: 3, body: 'Fictional Appendix 3Y change of director\'s interest notice.'),
    Announcement(
      id: 'ann-bhp-1',
      code: 'BHP',
      title: 'Operational review for the quarter ended 30 September 2026',
      priceSensitive: true,
      at: aedt(10, 20, 9, 30),
      pages: 22,
      kaiSummary: 'BHP produced less iron ore and coal than the market expected and flagged higher costs at one of its copper operations. Shares fell sharply today. (Fictional K.ai preview summary. Not financial advice.)',
      body: 'BHP Group Limited (fictional demo announcement) reports quarterly iron ore production of 61.4 Mt and a revision to Queensland coal guidance following extended maintenance. Copper unit cost guidance has been increased at one operation.',
    ),
    Announcement(id: 'ann-bhp-2', code: 'BHP', title: 'Annual General Meeting – Chair and CEO addresses', at: aedt(10, 15, 10, 0), pages: 9, body: 'Fictional AGM addresses.'),
    Announcement(id: 'ann-csl-1', code: 'CSL', title: 'Investor briefing – CSL Behring margin update', priceSensitive: true, at: aedt(10, 13, 9, 45), pages: 26, body: 'Fictional investor briefing presentation covering plasma collection costs and gross margin recovery.'),
    Announcement(id: 'ann-cba-1', code: 'CBA', title: 'Q1 FY27 trading update', priceSensitive: true, at: aedt(10, 16, 9, 30), pages: 12, body: 'Fictional quarterly trading update.'),
  ];

  static const _audio = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3';
  static const _video = 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  static final research = [
    ResearchContent(
      id: 'mc-1020',
      type: ContentType.morningCall,
      title: 'Morning Call: Miners weigh as iron ore slips; banks steady',
      summary: 'Daily podcast & report',
      author: 'MPC Markets Research',
      published: aedt(10, 20, 7, 30),
      minutes: 12,
      audioUrl: _audio,
      related: ['BHP', 'RIO', 'FMG', 'CBA'],
      hue: 0,
      body: [
        'Good morning. US equities closed modestly higher overnight, with the S&P 500 up 0.4% as bond yields eased. Futures point to a softer open locally, led by the materials sector.',
        'Iron ore fell 1.4% to US\$104/t on renewed concerns about Chinese steel demand. Expect pressure on BHP, RIO and FMG ahead of quarterly production updates this morning.',
        'Banks look steady after CBA\'s trading update last week. We remain comfortable with our relative preference for NAB on valuation.',
        'Stocks to watch: BHP and RIO quarterly reports, CSL following last week\'s investor briefing, and XRO on continued US subscriber momentum.',
      ],
    ),
    ResearchContent(
      id: 'bvb-42',
      type: ContentType.bullsBears,
      title: 'Bulls vs. Bears: Is the bank rally running out of road?',
      summary: 'Weekly podcast & report',
      author: 'MPC Markets Research',
      published: aedt(10, 17, 8, 0),
      minutes: 28,
      audioUrl: _audio,
      related: ['CBA', 'NAB', 'ANZ'],
      hue: 1,
      body: [
        'This week our bull and bear go head-to-head on the major banks after a strong run in 2026.',
        'The bull case: credit growth is holding up, arrears remain contained and capital positions support ongoing dividends.',
        'The bear case: valuations are stretched relative to history, and margin competition in mortgages is intensifying.',
        'Our verdict: hold existing positions, but be selective on new money.',
      ],
    ),
    ResearchContent(
      id: 'th-critical',
      type: ContentType.thematic,
      title: 'When did critical minerals stop being critical?',
      summary: 'Prices for lithium and rare earths have swung wildly. We revisit the long-term thesis.',
      author: 'MPC Markets Research',
      published: aedt(10, 19, 9, 0),
      minutes: 8,
      related: ['LYC', 'PLS', 'MIN'],
      hue: 2,
      body: [
        'Two years ago, critical minerals were the market\'s favourite theme. Then oversupply arrived, prices collapsed, and many investors moved on.',
        'We think the long-term demand story remains intact: electrification, grid storage and defence supply chains still require secure, diversified sources of lithium, rare earths and graphite.',
        'What has changed is the cost curve. Only the lowest-cost, best-funded producers are likely to generate attractive returns through the cycle.',
        'Our preferred exposure is through producers with strong balance sheets and offtake agreements, rather than early-stage explorers.',
      ],
    ),
    ResearchContent(id: 'ci-csl', type: ContentType.companyInsight, title: 'CSL: Behring margin recovery on track', summary: 'Plasma collection costs continue to normalise.', author: 'Healthcare Analyst, MPC Markets', published: aedt(10, 14, 10, 0), minutes: 6, related: ['CSL'], hue: 3, body: [
      'CSL\'s investor briefing reaffirmed the path back to pre-pandemic Behring gross margins.',
      'Collection costs per litre continue to decline, and new fractionation technology should support yield improvement over the next three years.',
      'We see the recent share price weakness as an opportunity for long-term investors.',
    ]),
    ResearchContent(id: 'ar-banks', type: ContentType.article, title: 'Bank margins: the quiet squeeze', summary: 'Mortgage competition is heating up again.', author: 'MPC Markets Research', published: aedt(10, 15, 12, 0), minutes: 5, related: ['CBA', 'NAB', 'ANZ'], hue: 4, body: [
      'Net interest margins have stabilised, but competition for new mortgages is intensifying as refinancing activity picks up.',
      'We expect margins to drift modestly lower over FY27.',
    ]),
    ResearchContent(id: 'wb-q4', type: ContentType.webinar, title: 'Webinar replay: Positioning portfolios for 2027', summary: 'Our strategists on rates, earnings and asset allocation.', author: 'MPC Markets Strategy', published: aedt(10, 12, 18, 0), minutes: 42, videoUrl: _video, hue: 5, body: [
      'In this webinar replay, our strategy team discusses the outlook for interest rates, corporate earnings and portfolio construction heading into 2027.',
      'The video below is a demonstration clip for the prototype. It is not the MPC webinar recording.',
    ]),
    ResearchContent(id: 'vd-iron', type: ContentType.video, title: 'Iron ore in three minutes', summary: 'What the latest price fall means for the majors.', author: 'MPC Markets Research', published: aedt(10, 16, 16, 0), minutes: 3, videoUrl: _video, related: ['BHP', 'RIO', 'FMG'], hue: 6, body: [
      'A short explainer on iron ore supply, Chinese steel demand and what it means for BHP, RIO and FMG.',
      'The video below is a demonstration clip for the prototype.',
    ]),
    ResearchContent(id: 'ar-reporting', type: ContentType.article, title: 'AGM season: what to listen for', summary: 'Guidance updates matter more than ever this year.', author: 'MPC Markets Research', published: aedt(10, 10, 9, 0), minutes: 4, hue: 7, body: [
      'AGM season is underway. With many companies holding back formal guidance in August, trading updates at AGMs may move share prices.',
    ]),
    ResearchContent(id: 'th-ai', type: ContentType.thematic, title: 'Data centres and the power bill', summary: 'Who wins from surging electricity demand?', author: 'MPC Markets Research', published: aedt(10, 7, 9, 0), minutes: 7, hue: 8, related: ['WTC', 'TCL'], body: [
      'Data centre growth is driving a step-change in electricity demand forecasts.',
      'We examine the listed beneficiaries across utilities, infrastructure and technology.',
    ]),
    ResearchContent(id: 'ci-xro', type: ContentType.companyInsight, title: 'Xero: US expansion gathering pace', summary: 'Subscriber growth beats expectations.', author: 'Technology Analyst, MPC Markets', published: aedt(10, 6, 11, 0), minutes: 5, hue: 9, related: ['XRO'], body: [
      'Xero\'s US subscriber growth continues to exceed expectations following its payments acquisition.',
    ]),
    ResearchContent(id: 'mc-1019', type: ContentType.morningCall, title: 'Morning Call: Quiet start to reporting week', summary: 'Daily podcast & report', author: 'MPC Markets Research', published: aedt(10, 19, 7, 30), minutes: 11, audioUrl: _audio, hue: 0, body: ['Markets were steady on Friday. This week brings quarterly updates from the major miners.']),
    ResearchContent(id: 'ar-gold', type: ContentType.article, title: 'Gold above US\$4,000: what next?', summary: 'Central bank buying remains the key driver.', author: 'MPC Markets Research', published: aedt(10, 3, 9, 0), minutes: 6, hue: 2, related: ['NST'], body: ['Gold has held above US\$4,000/oz, supported by central bank buying.']),
  ];

  static final recommendations = [
    Recommendation(
      id: 'rec-csl',
      code: 'CSL',
      name: 'CSL Limited',
      action: 'BUY',
      category: RecCategory.auStocks,
      entityId: 'smsf',
      entryLow: 236,
      entryHigh: 240,
      target: 275,
      stop: 218,
      issued: aedt(10, 19, 8, 15),
      commentary: 'CSL has de-rated over the past 18 months as plasma collection costs weighed on Behring margins. Last week\'s investor briefing confirmed that margin recovery is on track, and we see the current price as an attractive entry point for long-term investors. The suggested account already holds CSL, so this would increase an existing position.',
      whyWeLikeIt: ['Behring gross margin recovery is on track', 'Global leader in plasma therapies with high barriers to entry', 'Valuation below its 10-year average', 'Strong balance sheet supports ongoing investment'],
    ),
    Recommendation(
      id: 'rec-googl',
      code: 'GOOGL',
      name: 'Alphabet Inc.',
      action: 'BUY',
      category: RecCategory.globalStocks,
      currency: 'US\$',
      entityId: 'individual',
      entryLow: 238,
      entryHigh: 246,
      target: 290,
      stop: 215,
      issued: aedt(10, 16, 8, 30),
      commentary: 'Cloud growth and disciplined cost control support earnings upgrades. Provides global technology diversification for the individual portfolio.',
      whyWeLikeIt: ['Cloud revenue growth accelerating', 'Search remains highly cash generative', 'Buyback program supports returns'],
    ),
    Recommendation(
      id: 'rec-wtc',
      code: 'WTC',
      name: 'WiseTech Global Limited',
      action: 'ACCUMULATE',
      category: RecCategory.highConviction,
      entityId: 'company',
      entryLow: 78,
      entryHigh: 83,
      target: 98,
      stop: 70,
      issued: aedt(10, 14, 8, 0),
      commentary: 'High conviction idea: logistics software platform with long runway for growth as customers consolidate onto CargoWise.',
      whyWeLikeIt: ['Sticky, mission-critical software', 'Pricing power', 'Long runway in global freight'],
    ),
    Recommendation(id: 'rec-mqg', code: 'MQG', name: 'Macquarie Group Limited', action: 'BUY', category: RecCategory.auStocks, entityId: 'smsf', entryLow: 198, entryHigh: 205, target: 235, stop: 185, issued: aedt(9, 24, 8, 0), status: RecStatus.accepted, actionedAt: aedt(9, 24, 14, 10), commentary: 'Asset management recovery and strong commodities trading result.', whyWeLikeIt: ['Diversified earnings', 'Capital surplus']),
    Recommendation(id: 'rec-fmg', code: 'FMG', name: 'Fortescue Ltd', action: 'SELL', category: RecCategory.auStocks, entityId: 'company', entryLow: 19.5, entryHigh: 20.5, target: 16.0, stop: 22.0, issued: aedt(9, 10, 8, 0), status: RecStatus.declined, actionedAt: aedt(9, 11, 9, 40), commentary: 'Iron ore price risk and elevated green energy capex.', whyWeLikeIt: ['Reduce iron ore concentration']),
    Recommendation(id: 'rec-nab', code: 'NAB', name: 'National Australia Bank Limited', action: 'HOLD', category: RecCategory.auStocks, entityId: 'smsf', entryLow: 37, entryHigh: 39, target: 41, stop: 34, issued: aedt(8, 20, 8, 0), status: RecStatus.accepted, actionedAt: aedt(8, 20, 11, 5), commentary: 'Fair value. Maintain position.', whyWeLikeIt: ['Business banking franchise']),
  ];

  static final offers = [
    StructuredOffer(
      id: 'off-growth',
      type: 'Growth Note',
      title: 'ASX 200 Growth Note – Series 14',
      description: 'Participate in the growth of the S&P/ASX 200 over five years with partial downside protection.',
      tenor: '5 years',
      features: ['120% participation in index growth', '90% capital protection at maturity', 'Quarterly liquidity window'],
      minInvestment: 50000,
      closes: Seed.aedt(11, 6, 17),
    ),
    StructuredOffer(
      id: 'off-smart',
      type: 'Smart Entry Note',
      title: 'Big Miners Smart Entry Note',
      description: 'Earn a monthly coupon while waiting to buy BHP and RIO at a discount to today\'s price.',
      tenor: '12 months',
      features: ['Monthly coupon 9.6% p.a.', 'Entry at 85% of initial price', 'Underlying: BHP, RIO'],
      minInvestment: 50000,
      closes: Seed.aedt(11, 13, 17),
    ),
    StructuredOffer(
      id: 'off-fixed',
      type: 'Fixed Coupon Note',
      title: 'Major Banks Fixed Coupon Note',
      description: 'Quarterly fixed coupons linked to the four major Australian banks.',
      tenor: '2 years',
      features: ['Fixed coupon 8.2% p.a. paid quarterly', 'Autocall from month 6', 'Underlying: CBA, NAB, ANZ, WBC'],
      minInvestment: 100000,
      closes: Seed.aedt(11, 27, 17),
    ),
  ];

  static const threads = [
    MessageThread(id: 'kai', displayName: 'K.ai', org: 'MPC Markets', role: 'Your Mosaic assistant', initials: 'K', kind: ThreadKind.assistantPreview),
    MessageThread(id: 'adviser', displayName: 'Your Adviser', org: 'MPC Markets', role: 'Private Client Adviser', initials: 'YA', kind: ThreadKind.broker),
    MessageThread(id: 'desk', displayName: 'MPC Structured Products Desk', org: 'MPC Markets', role: 'Broker Team', initials: 'SD', kind: ThreadKind.broker),
  ];

  static ChatMessage _m(String id, String th, Sender s, String text, DateTime at) => ChatMessage(id: id, threadId: th, sender: s, body: TextBody(text), at: at);

  static final messages = [
    _m('a1', 'adviser', Sender.staff, 'Hi Alex, welcome to Mosaic mobile. You can message me here any time during business hours.', aedt(10, 12, 9, 2)),
    _m('a2', 'adviser', Sender.client, 'Thanks. Good to have everything in one place.', aedt(10, 12, 9, 15)),
    _m('a3', 'adviser', Sender.staff, 'I\'ve rebalanced the SMSF watchlist after our review. I added FMG so you can keep an eye on iron ore exposure.', aedt(10, 12, 9, 18)),
    _m('a4', 'adviser', Sender.client, 'Great. Can you send me the latest view on CSL?', aedt(10, 14, 16, 40)),
    _m('a5', 'adviser', Sender.staff, 'Sure. The healthcare team published a note today. Short version: margin recovery is on track.', aedt(10, 14, 16, 52)),
    _m('a6', 'adviser', Sender.client, 'Thanks, I\'ll read it tonight.', aedt(10, 14, 17, 1)),
    ChatMessage(id: 'a7', threadId: 'adviser', sender: Sender.staff, body: const RecCardBody('rec-csl', 'I\'ve sent through a CSL recommendation for the super fund. Have a look and let me know your thoughts.'), at: aedt(10, 19, 8, 20)),
    _m('a8', 'adviser', Sender.staff, 'Also, BHP and RIO report quarterly numbers tomorrow morning, so expect some volatility in the miners.', aedt(10, 19, 8, 22)),
    _m('a9', 'adviser', Sender.client, 'Noted. Let\'s speak after the numbers are out.', aedt(10, 19, 12, 5)),
    _m('a10', 'adviser', Sender.staff, 'BHP is down about 7% today after the production update. No action needed right now. Happy to talk it through.', aedt(10, 20, 14, 10)),
    _m('d1', 'desk', Sender.staff, 'Good morning Alex. Three new structured offers are open this month. Details are in the Recs tab.', aedt(10, 15, 9, 0)),
    _m('d2', 'desk', Sender.client, 'Which one suits income best?', aedt(10, 15, 10, 30)),
    _m('d3', 'desk', Sender.staff, 'The Major Banks Fixed Coupon Note pays 8.2% p.a. quarterly. Your adviser can check suitability for each entity.', aedt(10, 15, 10, 41)),
    _m('d4', 'desk', Sender.client, 'Thanks. Please send the PDS.', aedt(10, 15, 10, 50)),
    _m('d5', 'desk', Sender.staff, 'PDS sent to your registered email. Remember the Series 14 Growth Note closes on 6 November.', aedt(10, 16, 9, 12)),
    _m('d6', 'desk', Sender.staff, 'Reminder: the Smart Entry Note closes 13 November.', aedt(10, 20, 11, 0)),
  ];

  /// Two sample alert events (spec) plus two context events.
  static final notifications = [
    AppNotification(id: 'n1', kind: AlertKind.priceMove, title: 'BHP down 7.2% today', body: 'BHP Group fell −7.20% to A\$44.20 vs previous close. 20 min delayed.', route: '/holdings/quote/BHP?back=Alerts', at: aedt(10, 20, 14, 2)),
    AppNotification(id: 'n2', kind: AlertKind.announcement, title: 'RIO: price-sensitive announcement', body: 'Third quarter operations review and revised shipments guidance. K.ai summary available.', route: '/holdings/announcement/ann-rio-1?back=Alerts', at: aedt(10, 20, 9, 33)),
    AppNotification(id: 'n3', kind: AlertKind.recommendation, title: 'New recommendation: CSL BUY', body: 'Your adviser has shared a recommendation for Sample Family Super Fund.', route: '/recs/rec/rec-csl?back=Alerts', at: aedt(10, 19, 8, 20), read: true),
    AppNotification(id: 'n4', kind: AlertKind.message, title: 'Message from Your Adviser', body: 'BHP is down about 7% today after the production update…', route: '/messages/chat/adviser?back=Alerts', at: aedt(10, 20, 14, 10), read: true),
  ];
}
