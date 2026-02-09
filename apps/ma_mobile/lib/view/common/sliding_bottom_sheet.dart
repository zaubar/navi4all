import 'package:flutter/material.dart';
import 'package:smartroots/core/theme/colors.dart';

class SlidingBottomSheet extends StatelessWidget {
  final Widget? stickyHeader;
  final List<Widget>? listItems;
  final Widget? body;
  final double minSize;
  final double initSize;
  final double maxSize;

  SlidingBottomSheet({
    super.key,
    this.stickyHeader,
    this.listItems,
    this.body,
    this.minSize = 0.3,
    this.initSize = 0.45,
    this.maxSize = 0.75,
  }) {
    assert(listItems != null || body != null);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    minChildSize: minSize,
    initialChildSize: initSize,
    maxChildSize: maxSize,
    builder: ((BuildContext context, ScrollController controller) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.0),
          topRight: Radius.circular(32.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 2.0,
            offset: Offset(0, -1.0),
          ),
        ],
      ),
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32.0),
          topRight: Radius.circular(32.0),
        ),
        child: Column(
          children: [
            SingleChildScrollView(
              controller: controller,
              child: Column(
                children: <Widget>[
                  SizedBox(height: 16.0),
                  Container(
                    width: 32.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  stickyHeader ?? SizedBox.shrink(),
                ],
              ),
            ),
            stickyHeader != null
                ? Divider(color: SmartRootsColors.maBlue, height: 0)
                : SizedBox.shrink(),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: listItems != null ? Column(children: listItems!) : body,
              ),
            ),
          ],
        ),
      ),
    )),
  );
}
