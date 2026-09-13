import { common } from '@kit.AbilityKit';
import { UIContext, Router, PromptAction, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'UiContextHolder';

/**
 * Central access point for UIContext-bound APIs.
 *
 * `getContext()` is deprecated since API 18 (use `UIContext.getHostContext()`).
 * Structs may call `this.getUIContext()` directly, but class member initializers
 * and non-component classes (RouterUtil, bridges, presenters) cannot, so they use
 * this holder instead: every ability registers its own context on create/foreground
 * and its main window's UIContext on window stage create.
 */
export class UiContextHolder {
  private static hostCtx: common.UIAbilityContext | null = null;
  private static uiCtx: UIContext | null = null;
  private static routerInst: Router | null = null;
  private static promptInst: PromptAction | null = null;

  static setHostContext(ctx: common.UIAbilityContext): void {
    UiContextHolder.hostCtx = ctx;
  }

  static init(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      UiContextHolder.bind(win.getUIContext());
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to bind UIContext: %{public}s', JSON.stringify(e));
    }
  }

  static bind(uiContext: UIContext): void {
    UiContextHolder.uiCtx = uiContext;
    UiContextHolder.routerInst = uiContext.getRouter();
    UiContextHolder.promptInst = uiContext.getPromptAction();
  }

  static uiContext(): UIContext | null {
    return UiContextHolder.uiCtx;
  }

  static router(): Router | null {
    return UiContextHolder.routerInst;
  }

  static promptAction(): PromptAction | null {
    return UiContextHolder.promptInst;
  }

  /** Returns the foreground ability context (same instance `getContext()` used to return). */
  static hostContext(): common.UIAbilityContext {
    if (UiContextHolder.hostCtx === null) {
      hilog.error(DOMAIN, TAG, 'hostContext() requested before any ability registered one');
    }
    return UiContextHolder.hostCtx as common.UIAbilityContext;
  }

  static showToast(message: string, duration: number = 2000): void {
    const p: PromptAction | null = UiContextHolder.promptInst;
    if (p === null) {
      hilog.error(DOMAIN, TAG, 'showToast() requested before UIContext was bound: %{public}s', message);
      return;
    }
    p.showToast({ message: message, duration: duration });
  }
}
