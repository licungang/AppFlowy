import 'package:dartz/dartz.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/row_entities.pb.dart';

typedef RowId = String;

class RowBackendService {
  final String viewId;

  RowBackendService({
    required this.viewId,
  });

  Future<Either<RowPB, FlowyError>> createRow(RowId rowId) {
    final payload = CreateRowPayloadPB.create()
      ..viewId = viewId
      ..startRowId = rowId;

    return DatabaseEventCreateRow(payload).send();
  }

  Future<Either<OptionalRowPB, FlowyError>> getRow(RowId rowId) {
    final payload = RowIdPB.create()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventGetRow(payload).send();
  }

  Future<Either<RowMetaPB, FlowyError>> getRowMeta(RowId rowId) {
    final payload = RowIdPB.create()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventGetRowMeta(payload).send();
  }

  Future<Either<Unit, FlowyError>> updateMeta({
    String? iconURL,
    String? coverURL,
  }) {
    final payload = UpdateRowMetaChangesetPB.create()..viewId = viewId;

    if (iconURL != null) {
      payload.iconUrl = iconURL;
    }
    if (coverURL != null) {
      payload.coverUrl = coverURL;
    }

    return DatabaseEventUpdateRowMeta(payload).send();
  }

  Future<Either<Unit, FlowyError>> deleteRow(RowId rowId) {
    final payload = RowIdPB.create()
      ..viewId = viewId
      ..rowId = rowId;

    return DatabaseEventDeleteRow(payload).send();
  }

  Future<Either<Unit, FlowyError>> duplicateRow({
    required RowId rowId,
    String? groupId,
  }) {
    final payload = RowIdPB.create()
      ..viewId = viewId
      ..rowId = rowId;
    if (groupId != null) {
      payload.groupId = groupId;
    }

    return DatabaseEventDuplicateRow(payload).send();
  }
}
