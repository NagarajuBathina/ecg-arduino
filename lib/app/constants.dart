import 'package:flutter/material.dart';

const Color primaryColor = Colors.white;
const Color secondaryColor = Color(0xff25211f);
const Color greenColor = Color(0xff07B176);
const Color blueColor = Color(0xff41B7FA);
const Color limeColor = Color(0xffDED796);
const Color darkBgColor = Color(0xff2C2828);

const Color textColor = Color(0xff987544);
const Color buttonColor = Color(0xffbb86fc);
const Color borderColor = Color.fromRGBO(255, 255, 255, 0.59);

const LinearGradient buttonGradient = LinearGradient(colors: [
  Color(0xff414F33),
  Color(0xff382721),
]);
const LinearGradient appBarGradient = LinearGradient(
  stops: [0.05, 0.33, 0.6, 0.92],
  colors: [
    Color(0xff0F100D),
    Color(0xff141917),
    Color(0xff171818),
    Color(0xff251915)
  ],
);
const LinearGradient borderGradient = LinearGradient(
  stops: [0.05, 0.47, 0.89],
  colors: [Color(0xff957040), Color(0xffDED796), Color(0xffA37944)],
);

const double defaultPadding = 16;
const double defaultSpacing = 16;
const double defaultRadius = 16;

const String verticalLogo = "assets/images/logo.png";
const String bgImage1 = "assets/images/bg1.png";

const List<int> defaultIntervals = [1000, 3000, 5000, 10000, 30000, 60000];
