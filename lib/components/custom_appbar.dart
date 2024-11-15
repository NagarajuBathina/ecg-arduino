import 'package:flutter/material.dart';

import '../app/constants.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  const CustomAppbar({
    super.key,
    this.title,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: appBarGradient,
      ),
      child: AppBar(
        leading: Navigator.canPop(context) && leading == null
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded),
              )
            : leading,
        elevation: 0,
        title: title,
        backgroundColor: Colors.transparent,
        actions: actions,
      ),
    );
    ;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
