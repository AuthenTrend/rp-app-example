import 'package:flutter/material.dart';
import 'package:localization/localization.dart';

import 'MainPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    LocalJsonLocalization.delegate.directories = ['assets/i18n'];
    return MaterialApp(
      title: 'app_name'.i18n(),
      theme: ThemeData.dark().copyWith(textButtonTheme: TextButtonThemeData(style: ButtonStyle(textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 16))))),
      //darkTheme: ThemeData(),
      localizationsDelegates: [
        // delegate from flutter_localization
        //GlobalMaterialLocalizations.delegate,
        //GlobalWidgetsLocalizations.delegate,
        //GlobalCupertinoLocalizations.delegate,
        // delegate from localization package.
        LocalJsonLocalization.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      home: MainPage(),
    );
  }
}
