import { HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HdsTheme } from '../design/HdsTheme';

@Component
export struct ImmersiveScrollTopInset {
  @Prop titleMode: HdsNavigationTitleMode = HdsNavigationTitleMode.MINI

  build() {
    if (HdsTheme.needsScrollTopInset(this.titleMode)) {
      Blank()
        .height(HdsTheme.resolveTitleBarScrollInset(this.titleMode))
        .width('100%')
    }
  }
}
