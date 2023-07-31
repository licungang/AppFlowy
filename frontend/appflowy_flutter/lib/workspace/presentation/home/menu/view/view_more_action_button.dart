import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_action_type.dart';
import 'package:flutter/material.dart';
import 'package:flowy_infra/image.dart';

import 'package:appflowy/workspace/presentation/widgets/pop_up_action.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra_ui/style_widget/icon_button.dart';

const supportedActionTypes = [
  ViewMoreActionType.rename,
  ViewMoreActionType.delete,
  ViewMoreActionType.duplicate,
  ViewMoreActionType.openInNewTab,
  ViewMoreActionType.toggleFavorite,
];

/// ··· button beside the view name
class ViewMoreActionButton extends StatelessWidget {
  const ViewMoreActionButton({
    super.key,
    required this.favoriteStatus,
    required this.onEditing,
    required this.onAction,
  });
  final bool favoriteStatus;
  final void Function(bool value) onEditing;
  final void Function(ViewMoreActionType) onAction;

  @override
  Widget build(BuildContext context) {
    return PopoverActionList<ViewMoreActionTypeWrapper>(
      direction: PopoverDirection.bottomWithCenterAligned,
      offset: const Offset(0, 8),
      actions: supportedActionTypes
          .map((e) => ViewMoreActionTypeWrapper(e, favoriteStatus))
          .toList(),
      buildChild: (popover) {
        return FlowyIconButton(
          hoverColor: Colors.transparent,
          iconPadding: const EdgeInsets.all(2),
          width: 26,
          icon: const FlowySvg(name: 'editor/details'),
          onPressed: () {
            onEditing(true);
            popover.show();
          },
        );
      },
      onSelected: (action, popover) {
        onEditing(false);
        onAction(action.inner);
        popover.close();
      },
      onClosed: () => onEditing(false),
    );
  }
}

class ViewMoreActionTypeWrapper extends ActionCell {
  ViewMoreActionTypeWrapper(this.inner, this.state);

  final ViewMoreActionType inner;
  final bool? state;

  @override
  Widget? leftIcon(Color iconColor) => inner.icon(iconColor, state: state);

  @override
  String get name => inner.name(state: state);
}
