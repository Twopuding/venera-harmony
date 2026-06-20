import {
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';
import { HdsTheme } from '../design/HdsTheme';
import { RouterUtil } from '../navigation/RouterUtil';
import { ImmersiveScrollTopInset } from './ImmersiveScrollTopInset';
import { LoadingIndicator } from './LoadingIndicator';
import { AuthSessionGuard } from '../utils/AuthSessionGuard';

@Component
export struct ImmersivePageScaffold {
  @Prop title: string = ''
  @Prop titleMode: HdsNavigationTitleMode = HdsNavigationTitleMode.MINI
  @Prop showBack: boolean = true
  @Prop scrollable: boolean = true
  @Prop contentPaddingH: number = 16
  @Prop menus: HdsNavigationMenuContentOptions | undefined = undefined
  @Prop pageScroller: Scroller | undefined = undefined
  onBack: (() => void) | null = null
  @BuilderParam content: () => void = this._defaultContent
  @State authBlocked: boolean = false

  private internalScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.authBlocked = AuthSessionGuard.shouldBlock();
    if (this.authBlocked) {
      AuthSessionGuard.redirectIfNeeded();
    }
  }

  @Builder
  _defaultContent() {
  }

  private activeScroller(): Scroller {
    if (this.pageScroller !== undefined) {
      return this.pageScroller;
    }
    return this.internalScroller;
  }

  private handleBack(): void {
    if (this.onBack !== null) {
      this.onBack!();
    } else {
      RouterUtil.back();
    }
  }

  @Builder
  paddedContent() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding({ left: this.contentPaddingH, right: this.contentPaddingH })
  }

  @Builder
  navigationBody() {
    if (this.scrollable) {
      Scroll(this.activeScroller()) {
        Column() {
          ImmersiveScrollTopInset({ titleMode: this.titleMode })
          this.paddedContent()
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .clipContent(ContentClipMode.SAFE_AREA)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    } else {
      Column() {
        Column() {
          this.content()
        }
        .width('100%')
        .height('100%')
        .padding({ left: this.contentPaddingH, right: this.contentPaddingH })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
    }
  }

  private ignoreSafeAreaEdges(): Array<LayoutSafeAreaEdge> {
    if (this.titleMode === HdsNavigationTitleMode.MINI) {
      return [LayoutSafeAreaEdge.BOTTOM];
    }
    return [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM];
  }

  build() {
    if (this.authBlocked) {
      LoadingIndicator()
    } else if (this.scrollable || this.pageScroller !== undefined) {
      HdsNavigation() {
        this.navigationBody()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .mode(NavigationMode.Stack)
      .titleBar(HdsTheme.titleBarOptions(
        this.title,
        this.menus,
        this.showBack,
        () => this.handleBack(),
        this.titleMode
      ))
      .titleMode(this.titleMode)
      .hideBackButton(!this.showBack)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], this.ignoreSafeAreaEdges())
      .bindToScrollable([this.activeScroller()])
    } else {
      HdsNavigation() {
        this.navigationBody()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .mode(NavigationMode.Stack)
      .titleBar(HdsTheme.titleBarOptions(
        this.title,
        this.menus,
        this.showBack,
        () => this.handleBack(),
        this.titleMode
      ))
      .titleMode(this.titleMode)
      .hideBackButton(!this.showBack)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], this.ignoreSafeAreaEdges())
    }
  }
}
