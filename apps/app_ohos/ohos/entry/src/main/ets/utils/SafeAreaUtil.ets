import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SafeAreaUtil';
const DOMAIN: number = 0x0000;

export class SafeAreaUtil {
  static readonly KEY_TOP: string = 'app_safeAreaTop';
  static readonly KEY_BOTTOM: string = 'app_safeAreaBottom';
  private static listenerRegistered: boolean = false;

  static init(win: window.Window): void {
    win.setWindowLayoutFullScreen(true).then(() => {
      SafeAreaUtil.syncAvoidAreas(win);
      hilog.info(DOMAIN, TAG, 'Fullscreen layout enabled');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Fullscreen layout failed: ' + err.message);
      SafeAreaUtil.syncAvoidAreas(win);
    });

    if (!SafeAreaUtil.listenerRegistered) {
      win.on('avoidAreaChange', () => {
        SafeAreaUtil.syncAvoidAreas(win);
      });
      SafeAreaUtil.listenerRegistered = true;
    }
  }

  private static syncAvoidAreas(win: window.Window): void {
    const systemArea: window.AvoidArea =
      win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const top: number = px2vp(systemArea.topRect.height);
    const navArea: window.AvoidArea =
      win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const bottom: number = px2vp(navArea.bottomRect.height);

    AppStorage.setOrCreate(SafeAreaUtil.KEY_TOP, top);
    AppStorage.setOrCreate(SafeAreaUtil.KEY_BOTTOM, bottom);

    hilog.info(DOMAIN, TAG,
      'Safe area top=' + top.toString() + ' bottom=' + bottom.toString());
  }
}
