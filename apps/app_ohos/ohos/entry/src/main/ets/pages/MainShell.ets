import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsTheme } from '../design/HdsTheme';
import { HomePage } from './home/HomePage';
import { DataService } from '../service/DataService';

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

@Component
export struct MainShell {
  private scroller: Scroller = new Scroller();
  private tabsController: HdsTabsController = new HdsTabsController();
  @State currentTab: number = 0;
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  aboutToAppear(): void {
    this.materialLevel = HdsTheme.resolveMaterialLevel();
    DataService.getInstance().getSettings().then((settings: Record<string, Object>) => {
      let initialPage: string = settings['initialPage']?.toString() ?? '0';
      let index: number = parseInt(initialPage);
      if (!isNaN(index) && index >= 0 && index < SHELL_TABS.length) {
        this.currentTab = index;
        this.tabsController.changeIndex(index);
      }
    });
  }

  @Builder
  tabContent(index: number) {
    if (index === 0) {
      HomePage()
    } else {
      Column() {
        Text(SHELL_TABS[index].label)
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.tabsController, index: this.currentTab }) {
        ForEach(SHELL_TABS, (tab: ShellTab, index: number) => {
          TabContent() {
            Stack() {
              Scroll(this.scroller) {
                Column() {
                  this.tabContent(index)
                }
                .width('100%')
              }
              .clipContent(ContentClipMode.SAFE_AREA)
              .width('100%')
              .height('100%')
            }
          }
          .tabBar(new BottomTabBarStyle({
            normal: tab.normalIcon,
            selected: tab.selectedIcon
          }, tab.label))
        }, (tab: ShellTab, index: number) => index.toString())
      }
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .barFloatingStyle({
        barBottomMargin: 28,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.materialLevel
        }
      })
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: {
          mainTitle: 'Venera',
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.materialLevel
        },
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    })
    .bindToScrollable([this.scroller])
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
