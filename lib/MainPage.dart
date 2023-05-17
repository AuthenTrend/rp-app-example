import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:http/http.dart' as http;
import 'package:localization/localization.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_passkey/flutter_passkey.dart';


import 'Config.dart';
import 'Extensions.dart';

class MainPage extends StatefulWidget {

  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  static const DEEP_LINK_SCHEME = "rpapp";
  String? _sessionToken = null;
  bool get _isLoggedIn => (_sessionToken != null);
  bool _isSignUp = false;
  StreamSubscription? _uriLinkSub;
  StreamSubscription<BrowserEvent>? _browserEvents;
  bool _isBrowserOpened = false;
  final ValueNotifier<Uri?> _browserResponse = ValueNotifier(null);
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ValueNotifier<bool> _isPlatformAuthenticatorPreferred = ValueNotifier(true);
  final ValueNotifier<bool> _isCrossPlatformAuthenticatorPreferred = ValueNotifier(false);

  void _showAbout() async {
    PackageInfo.fromPlatform().then((packageInfo) {
      var version = packageInfo.version;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
              title: Text('app_name'.i18n(), textAlign: TextAlign.center),
              content: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      style: const TextStyle(fontSize: 16),
                      text: '${'version'.i18n()} $version\n\n${'copyleft'.i18n()}\n\n\n',
                    ),
                    TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.blue),
                      text: 'website_url'.i18n(),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () { launchUrlString('website_url'.i18n(), mode: LaunchMode.externalApplication); },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('ok'.i18n())
                ),
              ],
            );
          });
    });
  }

  void _showConfig() async {
    Future.wait([
      PlatformExt.osVersion,
      Config.isPasskeyEnabled,
      Config.isPasskeySupported
    ]).then((value) {
      String osVersion = value[0] as String;
      bool isPasskeyEnabled = value[1] as bool;
      bool isPasskeySupported = value[2] as bool;
      ValueNotifier<bool> pkSwitch = ValueNotifier(isPasskeyEnabled);
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
              title: Text('configurations'.i18n(), textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${'os'.i18n()}: $osVersion'),
                  ValueListenableBuilder<bool>(
                    valueListenable: pkSwitch,
                    builder: (context, currentState, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text('Passkey', style: (isPasskeySupported ? null : const TextStyle(color: Colors.grey))),
                          Switch(
                            value: currentState,
                            inactiveThumbColor: isPasskeySupported ? null : Colors.grey,
                            inactiveTrackColor: isPasskeySupported ? null : Colors.grey,
                            onChanged: isPasskeySupported ? (value) {
                              pkSwitch.value = value;
                              Config.setPasskeyEnabled(value);
                            } : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const Text('Authenticator Attachment'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _isPlatformAuthenticatorPreferred,
                        builder: (context, currentState, child) {
                          return TextButton(
                            onPressed: () {
                              _isPlatformAuthenticatorPreferred.value = !_isPlatformAuthenticatorPreferred.value;
                              if (_isPlatformAuthenticatorPreferred.value) {
                                _isCrossPlatformAuthenticatorPreferred.value = false;
                              }
                            },
                            style: ButtonStyle(
                              backgroundColor: currentState ? MaterialStateProperty.all(Colors.white) : null,
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                                  side: BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                            child: const Text('platform'),
                          );
                        },
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isCrossPlatformAuthenticatorPreferred,
                        builder: (context, currentState, child) {
                          return TextButton(
                            onPressed: () {
                              _isCrossPlatformAuthenticatorPreferred.value = !_isCrossPlatformAuthenticatorPreferred.value;
                              if (_isCrossPlatformAuthenticatorPreferred.value) {
                                _isPlatformAuthenticatorPreferred.value = false;
                              }
                            },
                            style: ButtonStyle(
                              backgroundColor: currentState ? MaterialStateProperty.all(Colors.white) : null,
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                                  side: BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                            child: const Text('cross-platform'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: Text('ok'.i18n())
                ),
              ],
            );
          });
    });
  }

  void _showDialog(String message, {Function()? onOkPressed, Function()? onCancelPressed}) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
            content: Text(message, textAlign: TextAlign.center),
            contentPadding: const EdgeInsets.only(top: 30),
            actions: [
              TextButton(
                child: Text('cancel'.i18n()),
                onPressed: () {
                  Navigator.pop(context);
                  if (onCancelPressed != null) { onCancelPressed(); }
                },
              ),
              TextButton(
                child: Text('ok'.i18n()),
                onPressed: () {
                  Navigator.pop(context);
                  if (onOkPressed != null) { onOkPressed(); }
                },
              ),
            ],
          );
        });
  }

  Future<void> _saveSessionToken(String token) async {
    await Config.save('session_token', token);
  }

  Future<String?> _loadSessionToken() async {
    return Config.load('session_token');
  }

  Future<void> _clearSessionToken() async {
    await Config.remove('session_token');
  }

  Future<Map> _handleBrowserResponse(Uri uri) async {
    const scheme = DEEP_LINK_SCHEME;
    const METHOD_SIGN_UP = 'signup';
    const METHOD_SIGN_IN = 'signin';
    const METHOD_REGISTER_KEY = 'registerkey';
    if (uri.scheme != scheme) {
      return {'status': 'fail', 'msg': "unknown_uri".i18n()};
    }
    final method = uri.host;
    if (method != METHOD_SIGN_UP && method != METHOD_SIGN_IN && method != METHOD_REGISTER_KEY) {
      return {'status': 'fail', 'msg': "invalid_response".i18n()};
    }
    final resp = uri.queryParameters['resp'];
    if (resp == null) {
      return {'status': 'fail', 'msg': "invalid_response".i18n()};
    }
    final jsonStr = resp.base64UrlDecode();
    "resp: $jsonStr".log();
    Map map = json.decode(jsonStr);
    return map;
  }

  Future<Map> _openBrowser(Uri uri) {
    'Open ${uri.toString()}'.log();
    Completer<Map> completer = Completer();
    _browserResponse.value = null;
    var responseListener;
    listener() async {
      Uri? uri = _browserResponse.value;
      if (uri == null) { return; }
      Map map = await _handleBrowserResponse(uri);
      completer.complete(map);
      _browserResponse.removeListener(responseListener);
    }
    responseListener = listener;
    _browserResponse.addListener(responseListener);
    _isBrowserOpened = true;
    FlutterWebBrowser.openWebPage(
      url: uri.toString(),
      customTabsOptions: const CustomTabsOptions(
        shareState: CustomTabsShareState.on,
        instantAppsEnabled: true,
        showTitle: false,
        urlBarHidingEnabled: true,
      ),
      // FIXME: if using UIModalPresentationStyle.pageSheet and dragging down to close the browser, the close event will never be received.
      safariVCOptions: const SafariViewControllerOptions(
        barCollapsingEnabled: true,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        modalPresentationCapturesStatusBarAppearance: true,
        modalPresentationStyle: UIModalPresentationStyle.blurOverFullScreen,
      ),
    );
    return completer.future;
  }

  /// Handle incoming links - the ones that the app will receive from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _uriLinkSub = uriLinkStream.listen((Uri? uri) {
        if (uri == null || !mounted) return;
        'Incoming URI: $uri'.log();
        if (_isBrowserOpened) FlutterWebBrowser.close();
        Future.delayed(const Duration(seconds: 0), () => _browserResponse.value = uri);
      }, onError: (Object err) {
        'Error: $err'.log();
      });
    }
  }

  Future<Map> _signUp(String username, String? password) async {
    username = username.trim();
    bool isPwLess = (password == null);
    if (username.isNotEmpty && !username.isValidEmail()) {
      return {'status': 'fail', 'msg': "username_must_be_email".i18n()};
    }
    if (!isPwLess && username.isEmpty) {
      return {'status': 'fail', 'msg': "username_cant_be_empty".i18n()};
    }
    if (!isPwLess && password.isEmpty) {
      return {'status': 'fail', 'msg': "pw_cant_be_empty".i18n()};
    }

    bool isPasskeyEnabled = await Config.isPasskeyEnabled;
    if (isPwLess && !isPasskeyEnabled) {
      Map<String, String> params = {'m': 'signup', 'u': username, 'r': DEEP_LINK_SCHEME};
      if (_isPlatformAuthenticatorPreferred.value || _isCrossPlatformAuthenticatorPreferred.value) {
        params['at'] = _isPlatformAuthenticatorPreferred.value ? 'platform' : 'cross-platform';
      }
      return _openBrowser(Uri.https(Config.rpHostName, "/mindex.html", params));
    }

    Map<String, String> params = {'u': username};
    if (isPwLess) {
      if (_isPlatformAuthenticatorPreferred.value || _isCrossPlatformAuthenticatorPreferred.value) {
        params['at'] = _isPlatformAuthenticatorPreferred.value ? 'platform' : 'cross-platform';
      }
    }
    else {
      params['p'] = '1';
    }
    var url = Uri.https(Config.rpHostName, "/signup", params);
    var response = (await http.get(url)).json;
    if (response['status'] != 'ok') {
      return response;
    }
    Map? options = response['msg']?['options'];

    Map body = {'username': username};
    if (isPwLess) {
      if (options == null) {
        return {'status': 'fail', 'msg': "invalid_response".i18n()};
      }
      try {
        "Options: $options".log();
        final credential = await FlutterPasskey().createCredential(jsonEncode(options));
        "Credential: $credential".log();
        body['credential'] = jsonDecode(credential);
      } catch(e) {
        e.toString().log();
        return {'status': 'fail', 'msg': e.toString()};
      }
    }
    else {
      final encodedPassword = password.toSha256().toBase64();
      body['password'] = encodedPassword;
    }
    url = Uri.https(Config.rpHostName, "/signup");
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };
    response = (await http.post(url, headers: headers, body: jsonEncode(body))).json;
    return response;
  }

  Future<Map> _signIn(String username, String? password, bool is2faEnabled) async {
    username = username.trim();
    bool isPwLess = (password == null) && !is2faEnabled;
    if (username.isNotEmpty && !username.isValidEmail()) {
      return {'status': 'fail', 'msg': "username_must_be_email".i18n()};
    }
    if (!isPwLess && username.isEmpty) {
      return {'status': 'fail', 'msg': "username_cant_be_empty".i18n()};
    }
    if (!isPwLess && (password == null || password.isEmpty)) {
      return {'status': 'fail', 'msg': "pw_cant_be_empty".i18n()};
    }

    bool isPasskeyEnabled = await Config.isPasskeyEnabled;
    if (isPwLess && !isPasskeyEnabled) {
      Map<String, String> params = {'m': 'signin', 'u': username, 'r': DEEP_LINK_SCHEME};
      Uri uri = Uri.https(Config.rpHostName, "/mindex.html", params);
      return _openBrowser(uri);
    }

    Map<String, String> params = {'u': username};
    if (!isPwLess) {
      params['p'] = '1';
      if (is2faEnabled) { params['t'] = '1'; }
    }
    var url = Uri.https(Config.rpHostName, "/signin", params);
    var response = (await http.get(url)).json;
    if (response['status'] != 'ok') {
      return response;
    }
    Map? options = response['msg']?['options'];

    Map body = {'username': username};
    if (isPwLess || is2faEnabled) {
      if (options == null) {
        return {'status': 'fail', 'msg': "invalid_response".i18n()};
      }
      try {
        "Options: $options".log();
        final credential = await FlutterPasskey().getCredential(jsonEncode(options));
        "Credential: $credential".log();
        body['credential'] = jsonDecode(credential);
      } catch(e) {
        e.toString().log();
        return {'status': 'fail', 'msg': e.toString()};
      }
    }
    if (!isPwLess) {
      final encodedPassword = password?.toSha256().toBase64();
      body['password'] = encodedPassword;
    }
    url = Uri.https(Config.rpHostName, "/signin");
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };
    response = (await http.post(url, headers: headers, body: jsonEncode(body))).json;
    return response;
  }

  Future<String> _queryUserInfo() async {
    var url = Uri.https(Config.rpHostName, "/userinfo");
    var headers = {'Authorization': 'Bearer ${_sessionToken ?? ''}'};
    var response = await http.get(url, headers: headers);
    return response.body;
  }

  Future<Map> _registerKey() async {
    bool isPasskeyEnabled = await Config.isPasskeyEnabled;
    if (!isPasskeyEnabled) {
      Map<String, String> params = {'m': 'registerkey', 'r': DEEP_LINK_SCHEME, 't': _sessionToken ?? ''};
      if (_isPlatformAuthenticatorPreferred.value || _isCrossPlatformAuthenticatorPreferred.value) {
        params['at'] = _isPlatformAuthenticatorPreferred.value ? 'platform' : 'cross-platform';
      }
      Uri uri = Uri.https(Config.rpHostName, "/mindex.html", params);
      return _openBrowser(uri);
    }

    Map<String, String> params = {};
    if (_isPlatformAuthenticatorPreferred.value || _isCrossPlatformAuthenticatorPreferred.value) {
      params['at'] = _isPlatformAuthenticatorPreferred.value ? 'platform' : 'cross-platform';
    }
    var url = Uri.https(Config.rpHostName, "/registerkey", params);
    var headers = {'Authorization': 'Bearer ${_sessionToken ?? ''}'};
    var response = (await http.get(url, headers: headers)).json;
    if (response['status'] != 'ok') {
      return response;
    }
    Map? options = response['msg']?['options'];
    var body = {};
    if (options == null) {
      return {'status': 'fail', 'msg': "invalid_response".i18n()};
    }
    try {
      "Options: $options".log();
      final credential = await FlutterPasskey().createCredential(jsonEncode(options));
      "Credential: $credential".log();
      body['credential'] = jsonDecode(credential);
    } catch(e) {
      e.toString().log();
      return {'status': 'fail', 'msg': e.toString()};
    }
    url = Uri.https(Config.rpHostName, "/registerkey");
    headers['Accept'] = 'application/json';
    headers['Content-Type'] = 'application/json';
    response = (await http.post(url, headers: headers, body: jsonEncode(body))).json;
    return response;
  }

  Widget _loginWidget(bool isSignUp) {
    String username = '';
    String password = '';
    ValueNotifier<bool> pwSwitch = ValueNotifier(false);
    const int switchOn = 1;
    const int switchOff = 0;
    const int switchDisabled = -1;
    ValueNotifier<int> tfaSwitchState = ValueNotifier(switchDisabled);
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() { _isSignUp = true; }),
                style: ButtonStyle(
                  backgroundColor: _isSignUp ? MaterialStateProperty.all(Colors.white) : null,
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                child: Text('signup'.i18n(), style: const TextStyle(fontSize: 20)),
              ),
              TextButton(
                onPressed: () => setState(() { _isSignUp = false; }),
                style: ButtonStyle(
                  backgroundColor: _isSignUp ? null : MaterialStateProperty.all(Colors.white),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                child: Text('signin'.i18n(), style: const TextStyle(fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 40),
          TextFormField(
            decoration: InputDecoration(
              border: const UnderlineInputBorder(),
              labelText: 'enter_username'.i18n(),
            ),
            controller: _usernameController,
          ),
          const SizedBox(height: 40),
          ValueListenableBuilder<bool>(
            valueListenable: pwSwitch,
            builder: (context, currentState, child) {
              return Column(
                children: [
                  Row(
                    children: [
                      Text('use_password'.i18n()),
                      Switch(
                        value: currentState,
                        onChanged: (value) {
                          pwSwitch.value = value;
                          if (value) {
                            Config.isPasskeyEnabled.then((enabled) {
                              tfaSwitchState.value = enabled ? switchOff : switchDisabled;
                            });
                          }
                          else {
                            tfaSwitchState.value = switchDisabled;
                          }
                        },
                      ),
                      const SizedBox(width: 50),
                      if (!_isSignUp && currentState) ValueListenableBuilder<int>(
                        valueListenable: tfaSwitchState,
                        builder: (context, currentState, child) {
                          return Row(
                            children: [
                              Text('2fa'.i18n(), style: TextStyle(color: (tfaSwitchState.value == switchDisabled) ? Colors.grey : null)),
                              Switch(
                                value: (currentState == switchOn),
                                inactiveThumbColor: (tfaSwitchState.value == switchDisabled) ? Colors.grey : null,
                                inactiveTrackColor: (tfaSwitchState.value == switchDisabled) ? Colors.grey : null,
                                onChanged: (tfaSwitchState.value == switchDisabled) ? null : (value) {
                                  tfaSwitchState.value = value ? switchOn : switchOff;
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  if (currentState) TextFormField(
                    decoration: InputDecoration(
                      border: const UnderlineInputBorder(),
                      labelText: 'enter_password'.i18n(),
                    ),
                    controller: _passwordController,
                    obscureText: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 50),
          FilledButton(
            onPressed: () {
              final username = _usernameController.text;
              final password = _passwordController.text;
              var result = _isSignUp ? _signUp(username, pwSwitch.value ? password : null) : _signIn(username, pwSwitch.value ? password : null, (tfaSwitchState.value == switchOn));
              result.then((response) {
                if (response['status'] != 'ok') {
                  String msg = response['msg'] ?? "unknown_error".i18n();
                  msg.asAlert(context);
                  return;
                }
                String? token = response['msg']['token'];
                if (token == null) {
                  "unknown_error".i18n().asAlert(context);
                  return;
                }
                _saveSessionToken(token).then((value) {
                  setState(() {
                    _sessionToken = token;
                  });
                });
              });
            },
            child: Text(_isSignUp ? 'signup'.i18n() : 'signin'.i18n(), style: const TextStyle(color: Colors.white, fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _loggedInWidget() {
    ValueNotifier<String> userInfo = ValueNotifier('');
    _queryUserInfo().then((info) {
      userInfo.value = info;
    });
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Flexible(
              child: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: userInfo,
                  builder: (context, currentText, child) {
                    return Text(currentText, style: const TextStyle(fontSize: 16));
                  },
                ),
              ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FilledButton(
                onPressed: () {
                  _registerKey().then((response) {
                    if (response['status'] != 'ok') {
                      String msg = response['msg'] ?? "unknown_error".i18n();
                      msg.asAlert(context);
                    }
                    else {
                      setState(() {});
                    }
                  });
                },
                child: Text('reg_key'.i18n(), style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
              FilledButton(
                onPressed: () {
                  _clearSessionToken().then((value) {
                    setState(() {
                      _sessionToken = null;
                    });
                  });
                },
                child: Text('logout'.i18n(), style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSessionToken().then((token) {
      if (token != null) {
        final jwt = JWT.decode(token);
        int? exp = jwt.payload['exp'];
        if (exp == null || exp > (DateTime.now().millisecondsSinceEpoch / 1000)) {
          setState(() {
            _sessionToken = token;
          });
        }
      }
    });
    _handleIncomingLinks();
    _browserEvents = FlutterWebBrowser.events().listen((event) {
      if (event is RedirectEvent) {
        var uri = event.url;
        'RedirectEvent: $uri'.log();
        if (_isBrowserOpened) FlutterWebBrowser.close();
        Future.delayed(const Duration(seconds: 0), () => _browserResponse.value = uri);
      }
      else if (event is CloseEvent) {
        'CloseEvent'.log();
        _isBrowserOpened = false;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var title = 'app_title'.i18n();
    _usernameController.text = '';
    _passwordController.text = '';
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          centerTitle: true,
          leading: IconButton(
            splashRadius: 24,
            icon: const Icon(Icons.info_outline, size: 26.0),
            onPressed: () {
              _showAbout();
            },
          ),
          actions: [
            IconButton(
              splashRadius: 24,
              icon: const Icon(Icons.settings_rounded, size: 26.0),
              onPressed: () => _showConfig(),
            ),
          ],
        ),
        body: _isLoggedIn ? _loggedInWidget() : _loginWidget(_isSignUp),
      ),
    );
  }
}
