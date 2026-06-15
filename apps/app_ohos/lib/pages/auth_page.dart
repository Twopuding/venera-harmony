import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:venera/platform/ohos_platform_services.dart';
import 'package:venera/utils/translations.dart';

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
    var isAuthorized = await OhosLocalAuth.authenticate(
      localizedReason: "Please authenticate to continue".tl,
    );
    if (isAuthorized) {
      widget.onSuccessfulAuth?.call();
    }
  }
}
