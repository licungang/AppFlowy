import 'package:appflowy/plugins/database_view/application/cell/cell_controller_builder.dart';
import 'package:appflowy/util/platform_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pb.dart';
import 'package:flutter/material.dart';

import '../../application/cell/cell_service.dart';
import 'cells/card_cell.dart';
import 'cells/checkbox_card_cell.dart';
import 'cells/checklist_card_cell.dart';
import 'cells/date_card_cell.dart';
import 'cells/number_card_cell.dart';
import 'cells/select_option_card_cell.dart';
import 'cells/text_card_cell.dart';
import 'cells/timestamp_card_cell.dart';
import 'cells/url_card_cell.dart';

// T represents as the Generic card data
class CardCellBuilder<CustomCardData> {
  final CellMemCache cellCache;
  final Map<FieldType, CardCellStyle>? styles;

  CardCellBuilder(this.cellCache, {this.styles});

  Widget buildCell({
    CustomCardData? cardData,
    required DatabaseCellContext cellContext,
    EditableCardNotifier? cellNotifier,
    RowCardRenderHook<CustomCardData>? renderHook,
    required bool hasNotes,
  }) {
    final cellControllerBuilder = CellControllerBuilder(
      cellContext: cellContext,
      cellCache: cellCache,
    );

    final key = cellContext.key();
    final style = styles?[cellContext.fieldType];

    final cellWidget = PlatformExtension.isMobile
        ? _getMobileCardCellWidget(
            key: key,
            cellContext: cellContext,
            cellControllerBuilder: cellControllerBuilder,
            style: style,
            cardData: cardData,
            cellNotifier: cellNotifier,
            renderHook: renderHook,
            hasNotes: hasNotes,
          )
        : _getDesktopCardCellWidget(
            key: key,
            cellContext: cellContext,
            cellControllerBuilder: cellControllerBuilder,
            style: style,
            cardData: cardData,
            cellNotifier: cellNotifier,
            renderHook: renderHook,
            hasNotes: hasNotes,
          );

    return cellWidget;
  }

  Widget _getDesktopCardCellWidget({
    required Key key,
    required DatabaseCellContext cellContext,
    required CellControllerBuilder cellControllerBuilder,
    CardCellStyle? style,
    CustomCardData? cardData,
    EditableCardNotifier? cellNotifier,
    RowCardRenderHook<CustomCardData>? renderHook,
    required bool hasNotes,
  }) {
    switch (cellContext.fieldType) {
      case FieldType.Checkbox:
        return CheckboxCardCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.DateTime:
        return DateCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.DateTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.LastEditedTime:
        return TimestampCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.LastEditedTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.CreatedTime:
        return TimestampCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.CreatedTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.SingleSelect:
        return SelectOptionCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.SingleSelect],
          cellControllerBuilder: cellControllerBuilder,
          cardData: cardData,
          key: key,
        );
      case FieldType.MultiSelect:
        return SelectOptionCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.MultiSelect],
          cellControllerBuilder: cellControllerBuilder,
          cardData: cardData,
          editableNotifier: cellNotifier,
          key: key,
        );
      case FieldType.Checklist:
        return ChecklistCardCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.Number:
        return NumberCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.Number],
          style: isStyleOrNull<NumberCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.RichText:
        return TextCardCell<CustomCardData>(
          key: key,
          style: isStyleOrNull<TextCardCellStyle>(style),
          cardData: cardData,
          renderHook: renderHook?.renderHook[FieldType.RichText],
          cellControllerBuilder: cellControllerBuilder,
          editableNotifier: cellNotifier,
          showNotes: cellContext.fieldInfo.isPrimary && hasNotes,
        );
      case FieldType.URL:
        return URLCardCell<CustomCardData>(
          style: isStyleOrNull<URLCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
    }
    throw UnimplementedError;
  }

  Widget _getMobileCardCellWidget({
    required Key key,
    required DatabaseCellContext cellContext,
    required CellControllerBuilder cellControllerBuilder,
    CardCellStyle? style,
    CustomCardData? cardData,
    EditableCardNotifier? cellNotifier,
    RowCardRenderHook<CustomCardData>? renderHook,
    required bool hasNotes,
  }) {
    switch (cellContext.fieldType) {
      // TODO（yijing): refactor all the card cell to mobile
      case FieldType.Checkbox:
        return CheckboxCardCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.DateTime:
        return DateCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.DateTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.LastEditedTime:
        return TimestampCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.LastEditedTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.CreatedTime:
        return TimestampCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.CreatedTime],
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.SingleSelect:
        return SelectOptionCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.SingleSelect],
          cellControllerBuilder: cellControllerBuilder,
          cardData: cardData,
          key: key,
        );
      case FieldType.MultiSelect:
        return SelectOptionCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.MultiSelect],
          cellControllerBuilder: cellControllerBuilder,
          cardData: cardData,
          editableNotifier: cellNotifier,
          key: key,
        );
      case FieldType.Checklist:
        return ChecklistCardCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.Number:
        return NumberCardCell<CustomCardData>(
          renderHook: renderHook?.renderHook[FieldType.Number],
          style: isStyleOrNull<NumberCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.RichText:
        return TextCardCell<CustomCardData>(
          key: key,
          style: isStyleOrNull<TextCardCellStyle>(style),
          cardData: cardData,
          renderHook: renderHook?.renderHook[FieldType.RichText],
          cellControllerBuilder: cellControllerBuilder,
          editableNotifier: cellNotifier,
          showNotes: cellContext.fieldInfo.isPrimary && hasNotes,
        );
      case FieldType.URL:
        return URLCardCell<CustomCardData>(
          style: isStyleOrNull<URLCardCellStyle>(style),
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
    }
    throw UnimplementedError;
  }
}
