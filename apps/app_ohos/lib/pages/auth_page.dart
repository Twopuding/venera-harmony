import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:venera/platform/ohos_platform_services.dart';
import 'package:venera/utils/translations.dart';
import 'package:venera/foundation/appdata.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.onSuccessfulAuth});

  final void Function()? onSuccessfulAuth;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(SchedulerBinding.instance.lifecycleState != AppLifecycleState.paused) {
        auth();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Material(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 36),
              const SizedBox(height: 16),
              Text("Authentication Required".tl),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: auth,
                child: Text("Continue".tl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void auth() async {
    var canCheckBiometrics = await OhosLocalAuth.canCheckBiometrics();
    if (!canCheckBiometrics && !await OhosLocalAuth.isDeviceSupported()) {
      widget.onSuccessfulAuth?.call();
      return;
    }
    String localizationReason = "Please authenticate to continue".tl;
    bool useFace = appdata.settings['useFaceAuth'] == true;
    bool useFp = appdata.settings['useFingerprintAuth'] == true;
    bool faceAvailable = await OhosLocalAuth.canCheckFace();
    bool fpAvailable = await OhosLocalAuth.canCheckFingerprint();
    bool isAuthorized = false;
    if (useFace && faceAvailable) {
      isAuthorized = await OhosLocalAuth.authenticateWithFace(
        localizedReason: localizationReason,
      );
    }
    if (!isAuthorized && useFp && fpAvailable) {
      isAuthorized = await OhosLocalAuth.authenticateWithFingerprint(
        localizedReason: localizationReason,
      );
    }
    if (!isAuthorized) {
      isAuthorized = await OhosLocalAuth.authenticateWithPin(
        localizedReason: localizationReason,
      );
    }
    if (isAuthorized) {
      widget.onSuccessfulAuth?.call();
    }
  }
}
