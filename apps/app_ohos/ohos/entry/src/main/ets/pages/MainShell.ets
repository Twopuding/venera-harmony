import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import display from '@ohos.display';
import { HomePage } from './home/HomePage';
import { ExplorePage } from './explore/ExplorePage';
import { FavoritesPage } from './favorites/FavoritesPage';
import { CategoriesPage } from './categories/CategoriesPage';
import { DataService } from '../service/DataService';
import { HdsTheme } from '../design/HdsTheme.ets';
import { RouterUtil } from '../navigation/RouterUtil.ets';
import { ShellEvents } from '../utils/ShellEvents';
import { TranslationUtil } from '../utils/TranslationUtil';
import { SafeAreaUtil } from '../utils/SafeAreaUtil';
import { LoadingIndicator } from '../components/LoadingIndicator';
import {
  SHELL_CURRENT_TAB_KEY,
  SHELL_RESTORE_TAB_KEY
} from '../utils/AuthResumeSnapshot';

interface ShellTab {
  label: string;
  normalIcon: SymbolGlyphModifier;
  selectedIcon: SymbolGlyphModifier;
}

const SHELL_TABS: ShellTab[] = [
  {
    label: 'Home',
    normalIcon: new SymbolGlyphModifier($r('sys.symbol.house'))
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off')]),
    selectedIcon: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
      .fontColor([$r('sys.color.ohos_id_color_activated')])
  },
  {
    label: 'Favorites',
    normalIcon: new SymbolGlyphModifier($r('sys.symbol.bookmark'))
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off')]),
    selectedIcon: new SymbolGlyphModifier($r('sys.symbol.bookmark_fill'))
      .fontColor([$r('sys.color.ohos_id_color_activated')])
  },
  {
    label: 'Explore',
    normalIcon: new SymbolGlyphModifier($r('sys.symbol.compass'))
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off')]),
    selectedIcon: new SymbolGlyphModifier($r('sys.symbol.compass'))
      .fontColor([$r('sys.color.ohos_id_color_activated')])
  },
  {
    label: 'Categories',
    normalIcon: new SymbolGlyphModifier($r('sys.symbol.square_grid_2x2'))
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off')]),
    selectedIcon: new SymbolGlyphModifier($r('sys.symbol.square_grid_2x2'))
      .fontColor([$r('sys.color.ohos_id_color_activated')])
  }
];

const WIDE_SHELL_WIDTH: number = 600;

@Component
export struct MainShell {
  private tabsController: HdsTabsController = new HdsTabsController();
  @State currentTab: number = 0;
  @State isWide: boolean = false;
  @State tabHomeMounted: boolean = true;
  @State tabFavoritesMounted: boolean = false;
  @State tabExploreMounted: boolean = false;
  @State tabCategoriesMounted: boolean = false;
  @State shellReady: boolean = false;
  private skipInitialPage: boolean = false;
  @StorageLink(TranslationUtil.I18N_TICK) i18nTick: number = 0;
  @StorageLink(SafeAreaUtil.KEY_TOP) safeAreaTop: number = 0;
  @StorageLink(SafeAreaUtil.KEY_BOTTOM) safeAreaBottom: number = 0;
  private context = getContext(this);

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    let restoreTab: number | undefined = AppStorage.get<number>(SHELL_RESTORE_TAB_KEY);
    if (restoreTab !== undefined && restoreTab >= 0 && restoreTab < SHELL_TABS.length) {
      AppStorage.delete(SHELL_RESTORE_TAB_KEY);
      this.skipInitialPage = true;
      this.restoreShellTab(restoreTab);
    } else {
      AppStorage.setOrCreate<number>(SHELL_CURRENT_TAB_KEY, this.currentTab);
    }
    TranslationUtil.ensureLoaded(this.context).then(() => {
      this.shellReady = true;
    });
    AppStorage.setOrCreate(ShellEvents.EXPLORE_SCROLL_TOP, 0);
    AppStorage.setOrCreate(ShellEvents.CATEGORIES_SCROLL_TOP, 0);
    AppStorage.setOrCreate(ShellEvents.EXPLORE_ADD_PAGE, 0);
    AppStorage.setOrCreate(ShellEvents.CATEGORIES_ADD_PAGE, 0);
    AppStorage.setOrCreate(ShellEvents.HOME_RELOAD, 0);
    this.updateLayout();
    if (!this.skipInitialPage) {
      DataService.getInstance().getSettings().then((settings: Record<string, Object>) => {
        let initialPage: string = settings['initialPage']?.toString() ?? '0';
        let index: number = parseInt(initialPage);
        if (!isNaN(index) && index >= 0 && index < SHELL_TABS.length) {
          this.restoreShellTab(index);
        }
      });
    }
  }

  private restoreShellTab(tab: number): void {
    this.currentTab = tab;
    this.tabsController.changeIndex(tab);
    this.markTabMounted(tab);
    AppStorage.setOrCreate<number>(SHELL_CURRENT_TAB_KEY, tab);
  }

  private updateLayout(): void {
    try {
      let d = display.getDefaultDisplaySync();
      this.isWide = d.width / d.densityPixels > WIDE_SHELL_WIDTH;
    } catch (e) {
      this.isWide = false;
    }
  }

  private markTabMounted(index: number): void {
    if (index === 0) {
      this.tabHomeMounted = true;
    } else if (index === 1) {
      this.tabFavoritesMounted = true;
    } else if (index === 2) {
      this.tabExploreMounted = true;
    } else if (index === 3) {
      this.tabCategoriesMounted = true;
    }
  }

  private selectTab(index: number): void {
    if (this.currentTab === index) {
      this.onTabRetap(index);
    } else {
      this.currentTab = index;
      this.tabsController.changeIndex(index);
      this.markTabMounted(index);
      AppStorage.setOrCreate<number>(SHELL_CURRENT_TAB_KEY, index);
    }
  }

  private onTabRetap(index: number): void {
    if (index === 2) {
      ShellEvents.bumpCounter(ShellEvents.EXPLORE_SCROLL_TOP);
    } else if (index === 3) {
      ShellEvents.bumpCounter(ShellEvents.CATEGORIES_SCROLL_TOP);
    }
  }

  private tabIconRes(index: number, selected: boolean): Resource {
    if (index === 0) {
      return selected ? $r('sys.symbol.house_fill') : $r('sys.symbol.house');
    }
    if (index === 1) {
      return selected ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark');
    }
    if (index === 2) {
      return $r('sys.symbol.compass');
    }
    return $r('sys.symbol.square_grid_2x2');
  }

  @Builder
  tabContent(index: number) {
    if (index === 0 && this.tabHomeMounted) {
      HomePage()
    } else if (index === 1 && this.tabFavoritesMounted) {
      FavoritesPage()
    } else if (index === 2 && this.tabExploreMounted) {
      ExplorePage()
    } else if (index === 3 && this.tabCategoriesMounted) {
      CategoriesPage()
    }
  }

  @Builder
  shellHeader() {
    Row() {
      Text('Venera')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      if (this.currentTab !== 0) {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => RouterUtil.openSearch())
      }
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => RouterUtil.openSettings())
    }
    .width('100%')
    .height(56 + this.safeAreaTop)
    .padding({ left: 16, right: 8, top: this.safeAreaTop })
    .backgroundBlurStyle(HdsTheme.cardBlurStyle())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  sideNavItem(tab: ShellTab, index: number) {
    Column() {
      SymbolGlyph(this.tabIconRes(index, index === this.currentTab))
        .fontSize(22)
        .fontColor([index === this.currentTab ?
          $r('app.color.color_emphasize') : $r('app.color.text_secondary')])
      Text(this.tr(tab.label))
        .fontSize(11)
        .fontColor(index === this.currentTab ?
          $r('app.color.color_emphasize') : $r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => this.selectTab(index))
  }

  @Builder
  wideShell() {
    Row() {
      Column() {
        ForEach(SHELL_TABS, (tab: ShellTab, index: number) => {
          this.sideNavItem(tab, index)
        }, (tab: ShellTab, index: number) => index.toString())
      }
      .width(88)
      .height('100%')
      .backgroundBlurStyle(HdsTheme.cardBlurStyle())
      .border({ width: { right: 0.6 }, color: $r('app.color.card_border') })

      Column() {
        this.shellHeader()
        Column() {
          this.tabContent(this.currentTab)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  compactShell() {
    Column() {
      this.shellHeader()
      HdsTabs({
        barPosition: BarPosition.End,
        controller: this.tabsController,
        index: this.currentTab
      }) {
        ForEach(SHELL_TABS, (tab: ShellTab, index: number) => {
          TabContent() {
            Column() {
              this.tabContent(index)
            }
            .width('100%')
            .height('100%')
          }
          .tabBar(new BottomTabBarStyle({
            normal: tab.normalIcon,
            selected: tab.selectedIcon
          }, this.tr(tab.label)))
        }, (tab: ShellTab, index: number) => index.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .barMode(BarMode.Fixed)
      .barOverlap(true)
      .vertical(false)
      .barFloatingStyle({
        barBottomMargin: this.safeAreaBottom > 0 ? this.safeAreaBottom + 8 : 8,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: HdsTheme.resolveMaterialLevel()
        }
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .onChange((index: number) => {
        if (this.currentTab === index) {
          this.onTabRetap(index);
        }
        this.currentTab = index;
        this.markTabMounted(index);
        AppStorage.setOrCreate<number>(SHELL_CURRENT_TAB_KEY, index);
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (!this.shellReady) {
        LoadingIndicator()
      } else if (this.isWide) {
        this.wideShell()
      } else {
        this.compactShell()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange(() => {
      this.updateLayout();
    })
  }
}
