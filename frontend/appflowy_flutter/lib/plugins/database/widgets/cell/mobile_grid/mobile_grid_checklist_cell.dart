import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy/plugins/database/grid/presentation/layout/sizes.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/cell_container.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/checklist_cell/checklist_cell_bloc.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/checklist_cell/checklist_progress_bar.dart';
import 'package:appflowy/plugins/database/widgets/row/cells/checklist_cell/mobile_checklist_cell_editor.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../editable_cell_skeleton/checklist.dart';

class MobileGridChecklistCellSkin extends IEditableChecklistSkin {
  @override
  Widget build(
    BuildContext context,
    CellContainerNotifier cellContainerNotifier,
    ChecklistCellBloc bloc,
    ChecklistCellState state,
    PopoverController popoverController,
  ) {
    return FlowyButton(
      radius: BorderRadius.zero,
      hoverColor: Colors.transparent,
      text: Container(
        alignment: Alignment.centerLeft,
        padding: GridSize.cellContentInsets,
        child: state.tasks.isEmpty
            ? const SizedBox.shrink()
            : ChecklistProgressBar(
                tasks: state.tasks,
                percent: state.percent,
                fontSize: 15,
              ),
      ),
      onTap: () => showMobileBottomSheet(
        context,
        padding: EdgeInsets.zero,
        backgroundColor: Theme.of(context).colorScheme.background,
        builder: (context) {
          return MobileChecklistCellEditScreen(
            cellController: bloc.cellController,
          );
        },
      ),
    );
  }
}
