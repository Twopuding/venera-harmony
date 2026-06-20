import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';

export interface NavigationMenuEntry {
  icon: Resource;
  label: string;
  action: () => void;
}

interface NavigationMenuItemContent {
  label: string;
  icon: Resource;
  action: () => void;
}

interface NavigationMenuItem {
  content: NavigationMenuItemContent;
}

export class NavigationMenus {
  static single(icon: Resource, label: string, action: () => void): HdsNavigationMenuContentOptions {
    return NavigationMenus.fromEntries([{ icon: icon, label: label, action: action }]);
  }

  static fromEntries(entries: NavigationMenuEntry[]): HdsNavigationMenuContentOptions {
    let items: NavigationMenuItem[] = [];
    for (let i: number = 0; i < entries.length; i++) {
      let entry: NavigationMenuEntry = entries[i];
      let item: NavigationMenuItem = {
        content: {
          label: entry.label,
          icon: entry.icon,
          action: entry.action
        }
      };
      items.push(item);
    }
    return { value: items };
  }
}
