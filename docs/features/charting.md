# Charting Strategy — Package vs Custom Painters

**Status:** implemented baseline — `fl_chart` for the main 12-week chart, CustomPainter for micro visuals
**Last checked:** 26 Oct 2026

---

## 1. What NubiSport already has

All current charts are hand-drawn with `CustomPainter`:

| Chart                  | Where              | Type                              |
| ---------------------- | ------------------ | --------------------------------- |
| 12-week distance chart | Profile → Progress | Line + area + dots + axes         |
| Fitness sparkline      | Profile → Progress | Line                              |
| Performance sparkline  | Profile → Progress | Line                              |
| Training Zones         | Profile → Progress | Horizontal bars                   |
| Relative Effort        | Profile → Progress | Gradient bar + marker             |
| Route art              | Share card         | Polyline over a styled background |

The 12-week distance chart now uses `fl_chart` through a themed wrapper (`lib/shared/widgets/charts/nubi_line_chart.dart`). The rest remain hand-drawn so the tiny sparklines, zone bars and share-card route art keep their exact brand look.

The main chart now has touch tooltips, the current-week marker, themed dots/grid and a `Semantics` label. The remaining custom charts still lack shared axis/label logic and per-point tooltips.

---

## 2. Evaluation criteria

1. **Licence** — can we ship it commercially without a legal surprise?
2. **Maintenance** — active releases, issues, Flutter compatibility.
3. **Fit for NubiSport** — line/area/bar/sparkline, dark/light theme, orange/navy styling.
4. **Interaction** — tooltips, touch scrubbing, zoom/pan.
5. **Learning/implementation cost** — time to first chart and to a custom look.
6. **Bundle/performance** — especially on feed/profile with several charts.
7. **Accessibility** — whether we still need a raw-data fallback.

---

## 3. Package comparison (checked 26 Oct 2026)

| Option                                | Licence                                             | Maturity                                                   | Chart types                                 | Interactivity                              | Verdict                                                            |
| ------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------ |
| **fl_chart 1.3.0**                    | **MIT**                                             | 7.2k likes, 2.12M downloads, active (published 5 days ago) | Line, bar, pie, scatter, radar, candlestick | Tooltips, touch, animations                | **Best general-purpose choice**                                    |
| **syncfusion_flutter_charts 35.1.41** | Commercial; free Community Licence only if eligible | 3.6k likes, 233k downloads, active                         | 30+ types + spark charts                    | Zoom, pan, trackball, crosshair, selection | Great features, but licence risk                                   |
| **graphic 2.7.0**                     | MIT                                                 | 902 likes, 42.8k downloads, last release 8 months ago      | Grammar-of-graphics, composed marks         | Events, selection, animation               | Powerful for bespoke charts; steeper learning                      |
| **d_chart**                           | MIT                                                 | ~205 likes, 9.8k downloads                                 | Simple line/bar/pie                         | Basic                                      | Average maintenance; not compelling over fl_chart                  |
| **community_charts_flutter**          | Apache/MIT fork                                     | ~221 likes, 32.8k downloads                                | Google Charts fork                          | Basic                                      | Maintenance rated Poor; avoid                                      |
| **charts_flutter (Google)**           | Discontinued                                        | —                                                          | —                                           | —                                          | Do not use                                                         |
| **flutter_echarts**                   | Apache ECharts via WebView                          | ~576 likes, 3.5k downloads                                 | Very broad                                  | Full ECharts                               | WebView/Javascript bridge; Poor maintenance; not for native charts |
| **CustomPainter (ours)**              | Our code                                            | —                                                          | Exactly what we draw                        | We build it                                | Best for tiny/branded visuals; expensive for full chart UX         |

### fl_chart

**Pros**

- MIT; free for commercial use.
- Huge adoption and active maintenance.
- Line, bar, pie, scatter, radar and candlestick; enough for running stats, splits, heart rate, elevation and weekly volume.
- Custom titles, grid, dots, gradients, touch tooltips and animations.
- Pure Flutter (no WebView), works on iOS/Android/web/desktop.
- Easy to theme with our orange/navy palette.

**Cons / limits**

- Highly custom layouts (e.g. the current hand-drawn look) still need work; some axis/legend positions are opinionated.
- Very large datasets need downsampling; tooltips/labels can get crowded.
- Accessibility is still our responsibility; package does not give a semantic data table automatically.
- Frequent major-ish versions; pin the version and test upgrades.

### Syncfusion

**Pros**

- 30+ chart types, spark charts, zoom/pan, trackball, crosshair, selection, legends.
- Very polished out of the box; fast for advanced dashboards.
- Commercial support and frequent releases.

**Licence**

- Free **Community Licence** only if the company has:
  - less than **$1M USD annual gross revenue**,
  - **5 or fewer developers**,
  - **10 or fewer total employees**,
  - and has never received more than **$3M USD** outside capital.
- If NubiSport grows past those limits, a paid licence is required.
- Flutter is offered as an add-on benefit for UI Component Suite users.

**Verdict:** technically excellent, but we should not make our chart layer depend on a licence that expires when the company grows. Consider only if we need its advanced features and can accept the commercial terms.

### graphic

**Pros**

- MIT, pure Flutter, grammar-of-graphics model.
- Very flexible composition, good for bespoke visualisations (multi-layer, annotations, unusual marks).
- Interaction and animation built in.

**Cons**

- Smaller community; unverified publisher; 8 months since last release.
- Learning curve is higher; more code for a standard line chart.
- Overkill for sparklines and simple weekly charts.

**Verdict:** keep as an option for a future bespoke visual (e.g. pace/elevation profile with annotations), not for the standard progress charts.

### CustomPainter

**Pros**

- Zero dependency, exact brand control, smallest code for a tiny chart.
- We already own the route art, sparklines and bars.
- No licence or upgrade risk; easy to make pixel-perfect.

**Cons**

- We must build and maintain axes, hit testing, tooltips, animations, accessibility, and edge cases.
- Duplicated logic across charts unless we extract shared painters.
- The existing line chart has no tooltip and no semantic fallback.

**Verdict:** keep it for **micro visuals** and custom art. Do not build a general charting framework from scratch.

---

## 4. Recommendation

### Use a hybrid approach

1. **Keep CustomPainter for:**
   - sparklines (Fitness, Performance),
   - Training Zones bars,
   - Relative Effort bar,
   - route art on share cards,
   - any tiny decorative visual.

   These are less than a screen of code and need exact brand styling. A package would add dependency and still need customisation.

2. **Use `fl_chart` for the main interactive charts** when we add:
   - touch tooltips on the 12-week chart,
   - pace/heart-rate/elevation charts,
   - split bars,
   - weekly/monthly comparisons,
   - zoom/pan or selection.

3. **Do not use Syncfusion** unless the Community Licence clearly applies and we need advanced features that fl_chart cannot do. Treat a paid Syncfusion licence as a product-level cost.

4. **Do not use `charts_flutter`/`community_charts_flutter`** (discontinued/poor maintenance) or WebView-based ECharts for native stats.

5. **Do not build our own charting framework.** For simple charts, custom painters are fine. For interactive charts, use a maintained package.

### Practical target

- Add `fl_chart: ^1.3.0` only when we start the interactive chart work.
- Create shared wrappers in `lib/shared/widgets/charts/`:
  - `NubiLineChart`
  - `NubiSparkline`
  - `NubiBarChart`
- Keep the wrappers themed with `AppColors` and `AppTheme`.
- Always provide a `Semantics` label and a raw-data/table fallback for accessibility.

---

## 5. Suggested migration path

### Phase 1 — no new dependency (now)

- Leave the existing CustomPainter charts.
- Extract chart colours, axis labels and padding into shared helpers.
- Add `Semantics` labels describing the trend (e.g. “Jarak 12 minggu, 28.4 km minggu ini”).
- Fix unnecessary repaints by comparing list contents rather than list identity.

### Phase 2 — POC fl_chart

Build the 12-week distance chart with fl_chart behind a feature flag and compare:

- closeness to the current design,
- code size,
- touch/tooltip quality,
- performance on a profile with many cards,
- accessibility fallback.

Adopt fl_chart for interactive charts if the POC is clean. Keep the custom sparklines.

### Phase 3 — health/fitness charts

When health data lands (heart rate, sleep, recovery, splits):

- use fl_chart for full-size charts,
- use CustomPainter for tiny inline indicators,
- add a data-table fallback for screen readers.

---

## 6. Quick decision rule

| Need                                          | Choice                      |
| --------------------------------------------- | --------------------------- |
| Sparkline under a stat                        | CustomPainter               |
| Branded share-card route art                  | CustomPainter               |
| Simple 12-week line with no interaction       | CustomPainter is fine       |
| Line/bar with tooltips, touch, animation      | fl_chart                    |
| 30+ chart types, zoom/pan, enterprise support | Syncfusion only if licensed |
| Bespoke multi-layer visual with unusual marks | graphic                     |
| Discontinued/WebView charts                   | Avoid                       |

---

## 7. Sources

- [fl_chart on pub.dev](https://pub.dev/packages/fl_chart)
- [FL Chart documentation](https://flchart.dev/)
- [syncfusion_flutter_charts on pub.dev](https://pub.dev/packages/syncfusion_flutter_charts)
- [Syncfusion Community Licence](https://www.syncfusion.com/products/communitylicense)
- [graphic on pub.dev](https://pub.dev/packages/graphic)
- [Flutter Gems — Plots & Visualization packages](https://fluttergems.dev/plots-visualization/)
