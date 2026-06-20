# HarmonyOS Native UI vs Flutter — Parity Report

**Date:** 2026-06-19 (parity implementation pass)  
**Scope:** `useNativeUi=true` (default)  
**Build:** `devecocli build` — **PASS**

## Summary

| Dimension | Before pass | After pass |
|-----------|-------------|------------|
| Page/route coverage | ~100% | **100%** |
| DataBridge methods | 81/81 | **83/83** (+`setReaderSetting`, +`setComicSpecificSettingsEnabled`) |
| Reader per-comic settings | Missing | **Implemented** (bridge + in-reader panel) |
| Reader chapter picker / share | Missing | **Implemented** |
| Chapter comments at end | Setting only | **Implemented** in gallery LR/RL |
| Follow updates UI | Single list | **Updated + All** sections, mark all read |
| Export formats | CBZ only | **CBZ / PDF / EPUB** picker |
| Comments rendering | Plain text | **RichCommentContent** (links, basic HTML) |
| i18n coverage | ~14 pages | **26+ pages** with TranslationUtil |
| Code editor | Plain TextArea | **CodeEditor** with line numbers |
| UI polish | Partial | Hero transition, favorite side sheet, image load bar |

## Completed in this pass

### P0 — Reader core
- `ReaderService.getSettings()` accepts `comicId`/`sourceKey`, merges per-comic/device settings via `getReaderSetting`
- Returns full field set: `limitImageWidth`, `preloadImageCount`, `quickCollectImage`, `readerScrollSpeed`, `longPressZoomPosition`, `showSystemStatusBar`, `showChapterCommentsAtEnd`, `comicSpecificEnabled`
- `ReaderBridge.onGetSettings(comicId, sourceKey)` wired end-to-end
- `ReaderPage`: chapter picker sheet, in-reader settings panel, share current page, chapter-comments-at-end virtual page
- New components: `ChapterPickerSheet.ets`, `ReaderSettingsPanel.ets`

### P1 — Library & follow updates
- `Comic.hasNewUpdate` / `updateTime` mapped in `DataService.toComic()`
- `FollowUpdatesPage`: Updated vs All sections, **Mark all as read**
- `LocalComicsPage` + `FavoritesPage`: export format dialog (cbz/pdf/epub)

### P2 — Comments & i18n
- `RichCommentContent.ets` for HTML links, bold/italic, URLs
- Used in `CommentsPage` and reader chapter-comments panel
- TranslationUtil on: Search*, MainShell, Comments, Local, Downloading, Logs, CategoryComics, ImageFavorites, etc.

### P3 — Editor & polish
- `CodeEditor.ets` with line numbers in `ComicSourceEditPage`
- `ComicTile` / `ComicDetailPage` cover `sharedTransition` (Hero-like)
- `ComicDetailPage` favorite picker as right-side sheet
- `ReaderImage` linear progress bar while loading

### Bridge additions
- `setReaderSetting`, `setComicSpecificSettingsEnabled` on DataBridge/DataService

## Remaining platform differences (not targeted)

- Desktop window management, mouse back button
- Clipboard image write (`venera/clipboard`)
- Real-time `imageProgress` EventChannel (native uses loading indicator + linear bar)
- Full syntax-highlighting parity with Flutter `CodeEditor` (line numbers + monospace implemented)

## Manual regression

Use [PARITY_CHECKLIST.md](./PARITY_CHECKLIST.md) with `devecocli run` on device/emulator.
