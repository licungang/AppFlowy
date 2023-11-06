import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';

class UploadImageFileWidget extends StatelessWidget {
  const UploadImageFileWidget({
    super.key,
    required this.onPickFile,
    this.allowedExtensions = const ['jpg', 'png', 'jpeg'],
  });

  final void Function(String? path) onPickFile;
  final List<String> allowedExtensions;

  @override
  Widget build(BuildContext context) {
    return FlowyHover(
      child: FlowyButton(
        showDefaultBoxDecorationOnMobile: true,
        text: Container(
          margin: const EdgeInsets.all(4.0),
          alignment: Alignment.center,
          child: FlowyText(
            LocaleKeys.document_imageBlock_upload_placeholder.tr(),
          ),
        ),
        onTap: () async {
          final result = await getIt<FilePickerService>().pickFiles(
            dialogTitle: '',
            allowMultiple: false,
            type: FileType.image,
            allowedExtensions: allowedExtensions,
          );
          onPickFile(result?.files.firstOrNull?.path);
        },
      ),
    );
  }
}
