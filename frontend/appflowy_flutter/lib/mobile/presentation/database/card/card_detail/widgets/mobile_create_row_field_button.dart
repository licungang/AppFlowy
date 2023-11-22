import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/database/card/card_detail/mobile_create_row_field_screen.dart';
import 'package:appflowy/plugins/database_view/application/field/field_controller.dart';
import 'package:appflowy/plugins/database_view/application/field/type_option/type_option_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileCreateRowFieldButton extends StatelessWidget {
  const MobileCreateRowFieldButton({
    super.key,
    required this.viewId,
    required this.fieldController,
  });

  final String viewId;
  final FieldController fieldController;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      label: Text(
        LocaleKeys.grid_field_newProperty.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
      onPressed: () {
        TypeOptionBackendService.createFieldTypeOption(viewId: viewId).then(
          (result) => result.fold(
            (typeOption) {
              context.push(
                MobileCreateRowFieldScreen.routeName,
                extra: {
                  MobileCreateRowFieldScreen.argViewId: viewId,
                  MobileCreateRowFieldScreen.argTypeOption: typeOption,
                  MobileCreateRowFieldScreen.argFieldController:
                      fieldController,
                },
              );
            },
            (r) => Log.error("Failed to create field type option: $r"),
          ),
        );
      },
      icon: FlowySvg(
        FlowySvgs.add_m,
        color: Theme.of(context).hintColor,
      ),
    );
  }
}
