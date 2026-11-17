# Oh My Esok preview 3

Preserve the light/dark surfaces, hierarchy, grouped lists, and glass navigation of the installed preview 2. The exploratory Material 3 redesign, colored summary cards, grouped columns, and connecting line chart were rejected. Keep the main balance prominent, and present income and expense as plain figures on the existing surface, with no individual boxes.

Keep **Oh My Esok** as the root header. The floating glass dock has four destinations: Hari, Uang, Laporan, Setelan. Primary add controls belong near the bottom, outside the dock. Keep both controls and the last list row reachable with either Android navigation mode and large text. Preserve the selected day when adding a daily note.

For report plots, use `fl_chart: ^1.3.1` from the lockfile. The compact volume view plots income as received and expense with its effect on cash flow (negative of the recorded expense). Signed imported values retain their meaning; when both marks share a side, draw them side by side to keep both measurable. Display exact recorded amounts separately. Include zeros in the date series; never count transfers or corrections as income or expense. Remove plots and numeric accessibility values when the user's privacy setting is enabled.

Use blue/orange accents with theme-specific contrast: light `#1558D4` / `#B64A0B`, dark `#548CFF` / `#FF8836`. Use signs/labels, paired with numbers and volume direction. The Add control is a 52 dp circle with the dock's glass, a subtle blue tint, and a short accessible action label.

References: the owner's Tether Wallet screenshots, [Apple's guidance for glass materials](https://developer.apple.com/design/human-interface-guidelines/materials), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars?changes=la) and [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [TradingView chart examples](https://tradingview.github.io/lightweight-charts/examples), and [fl_chart](https://pub.dev/packages/fl_chart/versions/1.3.1). These guide arrangement and interaction; the implementation uses Oh My Esok's own UI and data.
