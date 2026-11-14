# AI photo calorie apps and smart nutrition scales: competitors to Miqdar

Researched 2026-11-14. Source quality is flagged throughout. Much of the "accuracy" material on the web comes from blogs run by competing apps; those numbers are labelled as such. Peer-reviewed or controlled sources are marked **[controlled]**.

## AI photo apps: what they do, how accurate they are, what users complain about

### Takeaway
Photo-only apps (Cal AI, MyFitnessPal Meal Scan, Lose It! Snap It, Foodvisor, SnapCalorie) name foods fairly well, but they guess portion size badly. They undercount calories by about a third, mostly fat. The best 2026 controlled test found every app tested undercounting by 252 to 345 kcal per meal. Weighing removes the portion guess, so Miqdar's design avoids the biggest known failure. What remains is error in the per-100 g figure for oily, mixed and regional dishes.

### Cited Findings

**Controlled accuracy evidence**
- **[controlled, conference abstract, not peer reviewed]** NIDDK/NIH controlled feeding study (Charles O et al.; spokesperson Aaron Hengist). 102 nutrient-controlled meals were made in a metabolic kitchen, and photos of them went through 4 apps. Mean energy underestimate per meal: Appediet 252 kcal, MyFitnessPal 327, Lose It! 333, Cal AI 345, about 33% overall. All four apps underestimated fat by about 30 g. Lose It! and Cal AI underestimated carbs by about 14 g. Lose It! and MyFitnessPal did better on higher-energy meals than on lower-energy ones. The researchers advise entering food amounts by hand. Presented at NUTRITION 2026, July 25–28, 2026. Follow-up findings suggest the undercount grows on higher-fat, lower-carb meals — [Healio](https://www.healio.com/news/primary-care/20260804/ai-photobased-calorietracking-tools-underestimate-them-by-33); also [EurekAlert](https://www.eurekalert.org/news-releases/1136415) (as cited by Callie's list)
- **[controlled, peer reviewed]** Rodríguez-Jiménez M et al., *Nutrients* 2025;17(22):3613. ChatGPT-5, 195 dishes (Allrecipes 96, SNAPMe 74, 25 dietitian-weighed home meals). Energy mean absolute error by input:

  | Input | Energy error |
  |---|---|
  | Photo only | 123 kcal |
  | Photo + non-visual descriptors | 92 kcal |
  | Photo + ingredients with amounts | 53 kcal |
  | Ingredients only, no photo | 66.5 kcal |

  Protein, carbohydrate and fat errors fell in the same order. So the photo adds value beyond the ingredient arithmetic. The study does not separate the effect of the amounts from the effect of the ingredient list — [PMC12655113](https://pmc.ncbi.nlm.nih.gov/articles/PMC12655113/)
- **[peer reviewed; seen only through an aggregator's summary, primary not opened]** Fridolfsson J et al., *Current Developments in Nutrition* 2025;9(10):107556. 52 photos. Mean energy error was 35.8% for GPT-4o and for Claude 3.5 Sonnet, and 64.2% for Gemini 1.5 Pro. Protein error ran from 60.7% to 109.9% — [PMC12513282](https://pmc.ncbi.nlm.nih.gov/articles/PMC12513282/) via [Callie study list](https://www.mycallie.app/en/blog/ai-calorie-accuracy-research)
- **[peer reviewed; via aggregator]** Isobe T et al., *Nutrients* 2026;18(6):966. 10 AI models, including GPT-4o and Gemini 1.5 Pro, against 10 dietitians on 15 hospital meals. The top models were often within 10% for energy (r > 0.8), but all models overestimated fat by more than 20% — [DOI 10.3390/nu18060966](https://doi.org/10.3390/nu18060966) via [Callie](https://www.mycallie.app/en/blog/ai-calorie-accuracy-research)
- **[preprint]** Li X, 2026, arXiv:2610.26538. 6 Claude and GPT models, 802 meals over 148 feeding days. Three models kept the 90% CI of average error within 10%. None met a 30% per-meal limit. So averages are fine but single meals are not — [arXiv](https://arxiv.org/abs/2610.26538) via [Callie](https://www.mycallie.app/en/blog/ai-calorie-accuracy-research)
- **[peer reviewed]** A 2024 *Nutrients* comparison of 7 AI image apps against food records found MyFitnessPal (97%) and Fastic (92%) most accurate at identifying food. It also found that automatic energy estimates were inaccurate, and poor for mixed and cultural dishes — [Nutrients 16(15):2573](https://www.mdpi.com/2072-6643/16/15/2573)
- **[systematic review]** Shonkoff E et al., *Annals of Medicine* 2023. 52 studies of automated image methods: average calorie error from 0.10% to 38.3%, lower for simple foods — [PubMed 38060823](https://pubmed.ncbi.nlm.nih.gov/38060823/) via [Callie](https://www.mycallie.app/en/blog/ai-calorie-accuracy-research)
- **[validation study]** CALO mama, a Japanese app, underestimated energy and 19 nutrients — [PMC8787663](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8787663/)
- A review notes that mobile LiDAR's spatial resolution "is often insufficient for dietary assessment" — [Vinod & Zhu, arXiv 2602.05078](https://arxiv.org/html/2602.05078)

**Regional food recognition**
- Recognition of Lebanese and regional dishes reached 78.66% accuracy across 174 classes (AUB MS thesis, 2025, no calorie figure) — [AUB ScholarWorks](https://scholarworks.aub.edu.lb/items/b4a5f886-4834-48a3-bdf1-31aeedde9ce3/full)
- Recognition of Middle Eastern food reached 94% across 23 classes (Aktı et al., 2022) — [arXiv 2204.09432](https://www.arxiv.org/abs/2204.09432)

**Per-app features and claims**
- **Cal AI:** photo logging that estimates volume with the phone's depth sensor (per Cal AI's own blog; whether it uses LiDAR is not stated), and splits a photo into its component foods. It claims a result in under 15 s. It has a "describe" text fallback for soups and smoothies, and barcode scanning. MyFitnessPal acquired it (closed Dec 2025, announced Mar 2026) and says it passed 15M downloads and $30M yearly revenue — [RaftLabs teardown](https://www.raftlabs.com/blog/cal-ai-product-teardown). Cal AI's own accuracy claims vary between "about 80%" and "90% on visible foods" — [search summary of Cal AI FAQ and blog, via Fitia](https://fitia.app/learn/article/ai-calorie-photo-apps-accuracy-2026/)
- **SnapCalorie:** made by ex-Google AI researchers, who built the Nutrition5k dataset of 5,000 dishes with every ingredient weighed. A voice note can be added to a photo to give context the camera cannot see, such as cooking method or a measured portion. It also has voice-only logging and a ChatGPT-based nutrition chatbot — [App Store](https://apps.apple.com/us/app/-/id1574239307), [Feastgood review](https://feastgood.com/?p=37083). The company claims error under 20% and "2x more accurate than nutritionists", which is unverified — [TechCrunch 2023](https://techcrunch.com/2023/06/26/snapcalorie-computer-vision-health-app-raises-3m/). Blogs say it uses LiDAR volume measurement, but I found no study — [Macaron](https://macaron.im/en/blog/ai-calorie-tracker-by-photo)
- **Lose It! Snap It:** now on the Premium tier. One reviewer says portions are consistently off by 25–45%, against 30–50% for MyFitnessPal Meal Scan — [Calorie Tracker Lab](https://calorietrackerlab.com/reviews/lose-it/). A non-independent benchmark gives a 68.7% identification rate, ±22% portion error and 11.2 s median time — [ai-food-tracker.com](https://ai-food-tracker.com/reviews/lose-it/)
- **MyFitnessPal Meal Scan:** a non-independent benchmark gives 71.2% identification and ±18% portion error, falling to 58.3% on East Asian food — [ai-food-tracker.com](https://ai-food-tracker.com/reviews/myfitnesspal/)
- **Foodvisor:** in a hands-on test it set rice 25 g too high and asparagus 15 g too low. Its portions looked like generic defaults rather than values read from the photo, and repeated photos of the same meal gave different suggestions — [Feastgood meal scan test](https://feastgood.com/meal-scan-accuracy-for-nutrition-apps/). Benchmarks disagree on its portion error: ±31% in one, ±13.9% in another — [ai-food-tracker.com](https://ai-food-tracker.com/best-ai-food-trackers/) vs [nutrition-apps-ranked](https://nutrition-apps-ranked.com/en/articles/cal-ai-vs-foodvisor-vs-myfitnesspal-ranked-2026/)
- **Callie** (a 2026 LLM newcomer), in its own test: 13% error against Cal AI's 17%, on 20 meals weighed on a 0.1 g scale against USDA FoodData Central. Callie ran the test itself, so it is not independent — [Callie vs Cal AI](https://www.mycallie.app/en/compare/callie-vs-cal-ai)

**User complaints**, drawn from reviews rather than surveys: portions are wrong or look like defaults; the same meal gives different results across photos; hidden oil and fat are missed; photo AI is locked behind a paywall (Snap It) — [Feastgood](https://feastgood.com/meal-scan-accuracy-for-nutrition-apps/), [Calorie Tracker Lab](https://calorietrackerlab.com/reviews/lose-it/), [Healio](https://www.healio.com/news/primary-care/20260804/ai-photobased-calorietracking-tools-underestimate-them-by-33)

### Inferences
- The errors are systematic: consistent undercounting, centred on fat. That matters more for Miqdar than random error would. Even with grams measured, Gemini's per-100 g value for oily Gulf dishes (kabsa, mandi, saleeg) may run low. Fridolfsson's 64% Gemini 1.5 error is an old model; Miqdar uses newer Flash models, but has no published figure of its own.
- Rodríguez-Jiménez supports Miqdar's design. A photo plus measured amounts more than halved the error compared with a photo alone. Miqdar gives measured grams for the whole plate, or per food in plate mode, but not an ingredient list. A short "how was it cooked / how much oil?" prompt would add the "non-visual descriptors" that cut error by about 25% in that study.
- Weighing fixes the portion problem, but only for what is on the scale, not for what is eaten. Miqdar's leftovers weighing goes beyond every photo app on this point.
- SnapCalorie's voice note with the photo and Cal AI's "describe" fallback are close to features Miqdar has. Miqdar has text and voice description only on the Failure sheet and in away-from-scale logging, not as extra context for a scale capture.

### Gaps
- No peer-reviewed validation of Foodvisor, Bitesnap, Calorie Mama, Lifesum or Yazio AI was found within the time available. Lifesum's and Yazio's 2025–2026 AI features were not researched (out of tool budget).
- The full NIH abstract was not read. Healio lists the CI bounds out of order.
- I found no evidence of any app asking follow-up clarifying questions automatically, such as "was this fried?". It may exist in LLM newcomers, but it is unconfirmed.
- Whether any app learns from user corrections (for example, "my kabsa is usually 180 kcal/100 g") was not confirmed.

## Smart nutrition scales, including camera scales

### Takeaway
Consumer nutrition scales (Etekcity, Renpho, Drop) are plain Bluetooth scales: the user picks the food from a database by hand, and the scale supplies grams. Their weak points are the app, sync, and the manual searching. The one direct commercial rival is **Qalzy**, a camera scale with AI recognition that does almost exactly what Miqdar does: camera, OpenAI recognition, auto-tare between ingredients, Alexa voice, label reading, an on-device display. Academic Raspberry Pi prototypes (SCALEeat) and hospital camera-plus-scale systems also exist.

### Cited Findings
- **Qalzy** (Kickstarter, first covered May 2025, page updated Oct 2026): 2 MP camera, OpenAI-powered recognition of raw, cooked and mixed meals, combined with the weight. Auto-tares between ingredients and scans several items at once. Reads branded foods and nutrition labels, with a database of 2M+ foods (USDA, CoFID). Voice logging through Alexa, including hard-to-see items such as oils. LED flash for low light, splash-proof glass, 5 kg at ±1 g, 10 h battery, USB-C. Syncs with Apple Health and Health Connect, can upload to the cloud without the phone, has an app-only mode and barcode scanning in the app. $269 retail, $169 early backers, app "without ongoing fees". No independent accuracy test — [Notebookcheck](https://www.notebookcheck.net/New-Qalzy-AI-kitchen-scale-makes-food-tracking-automatic-with-camera-calorie-logging-and-app-sync.1010973.0.html); [T3](https://www.t3.com/home-living/appliances/this-ai-kitchen-scale-uses-a-built-in-camera-to-track-your-meals-calories); [Qalzy](https://qalzy.com/). Qalzy's site cites "up to 65%" error for photo apps and its own internal user data from Aug–Oct 2026, neither verified — [search summary of qalzy.com](https://qalzy.com/)
- **SCALEeat** (*Engineering Proceedings* 2026): Raspberry Pi 5 with a camera and load cell. Computes calories, carbs, protein and fat from the measured weight, using a Philippine food composition database. Recognition was 97.33% top-1 on 300 test images and 93.60% end to end. The authors say it reliably identifies *single* items — [DOI 10.3390/engproc2026134083](https://doi.org/10.3390/engproc2026134083) (abstract via search; the full text returned 403)
- **Hackster.io DIY build:** YOLO running on a Jetson, offline, real-time macros — [Hackster](https://www.hackster.io/marinmandarinegirl/ai-kitchen-scale-with-real-time-nutrition-tracking-f13240)
- **Etekcity nutrition scales** (ESN00, ESN90, Luminary) with the VeSync app: 12 nutrition facts on the scale, 19 in the app. Search the USDA's roughly 8,000 foods or enter values by hand. Barcode scanning, food records, nutrition goals, and sync with Apple Health and Fitbit — [Etekcity Luminary](https://etekcity.com/products/ens-l221s-sus-luminary-smart-nutrition-scale), [ESN90 manual](https://etekcity.com/cdn/shop/files/ESN90.pdf). Digital Trends: "the app is the real brain", and the scale "isn't the most intuitive device" — [Digital Trends](https://digitaltrends.com/home/etekcity-esn00-smart-nutrition-scale-review)
- **Renpho** (Calibra 1, Smart Food Scale 2; Renpho Health and Gennec apps): 23 nutrition facts, several units. Complaints: glass smears, recalibration needed after moving it, the scale failing to record to the app — [Live Science](https://www.livescience.com/renpho-smart-scale-review), [Renpho Calibra listing](https://newplacestobe.com/Scale-White-RENPHO-US-306-83247.html). An AI-generated review summary (low trust) reports forced logouts and sync failures — [marlvel](https://marlvel.ai/api/llm/apps/health-fitness/com-renpho-health)
- **Drop (Perfect Company):** a recipe-guided scale with no display. The app walks through each ingredient and *rescales the recipe* if you are short of one, and recipes show calories per serving. Complaints: a small recipe library, and it is not a nutrition tracker — [SlashGear](https://www.slashgear.com/drop-scale-review-no-need-to-weigh-your-options-21360086), [Drop help: nutrition](https://drop.helpjuice.com/drop-recipes-features/nutrition)
- **Hospital and institutional systems:**
  - DIMS photographs and weighs plates before and after eating. Portion-size ICC was 0.88 before eating and 0.99 after (pilot) — [Public Health Nutrition / PMC10260788](https://pmc.ncbi.nlm.nih.gov/articles/PMC10260788/)
  - A 2026 hospital weighing-and-camera system reported 99.2% recognition on 1,000 samples. Its volume estimate was above 90% accurate in only 39% of cases — [Frontiers in Nutrition 2026](https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2026.1637034/full)
  - Commercial kitchens use camera-plus-scale food-waste bins (Winnow, Leanpath, Orbisk). Accuracy figures are self-reported by the vendors — [Bloomberg 2024](https://www.bloomberg.com/news/articles/2024-07-01/ai-enhanced-garbage-bins-aim-to-solve-food-service-s-waste-problem), [Leanpath](https://blog.leanpath.com/leanpath-ai-enabled-food-waste-tracking)

### Inferences
- Miqdar is no longer unique as a "camera + scale + AI" device: Qalzy is commercial and SCALEeat is academic. Its distinct points are Arabic, Gulf food, leftovers weighing, diabetes carb mode, Ramadan mode and a doctor's report. None of these appear in Qalzy's coverage.
- The DIMS before-and-after weighing (ICC 0.99 after eating) is the same idea as Miqdar's Weigh What's Left, which strengthens the case for it in reports.

### Gaps
- No information was found on Greater Goods or Nutratrack scales, or Arboleaf and Ozeri nutrition models.
- Qalzy's product page returned HTTP 429. Its shipping status and real reviews are unknown, and whether it supports Arabic or diabetes features is unconfirmed.
- I found no independent accuracy test of any camera scale.

## Research on combining weight with images

### Takeaway
The evidence consistently shows that recognition is the easy part and portion size is the hard part. Measured weight cuts error sharply. The best direct evidence is the ChatGPT-5 study: error fell from 123 kcal with a photo alone to 53 kcal with photo plus amounts. Weighing systems (DIMS) reach near-perfect portion agreement.

### Cited Findings
- A photo with ingredient amounts cut energy error from 123 kcal to 53 kcal (−57%) against a photo alone, for ChatGPT-5 on 195 dishes — [PMC12655113](https://pmc.ncbi.nlm.nih.gov/articles/PMC12655113/)
- DIMS image-plus-weight: portion ICC 0.88 before eating, 0.99 after — [PMC10260788](https://pmc.ncbi.nlm.nih.gov/articles/PMC10260788/)
- Image-only weight estimation, from an SSRN preprint: 88.18% recognition, but only 76.36% of weight estimates within 20% — [SSRN 7466364](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7466364)
- A US patent argues that a single image cannot capture volume, density or weight, which is why it uses a load sensor — [USPTO 9349297](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9349297)
- A 2026 study measured the gain from image-text pairs for calorie estimation — [arXiv 2511.11705](https://arxiv.org/pdf/2511.11705) (title only, not read)

### Inferences
- Miqdar's main remaining error sources are, in likely order: the per-100 g density of mixed, oily dishes; the edible fraction (bones, peel); and naming. Measured weight removes the portion term that dominates the app studies.

### Gaps
- I found no study that measures Gemini with weighed grams against a weighed-intake reference on Gulf food. Miqdar's planned accuracy test would be close to new evidence.

## What competitors offer that Miqdar lacks

### Takeaway
The main gaps are: food databases and barcode or label reading for packaged food; voice or text context attached to a scale capture; recipe mode with per-ingredient tare; health-platform sync; learning from user corrections; and a low-light flash. Several of Miqdar's features (leftovers, diabetes carb choices, Ramadan mode, doctor's PDF, Arabic, Gulf food) were not seen in any competitor researched.

### Cited Findings
| Feature | Who has it | Miqdar today (from AGENTS.md) |
|---|---|---|
| Barcode scan, reading nutrition labels | Qalzy, Etekcity, Cal AI ([Notebookcheck](https://www.notebookcheck.net/New-Qalzy-AI-kitchen-scale-makes-food-tracking-automatic-with-camera-calorie-logging-and-app-sync.1010973.0.html), [Etekcity](https://etekcity.com/products/ens-l221s-sus-luminary-smart-nutrition-scale), [RaftLabs](https://www.raftlabs.com/blog/cal-ai-product-teardown)) | Gemini prompt reads labels (2026-11-01 entry); no barcode |
| Verified food database (USDA, CoFID, MFP 20M) | Qalzy, Etekcity, Cal AI after the MFP deal | Gemini only, by decision; local catalog for Change Food |
| Voice note as context for a photo | SnapCalorie ([App Store](https://apps.apple.com/us/app/-/id1574239307)); Alexa for oils on Qalzy | Voice only for away-from-scale description; not run on a device |
| Auto-tare per ingredient, net weight of each | Qalzy | Plate mode gives grams per food, by button |
| Recipe guidance, rescaling, calories per serving | Drop ([SlashGear](https://www.slashgear.com/drop-scale-review-no-need-to-weigh-your-options-21360086)) | None (cook-once recipe weighing rejected 2026-11-07) |
| Apple Health / Health Connect / Fitbit sync | Qalzy, Etekcity | None; local diary, CSV export |
| On-scale nutrition display | Etekcity (12 facts), Qalzy | Touchscreen shows the result, Save and Cancel |
| LED flash for low light | Qalzy | None known |
| Chatbot for nutrition questions | SnapCalorie | None |
| Upload without a phone nearby | Qalzy | Pi needs the phone for Gemini, by design |
| Before-and-after plate weighing | DIMS, hospital research | Yes (Weigh What's Left) |

### Inferences
- The changes most worth considering, judged by the evidence: (1) a short context step on Review, such as cooking method or oil, typed or spoken, since this cut error about 25% in Rodríguez-Jiménez; (2) a fat or oil check, since every study found undercounted fat; (3) barcode scanning for packaged food; (4) remembering a user's correction for a recurring dish. Point 4 needs care against Abdullah's decision that Gemini analyzes every food.
- Miqdar's features not seen elsewhere could be shown in the demo as differentiators: Arabic UI, Gulf dishes, leftovers, diabetes carb choices, Ramadan mode, the doctor's report.

### Gaps
- I did not verify whether Cal AI, Foodvisor or the others offer leftover logging, diabetes modes or Arabic. Their absence above means "not found", not "confirmed absent".
- Lifesum, Yazio, Bitesnap and Calorie Mama were not researched in depth, because of the tool budget.
