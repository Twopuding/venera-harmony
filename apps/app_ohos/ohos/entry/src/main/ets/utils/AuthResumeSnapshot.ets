import { hilog } from '@kit.PerformanceAnalysisKit';
import { AUTH_SESSION_VALID_KEY } from './AuthLifecycleUtil';
import { AuthGatePresenter } from './AuthGatePresenter';
import { RouterUtil } from '../navigation/RouterUtil';

const TAG: string = 'AuthResumeSnapshot';
const DOMAIN: number = 0x0000;
const INDEX_PAGE_URL: string = 'pages/Index';
const AUTH_PAGE_URL: string = 'pages/AuthPage';
export const AUTH_RESUME_SNAPSHOT_KEY: string = 'authResumeSnapshot';
export const SHELL_CURRENT_TAB_KEY: string = 'shellCurrentTab';
export const SHELL_RESTORE_TAB_KEY: string = 'shellRestoreTab';

export interface AuthShellSnapshot {
  kind: 'shell';
  shellTab: number;
}

export interface AuthRouterSnapshot {
  kind: 'router';
  url: string;
  params?: Object;
  shellTab?: number;
}

export type AuthSnapshotData = AuthShellSnapshot | AuthRouterSnapshot;

export class AuthResumeSnapshot {
  static save(): void {
    let sessionValid: boolean = AppStorage.get<boolean>(AUTH_SESSION_VALID_KEY) ?? false;
    if (!sessionValid) {
      hilog.info(DOMAIN, TAG, 'skip save, session invalid');
      return;
    }

    let shellTab: number = AppStorage.get<number>(SHELL_CURRENT_TAB_KEY) ?? 0;
    let snapshot: AuthSnapshotData;
    let state = AuthGatePresenter.readRouterState();

    if (state !== null) {
      let path: string = state.path ?? '';
      let index: number = state.index ?? 0;
      if (index > 0 && path.length > 0 && path !== AUTH_PAGE_URL) {
        snapshot = {
          kind: 'router',
          url: path,
          params: state.params,
          shellTab: shellTab
        };
        AppStorage.setOrCreate<string>(AUTH_RESUME_SNAPSHOT_KEY, JSON.stringify(snapshot));
        hilog.info(DOMAIN, TAG, 'saved router index=%{public}d url=%{public}s', index, path);
        return;
      }
      if (path.length > 0 && path !== INDEX_PAGE_URL && path !== AUTH_PAGE_URL) {
        snapshot = {
          kind: 'router',
          url: path,
          params: state.params,
          shellTab: shellTab
        };
        AppStorage.setOrCreate<string>(AUTH_RESUME_SNAPSHOT_KEY, JSON.stringify(snapshot));
        hilog.info(DOMAIN, TAG, 'saved router url=%{public}s', path);
        return;
      }
    }

    let tracked = RouterUtil.readRouteTop();
    if (tracked !== null && tracked.url.length > 0 &&
      tracked.url !== INDEX_PAGE_URL && tracked.url !== AUTH_PAGE_URL) {
      snapshot = {
        kind: 'router',
        url: tracked.url,
        params: tracked.params,
        shellTab: shellTab
      };
      AppStorage.setOrCreate<string>(AUTH_RESUME_SNAPSHOT_KEY, JSON.stringify(snapshot));
      hilog.info(DOMAIN, TAG, 'saved router from track url=%{public}s', tracked.url);
      return;
    }

    snapshot = { kind: 'shell', shellTab: shellTab };
    AppStorage.setOrCreate<string>(AUTH_RESUME_SNAPSHOT_KEY, JSON.stringify(snapshot));
    hilog.info(DOMAIN, TAG, 'saved shell tab=%{public}d', shellTab);
  }

  static consume(): AuthSnapshotData | null {
    let raw: string | undefined = AppStorage.get<string>(AUTH_RESUME_SNAPSHOT_KEY);
    if (raw === undefined || raw.length === 0) {
      return null;
    }
    AppStorage.delete(AUTH_RESUME_SNAPSHOT_KEY);
    try {
      let data = JSON.parse(raw) as AuthSnapshotData;
      if (data.kind === 'shell' || data.kind === 'router') {
        return data;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'consume parse failed: %{public}s', JSON.stringify(err));
    }
    return null;
  }
}
