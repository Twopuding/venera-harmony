import { HdsTheme } from '../design/HdsTheme';

export const SETTINGS_ROW_PADDING_H: number = 16;
export const SETTINGS_ICON_ROW_DIVIDER_START: number = 64;
export const SETTINGS_ROW_HEIGHT_SINGLE: number = 56;
export const SETTINGS_ROW_HEIGHT_MULTI: number = 72;
export const SETTINGS_TITLE_FONT_SIZE: number = 16;
export const SETTINGS_SUBTITLE_FONT_SIZE: number = 14;
export const SETTINGS_VALUE_FONT_SIZE: number = 14;
export const SETTINGS_SECTION_TITLE_FONT_SIZE: number = 14;
export const SETTINGS_CHEVRON_FONT_SIZE: number = 12;

@Component
export struct SettingsListDivider {
  @Prop startMargin: number = SETTINGS_ROW_PADDING_H
  @Prop endMargin: number = SETTINGS_ROW_PADDING_H

  build() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: this.startMargin, right: this.endMargin })
  }
}

@Component
export struct SettingTile {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop showDivider: boolean = true
  @BuilderParam trailing: () => void = this._defaultTrailing
  onTap: (() => void) | null = null

  @Builder
  _defaultTrailing() {
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(SETTINGS_TITLE_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(SETTINGS_SUBTITLE_FONT_SIZE)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.trailing()
      }
      .width('100%')
      .height(this.subtitle.length > 0 ? SETTINGS_ROW_HEIGHT_MULTI : SETTINGS_ROW_HEIGHT_SINGLE)
      .padding({ left: SETTINGS_ROW_PADDING_H, right: SETTINGS_ROW_PADDING_H })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.onTap !== null) {
          this.onTap!();
        }
      })
      if (this.showDivider) {
        SettingsListDivider()
      }
    }
    .width('100%')
  }
}

@Component
export struct SettingsSection {
  @Prop title: string = ''
  @BuilderParam content: () => void = this.emptyContent

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(SETTINGS_SECTION_TITLE_FONT_SIZE)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding({ left: SETTINGS_ROW_PADDING_H, top: 4, bottom: 8 })
      }
      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(20)
      .backgroundBlurStyle(HdsTheme.cardBlurStyle())
      .margin({ bottom: 12 })
    }
    .width('100%')
  }
}

@Component
export struct CategoryNavTile {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop icon: Resource = $r('sys.symbol.gearshape')
  @Prop iconColor: ResourceColor = '#317AF7'
  @Prop showDivider: boolean = true
  onTap: (() => void) | null = null

  build() {
    Column() {
      Row() {
        Row() {
          SymbolGlyph(this.icon)
            .fontSize(18)
            .fontColor([Color.White])
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.iconColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column() {
          Text(this.title)
            .fontSize(SETTINGS_TITLE_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(SETTINGS_SUBTITLE_FONT_SIZE)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(SETTINGS_CHEVRON_FONT_SIZE)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .height(this.subtitle.length > 0 ? SETTINGS_ROW_HEIGHT_MULTI : SETTINGS_ROW_HEIGHT_SINGLE)
      .padding({ left: SETTINGS_ROW_PADDING_H, right: SETTINGS_ROW_PADDING_H })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.onTap !== null) {
          this.onTap!();
        }
      })

      if (this.showDivider) {
        SettingsListDivider({ startMargin: SETTINGS_ICON_ROW_DIVIDER_START })
      }
    }
    .width('100%')
  }
}

@Component
export struct SwitchSettingTile {
  @Prop @Watch('onValueChanged') value: boolean = false
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop showDivider: boolean = true
  @State isOn: boolean = false
  onChange: ((value: boolean) => void) | null = null

  aboutToAppear(): void {
    this.isOn = this.value;
  }

  onValueChanged(): void {
    this.isOn = this.value;
  }

  @LocalBuilder
  switchTrailing() {
    Toggle({ type: ToggleType.Switch, isOn: this.isOn })
      .onChange((isOn: boolean) => {
        this.isOn = isOn;
        if (this.onChange !== null) {
          this.onChange!(isOn);
        }
      })
  }

  build() {
    SettingTile({
      title: this.title,
      subtitle: this.subtitle,
      showDivider: this.showDivider,
      trailing: this.switchTrailing
    })
  }
}

@Component
export struct SelectSettingTile {
  @Prop title: string = ''
  @Prop valueLabel: string = ''
  @Prop showDivider: boolean = true
  onTap: (() => void) | null = null

  @LocalBuilder
  valueTrailing() {
    Row() {
      Text(this.valueLabel)
        .fontSize(SETTINGS_VALUE_FONT_SIZE)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 140 })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(SETTINGS_CHEVRON_FONT_SIZE)
        .fontColor([$r('sys.color.icon_tertiary')])
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    SettingTile({
      title: this.title,
      showDivider: this.showDivider,
      trailing: this.valueTrailing,
      onTap: this.onTap
    })
  }
}

@Component
export struct SliderSettingTile {
  @Prop title: string = ''
  @Prop value: number = 0
  @Prop min: number = 0
  @Prop max: number = 1
  @Prop step: number = 0.05
  @Prop showDivider: boolean = true
  onChange: ((value: number) => void) | null = null

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(SETTINGS_TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(this.value.toFixed(this.step < 1 ? 2 : 0))
          .fontSize(SETTINGS_VALUE_FONT_SIZE)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(SETTINGS_ROW_HEIGHT_SINGLE)
      .padding({ left: SETTINGS_ROW_PADDING_H, right: SETTINGS_ROW_PADDING_H })
      .alignItems(VerticalAlign.Center)
      Slider({
        value: this.value,
        min: this.min,
        max: this.max,
        step: this.step
      })
        .width('100%')
        .margin({ left: SETTINGS_ROW_PADDING_H, right: SETTINGS_ROW_PADDING_H, bottom: 12 })
        .onChange((v: number) => {
          if (this.onChange !== null) {
            this.onChange!(v);
          }
        })
      if (this.showDivider) {
        SettingsListDivider()
      }
    }
    .width('100%')
  }
}

@Component
export struct ActionSettingTile {
  @Prop title: string = ''
  @Prop actionLabel: string = ''
  @Prop showDivider: boolean = true
  onAction: (() => void) | null = null

  @LocalBuilder
  actionTrailing() {
    Row() {
      if (this.actionLabel.length > 0) {
        Text(this.actionLabel)
          .fontSize(SETTINGS_VALUE_FONT_SIZE)
          .fontColor($r('sys.color.font_emphasize'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 120 })
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(SETTINGS_CHEVRON_FONT_SIZE)
        .fontColor([$r('sys.color.icon_tertiary')])
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    SettingTile({
      title: this.title,
      showDivider: this.showDivider,
      trailing: this.actionTrailing,
      onTap: this.onAction
    })
  }
}
