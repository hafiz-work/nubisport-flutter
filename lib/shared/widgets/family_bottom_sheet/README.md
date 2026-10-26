# family_bottom_sheet (vendored)

Salinan tempatan pakej [family_bottom_sheet 0.1.0](https://pub.dev/packages/family_bottom_sheet)
(MIT, © 2025 Daniel Olayinka) — <https://github.com/danielkiing3/family_bottom_sheet>.

Disalin masuk supaya kita boleh ubah tanpa fork/publish. Fail `LICENSE` asal
dikekalkan.

## Perubahan tempatan

- Betulkan lint `prefer_initializing_formals` pada `_RenderBottomSheetLayoutWithSizeListener`.
- Dispose `_pageIndexNotifier` dalam `FamilyModalSheetState` (elak memory leak).
- `showMaterialDefault` kini delegate kepada `show` (buang kod pendua; tingkah laku sama).
- Kemas susunan import dan jadikan nilai animation default `const`.

## Guna dalam app

```dart
final confirmed = await FamilyModalSheet.showMaterialDefault<bool>(
  context: context,
  contentBackgroundColor: Theme.of(context).colorScheme.surface,
  mainContentBorderRadius: BorderRadius.vertical(
    top: Radius.circular(AppTheme.radius),
  ),
  showDragHandle: true,
  builder: (sheetContext) => ...,
);
```

Contoh sebenar: dialog log keluar dalam `lib/features/profile/profile_page.dart`.

## Naik taraf

Banding dengan versi upstream sebelum tarik perubahan baru. Jangan ubah API awam
tanpa kemas kini semua pemanggil dalam `lib/`.
