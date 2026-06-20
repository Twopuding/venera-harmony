import {
  hdsMaterial,
  HdsNavigationBackButtonItemOptions,
  HdsNavigationIconItemStyle,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleBarStyle,
  HdsNavigationTitleMode,
  HdsNavigationTitleStyle,
  HdsTitleBarContentStyle,
  ScrollEffectOptions,
  ScrollEffectType,
  SystemMaterialParams,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';

export class HdsTheme {
  static readonly TITLE_BAR_HEIGHT_MINI: number = 56;
  static readonly TITLE_BAR_HEIGHT_LARGE: number = 112;
  static readonly TITLE_BAR_HEIGHT_FREE: number = 138;
  static readonly SETTINGS_TITLE_MODE: HdsNavigationTitleMode = HdsNavigationTitleMode.FULL;
  static readonly SETTINGS_SUBPAGE_TITLE_MODE: HdsNavigationTitleMode = HdsNavigationTitleMode.MINI;

  static resolveTitleBarScrollInset(titleMode: HdsNavigationTitleMode): number {
    // MINI + enableComponentSafeArea: HdsNavigation already lays out content below the
    // title bar; an extra Blank would double the top gap on subpages.
    if (titleMode === HdsNavigationTitleMode.MINI) {
      return 0;
    }
    if (titleMode === HdsNavigationTitleMode.FULL) {
      return HdsTheme.TITLE_BAR_HEIGHT_LARGE;
    }
    if (titleMode === HdsNavigationTitleMode.FREE) {
      return HdsTheme.TITLE_BAR_HEIGHT_FREE;
    }
    return 0;
  }

  static needsScrollTopInset(titleMode: HdsNavigationTitleMode): boolean {
    return HdsTheme.resolveTitleBarScrollInset(titleMode) > 0;
  }

  static adaptiveMaterialEffect(): SystemMaterialParams {
    let effect: SystemMaterialParams = {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
    return effect;
  }

  static resolveMaterialLevel(): hdsMaterial.MaterialLevel {
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  static resolveScrollEffectType(): ScrollEffectType {
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      return ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
    }
    return ScrollEffectType.GRADIENT_BLUR;
  }

  static titleBarContentStyle(): HdsTitleBarContentStyle {
    let titleStyle: HdsNavigationTitleStyle = {
      mainTitleColor: $r('sys.color.font_primary'),
      subTitleColor: $r('sys.color.font_secondary')
    };
    let iconStyle: HdsNavigationIconItemStyle = {
      iconColor: $r('sys.color.icon_primary')
    };
    let contentStyle: HdsTitleBarContentStyle = {
      titleStyle: titleStyle,
      backIconStyle: iconStyle,
      menuStyle: iconStyle
    };
    return contentStyle;
  }

  static titleBarBarStyle(): HdsNavigationTitleBarStyle {
    let barStyle: HdsNavigationTitleBarStyle = {
      contentStyle: HdsTheme.titleBarContentStyle()
    };
    return barStyle;
  }

  static titleBarStyle(): TitleBarStyleOptions {
    let scrollOpts: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: HdsTheme.resolveScrollEffectType()
    };
    let barStyle: HdsNavigationTitleBarStyle = HdsTheme.titleBarBarStyle();
    let style: TitleBarStyleOptions = {
      scrollEffectOpts: scrollOpts,
      systemMaterialEffect: HdsTheme.adaptiveMaterialEffect(),
      originalStyle: barStyle,
      scrollEffectStyle: barStyle
    };
    return style;
  }

  static titleBarOptions(
    title: string,
    menu: HdsNavigationMenuContentOptions | undefined,
    showBack: boolean,
    onBack: () => void,
    titleMode: HdsNavigationTitleMode = HdsNavigationTitleMode.MINI
  ): HdsNavigationTitleBarOptions {
    let content: TitleBarContentOptions = {
      title: {
        mainTitle: title
      }
    };
    if (menu !== undefined) {
      content.menu = menu;
    }
    if (showBack) {
      let backIcon: HdsNavigationBackButtonItemOptions = {
        action: onBack
      };
      content.backIcon = backIcon;
    }
    let isMiniTitle: boolean = titleMode === HdsNavigationTitleMode.MINI;
    let options: HdsNavigationTitleBarOptions = {
      content: content,
      style: HdsTheme.titleBarStyle(),
      avoidLayoutSafeArea: isMiniTitle,
      enableComponentSafeArea: isMiniTitle
    };
    return options;
  }

  static cardBlurStyle(): BlurStyle {
    return BlurStyle.COMPONENT_ULTRA_THICK;
  }

  static thickBlurStyle(): BlurStyle {
    return BlurStyle.COMPONENT_THICK;
  }

  static titleBarBlurStyle(): BlurStyle {
    return BlurStyle.BACKGROUND_THICK;
  }

  static iconButtonBlurStyle(): BlurStyle {
    return BlurStyle.BACKGROUND_THIN;
  }
}
