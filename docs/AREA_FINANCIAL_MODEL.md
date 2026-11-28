# AREA Financial System — Pricing, Unit Economics and Launch Controls

**Working version:** 28 November 2026  
**Status:** Database and application code implemented; Paystack checkout deliberately disabled pending legal classification, merchant approval and test verification.

## 1. Design rules

1. AREA is a social product first. Reading, posting, replying, messaging and ordinary participation must not require a purchase.
2. AC is internal AREA credit. The current reference is **₦1 = 50 AC**. The naira figure is a pricing reference, not a redemption promise.
3. No cash-out, interest, yield, investment claim, automatic renewal or recurring subscription.
4. Show the full naira charge, AC received, bonus AC, processor fee policy and transaction receipt before/after payment.
5. Never credit AC from a browser redirect alone. The server must verify the payment with Paystack and settle it idempotently.
6. Treat unspent AC as outstanding customer credit, not as cash revenue or profit.
7. Do not tune prices from global app-store data as if it were AREA conversion data. Use those data only as external anchors, then validate with AREA cohorts.

## 2. Research used

### Nigerian household and digital spending

- **NITDA–NBS Nigeria Tech Outlook 2026:** 2,147 adults interviewed by telephone across all 36 states and the FCT. The report says 40.1% spend more than ₦5,000 per month on data and 43% say they would pay at least 25% more for reliable internet. It also reports that only 6.6% bought anything online in the previous three months and that 59.3% trust digital financial services. Important caveat: the achieved sample was predominantly male and older (1,688 men; 448 women; only 36 respondents aged 18–24); the report explicitly warns that the respondent mix limits interpretation of age- and sex-specific results.
  - https://nitda.gov.ng/wp-content/uploads/2026/11/NITDA26-NG-TECH-OUTLOOK-compressed.pdf
- **Nigeria Financial Habits Survey 2025:** 1,126 respondents aged 18–44 recruited through a Meta ad campaign. Food/groceries were selected by 72.0%, airtime/data by 46.1%, transport by 36.8%, family support by 27.2%, and subscriptions by 8.6%. This is a self-selected online sample, not a national expenditure survey, and the percentages measure category incidence—not the share of income spent.
  - https://columncontent.com/wp-content/uploads/2025/06/Nigeria-Financial-Habits-Survey-2025.pdf
- **BusinessDay Gen Z March 2026 poll:** 75.8% of respondents said they switch to cheaper alternatives when prices rise; 57.6% said they cut down on certain items. The published article does not provide a sample size, so use it as directional evidence, not a national estimate.
  - https://businessday.ng/news/article/when-n50000-fills-two-bags-rising-costs-reshape-gen-z-spending/
- **CBN Bullion, July–September 2026:** a study coded 1,200 public posts from X, Facebook, TikTok, Instagram and Threads about the akara/kuli-kuli price debate. Rising food prices appeared as a dominant theme in 318 posts, purchasing-power decline in 246, and household coping in 203. This is purposive social-media content analysis, not a representative survey and not proof of actual household purchases. It is useful for understanding public language and concerns across both high-visibility and ordinary public accounts; it does not provide a verified follower-status split.
  - https://www.cbn.gov.ng/Out/2026/CCD/BULLION%203rd%20%20QUARTER%202026_compressed.pdf
- **Innovations for Poverty Action, Nigeria 2024 digital-finance consumer protection:** survey of DFS users in 24 states, explicitly not nationally representative. 84% reported at least one challenge, 58% had been targeted by a fraud attempt, 6% had lost money due to a challenge, and only about one-third correctly identified the fee on their most recent mobile transaction. This strongly supports explicit receipts, clear pricing and a reliable dispute process.
  - https://poverty-action.org/sites/default/files/2025-01/2024-Nigeria-Report-Consumer-Protection-in-Digital-Financial-Services.pdf

### App-store and game-spending signals

Public app-store price points and third-party estimates for games such as Free Fire, eFootball and Call of Duty Mobile show that Nigerians do spend on digital goods and game currency. Sensor Tower-style revenue figures are estimates, not audited merchant statements, and do not reveal the distribution of spend across individual users. These signals support testing low-cost digital cosmetics and optional competition—not assuming every social user will become a payer.

### Evidence limitation

Private transaction-level data from OPay, PalmPay, TikTok, Meta, game publishers and other apps is not publicly available as a complete dataset. AREA cannot truthfully claim to have collected “all app metrics.” This model triangulates public research, public price points, third-party estimates and public conversation, then creates first-party AREA metrics to replace assumptions as actual usage accumulates.

## 3. Current pricing schedule

### AC packages

Base conversion stays at 50 AC per ₦1. Bonuses are promotional and are recorded separately from base purchased AC.

| Package | Charge | Base AC | Bonus AC | Bonus rate |
|---|---:|---:|---:|---:|
| Pocket | ₦100 | 5,000 | 0 | 0% |
| Small | ₦200 | 10,000 | 0 | 0% |
| Street | ₦500 | 25,000 | 250 | 1% |
| Regular | ₦1,000 | 50,000 | 1,500 | 3% |
| Big Man | ₦2,500 | 125,000 | 5,000 | 4% |
| Odogwu | ₦5,000 | 250,000 | 15,000 | 6% |

The ₦100 minimum is deliberate: a citizen can make a small, one-off purchase without being pushed into a subscription. Bonuses are conservative because a large bonus plus payment processing fees can consume the contribution margin before hosting, moderation, support, tax and refunds are considered.

### Digital goods and mechanics

| Item/action | Price | Naira reference |
|---|---:|---:|
| Street Frame | 5,000 AC | ₦100 |
| Yard Mark | 7,500 AC | ₦150 |
| Ink Nameplate | 10,000 AC | ₦200 |
| After Hours | 15,000 AC | ₦300 |
| Gbas Gbos level 2 escalation | 500 AC | ₦10 |
| Gbas Gbos level 3 escalation | 1,500 AC incremental | ₦30 |
| Standard Wolves penance | 1,000 AC | ₦20 |
| Community forgiveness / early return | 25,000 AC | ₦500 |

Escalation prices are incremental: level 1 → 2 costs 500 AC; level 2 → 3 costs another 1,500 AC. Existing Agbero duty rates remain owner-configurable; no duty is imposed while no active territory requires it.

### Entry tiers

| Starting tier | Entry price | Starting AC | Daily callout limit | Daily escalation limit |
|---|---:|---:|---:|---:|
| Slums | Free | 0 | 10 | 2 |
| Lapo Starter | ₦1,000 | 5,000 | 10 | 4 |
| Lapo — Senior Man | ₦2,000 | 10,000 | 10 | 6 |
| Nepo — Odogwu | ₦5,000 | 25,000 | 10 | 8 |

Paid entry starting AC is 10% of the entry fee at the current reference conversion. It is credited only after payment verification. Basic social access is not paywalled; higher classes get more escalation capacity, not unlimited ability to dominate or harass.

## 4. Payment processing and contribution margin

Paystack's published local payment pricing is 1.5% plus ₦100, with the fixed ₦100 component waived for transactions below ₦2,500 and a cap on the fee. At exactly ₦2,500, do not assume the fixed component is waived. The exact fee returned on each verified transaction is stored in the payment order.

Illustrative processor cost using the published schedule:

| Charge | Approx. processor fee | Approx. amount after processor fee |
|---:|---:|---:|
| ₦100 | ₦1.50 | ₦98.50 |
| ₦200 | ₦3.00 | ₦197.00 |
| ₦500 | ₦7.50 | ₦492.50 |
| ₦1,000 | ₦15.00 | ₦985.00 |
| ₦2,500 | ₦137.50 | ₦2,362.50 |
| ₦5,000 | ₦175.00 | ₦4,825.00 |

These are illustrations, not settlement guarantees. Actual fee amounts from Paystack verification are stored in kobo and shown in the owner treasury. Net-after-processor-fees is still not profit: taxes, refunds, chargebacks, hosting, support, moderation and other operating costs remain to be deducted.

Paystack merchant terms place responsibility for the merchant's products, customer support, KYC information, delivery, refunds and compliance on the merchant. AREA must have a clear customer-support and refund process before live collection.
- https://paystack.ng/terms

## 5. Accounting model

- **topup ledger entry:** base AC purchased.
- **bonus ledger entry:** promotional AC or paid-entry starting balance.
- **gift:** citizen-to-citizen transfer; it is not new revenue.
- **purchase, fee, penance, reward and refund:** internal AC movements/sinks or distributions; they are not automatically naira revenue.
- Payment orders store the NGN amount, AC amounts, provider reference, Paystack transaction ID, verified fee, status and payment timestamp.
- Duplicate callbacks/webhooks cannot credit the same order twice.
- The citizen wallet shows payment receipt references.
- The owner treasury reports gross top-ups, paid-entry revenue, processor fees, net after processor fees, outstanding AC, unique payers, repeat payer rate, average payment, revenue per payer and 30-day activity.

**Outstanding AC is a liability/unused credit balance, not cash profit.** AC transfers move balances between citizens; they do not create revenue. Only verified NGN payments create gross cash receipts.

## 6. Regulatory launch gate

The CBN's November 2026 Regulations for the Operations of Non-Security Virtual Assets exclude loyalty points, rewards and vouchers only where they are confined to a limited network and cannot be exchanged for money or transferred to third parties. AREA AC is non-cashable by design, but the current product also supports user-to-user gifts and other distributions to citizens. That makes the exact legal classification important. The CBN says classification depends on economic substance and functionality, not the label used by the operator.

Do not set AREA_PAYMENTS_ENABLED=true until Nigerian payments counsel has reviewed:
- whether purchased, transferable AC is an exempt closed-network reward, stored-value/e-money product, or another regulated arrangement;
- whether user-to-user gifting, Agbero owner distributions and jury rewards change that analysis;
- whether a licensed bank/PSP partner or a change to transfer functionality is required;
- the correct consumer disclosures, KYC/AML controls, refund rules, tax treatment and record retention.

Primary CBN source:
- https://www.cbn.gov.ng/Out/2026/CCD/REGULATIONS%20FOR%20THE%20OPERATIONS%20OF%20NON-SECURITY%20VIRTUAL%20ASSETS%20IN%20NIGERIA.pdf

The payment feature flag is deliberately separate from the presence of API keys. It prevents checkout from turning on accidentally when secrets are added. It does not, by itself, disable existing AC transfer functions.

## 7. Technical payment flow

1. Authenticated citizen selects a package or paid entry tier.
2. Server creates a private pending order with an AREA-generated reference.
3. Server initializes Paystack with NGN amount in kobo.
4. Browser is redirected to Paystack.
5. Paystack callback and signed webhook both independently verify the transaction with Paystack's verification API.
6. Settlement checks reference, status, currency and exact amount.
7. A service-role-only RPC credits the wallet or applies the paid entry tier and starter balance.
8. The order is marked paid in the same database transaction. Duplicate callbacks are idempotent.
9. Failed/abandoned transactions are marked failed so pending orders do not accumulate.
10. The wallet and owner treasury show the receipt and payment metrics.

### Required server environment

- AREA_PAYMENTS_ENABLED=false (keep false until approved)
- PAYSTACK_SECRET_KEY
- PAYSTACK_WEBHOOK_SECRET
- SUPABASE_SERVICE_ROLE_KEY (server-only; never expose with a NEXT_PUBLIC_ prefix)
- NEXT_PUBLIC_SITE_URL=https://area-woad.vercel.app

Configure the Paystack webhook URL as:

https://area-woad.vercel.app/api/payments/paystack/webhook

Use Paystack test keys first. Do not paste secret keys into chat, GitHub, source code or client-side variables.

## 8. What is not ready for live money

- Paystack merchant approval and API secrets have not been configured.
- Legal classification of transferable AC has not been obtained.
- Automated customer refunds, chargebacks and dispute workflows are not implemented.
- Bank settlement reconciliation and tax accounting are not complete.
- The latest payment-system source commit has a successful production build. Documentation-only updates may still trigger a follow-up deployment.
- No AREA payment orders exist yet, so all payer metrics are zero and no pricing has been validated by actual AREA customers.

## 9. Validation plan after approval

1. Run test-mode ₦100 top-up and one paid entry purchase.
2. Send the same success webhook twice; confirm only one credit.
3. Test failed and abandoned payments; confirm no AC is issued and the order is released for retry.
4. Test amount/currency mismatch and invalid webhook signatures; confirm rejection.
5. Confirm wallet receipt, owner gross revenue, processor fee and net-after-fee match the Paystack verification record.
6. Test refund and chargeback procedures before enabling live payments.
7. Invite a small first cohort; measure D1/D7/D30 retention, payer conversion, repeat payer rate, average order value, revenue per payer, package mix, AC spend velocity, market purchase rate, escalation usage, refund rate and chargeback rate.
8. Only then run controlled price experiments. Change one variable at a time; do not alter the 50 AC/₦1 reference while testing item prices or package bonuses.


## 11. Scale reality check

These are sensitivity scenarios, not forecasts. They assume the stated share of monthly active users buys AC every month at the stated average spend. They exclude one-time entry revenue, processor fees, bonus-credit dilution, taxes, refunds and operating costs.

| Monthly active users | Payer conversion | Paying users | Average monthly spend | Gross monthly receipts | Annualized gross |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 1% | 10 | ₦100 | ₦1,000 | ₦12,000 |
| 10,000 | 3% | 300 | ₦500 | ₦150,000 | ₦1.8m |
| 100,000 | 5% | 5,000 | ₦1,000 | ₦5m | ₦60m |
| 1,000,000 | 5% | 50,000 | ₦1,000 | ₦50m | ₦600m |

At ₦1,000 average monthly spend and 5% payer conversion, ₦5bn in annual gross receipts requires roughly 8.33 million monthly active users. At ₦500 average monthly spend, it requires about 16.67 million monthly active users. At 2% conversion, the required audience is 2.5 times larger. This is why the product's retention, organic distribution and trust matter more than squeezing another ₦50 out of an early cosmetic.

The paid entry tiers are one-time revenue, not a recurring revenue engine. Recurring revenue must come from voluntary top-ups and repeat purchases that citizens genuinely value.

## 12. Pricing decisions are hypotheses

The first price ladder intentionally tests low-cost, one-off purchases. The research supports price sensitivity, high priority for essentials and the importance of reliability and trust. It does not prove that AREA users will pay these prices. The first 100–500 real users should determine the next revision through observed conversion and repeat behaviour, not founder intuition or competitor revenue headlines.
