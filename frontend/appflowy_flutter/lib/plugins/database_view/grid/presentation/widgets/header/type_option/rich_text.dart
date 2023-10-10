import 'package:appflowy/plugins/database_view/application/field/type_option/type_option_parser.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pb.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flutter/widgets.dart';

class RichTextTypeOptionEditor extends StatelessWidget {
  final FieldPB field;
  final RichTextTypeOptionParser parser;
  final PopoverMutex popoverMutex;

  const RichTextTypeOptionEditor({
    required this.field,
    required this.parser,
    required this.popoverMutex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
