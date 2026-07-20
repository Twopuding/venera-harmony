import fs from 'fs'
import path from 'path'
import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { getNode } from '@ohos/hvigor'
import { flutterHvigorPlugin } from 'flutter-hvigor-plugin';

// Inject local signing from gitignored build-profile.json5.local at build time
// so branch switches do not wipe machine-specific cert paths/passwords.
const rootNode = getNode(__filename);
rootNode.afterNodeEvaluate(node => {
    const localSigningPath = path.join(__dirname, 'build-profile.json5.local');
    if (!fs.existsSync(localSigningPath)) {
        return;
    }

    let localSigning: { signingConfigs?: unknown };
    try {
        localSigning = JSON.parse(fs.readFileSync(localSigningPath, 'utf8'));
    } catch (e) {
        console.warn(`[signing] Failed to parse ${localSigningPath}: ${e}`);
        return;
    }

    if (!Array.isArray(localSigning.signingConfigs) || localSigning.signingConfigs.length === 0) {
        console.warn(`[signing] ${localSigningPath} has no signingConfigs; skipping inject`);
        return;
    }

    const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
    if (!appContext) {
        return;
    }

    const buildProfileOpt = appContext.getBuildProfileOpt();
    buildProfileOpt['app']['signingConfigs'] = localSigning.signingConfigs;
    appContext.setBuildProfileOpt(buildProfileOpt);
});

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[flutterHvigorPlugin(path.dirname(__dirname))]         /* Custom plugin to extend the functionality of Hvigor. */
}
