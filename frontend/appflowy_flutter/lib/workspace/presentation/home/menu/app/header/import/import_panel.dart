import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/migration/editor_migration.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/share/import_service.dart';
import 'package:appflowy/workspace/presentation/home/menu/app/header/import/import_type.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/protobuf.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flowy_infra/uuid.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/container.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;

import '../../../../../../application/settings/application_data_storage.dart';

typedef ImportCallback = void Function(
  ImportType type,
  String name,
  List<int>? document,
);

Future<void> showImportPanel(
  String parentViewId,
  BuildContext context,
  ImportCallback callback,
) async {
  await FlowyOverlay.show(
    context: context,
    builder: (context) => FlowyDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: FlowyText.semibold(
        LocaleKeys.moreAction_import.tr(),
        fontSize: 20,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 20.0,
        ),
        child: ImportPanel(
          parentViewId: parentViewId,
          importCallback: callback,
        ),
      ),
    ),
  );
}

class ImportPanel extends StatelessWidget {
  ImportPanel({
    super.key,
    required this.parentViewId,
    required this.importCallback,
  });

  final String parentViewId;
  final ImportCallback importCallback;
  final PopoverController popoverController = PopoverController();
  @override
  Widget build(BuildContext context) {
    final List<Widget> importCards = ImportType.values
        .where((element) => element.enableOnRelease)
        .map(
          (e) => Card(
            child: FlowyButton(
              leftIcon: e.icon(context),
              leftIconSize: const Size.square(20),
              text: FlowyText.medium(
                e.toString(),
                fontSize: 15,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                await _importFile(parentViewId, e);
                if (context.mounted) {
                  FlowyOverlay.pop(context);
                }
              },
            ),
          ),
        )
        .toList();
    importCards.add(
      Card(
        child: AppFlowyPopover(
          popupBuilder: (BuildContext context) {
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ImportFromNotionType.values
                    .map(
                      (e) => Card(
                        child: FlowyButton(
                          leftIconSize: const Size.square(20),
                          text: FlowyText.medium(
                            e.toString(),
                            fontSize: 15,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            popoverController.close();
                            await FlowyOverlay.show(
                              context: context,
                              builder: (context) =>
                                  _uploadFileToImportFromOverlay(context, e),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
          controller: popoverController,
          constraints: BoxConstraints.loose(const Size(200, 200)),
          direction: PopoverDirection.bottomWithCenterAligned,
          margin: EdgeInsets.zero,
          triggerActions: PopoverTriggerFlags.none,
          child: FlowyButton(
            leftIcon: const Icon(Icons.abc_outlined),
            leftIconSize: const Size.square(20),
            text: const FlowyText.medium(
              'Import from Notion',
              fontSize: 15,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              popoverController.show();
            },
          ),
        ),
      ),
    );
    final width = MediaQuery.of(context).size.width * 0.7;
    final height = width * 0.5;
    return FlowyContainer(
      Theme.of(context).colorScheme.surface,
      height: height,
      width: width,
      child: GridView.count(
        childAspectRatio: 1 / .2,
        crossAxisCount: 2,
        children: importCards,
      ),
    );
  }

  Widget _uploadFileToImportFromOverlay(
    BuildContext context,
    ImportFromNotionType importFromNotionType,
  ) {
    return FlowyDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: FlowyText.semibold(
        'Import Notion ${importFromNotionType.toString()}',
        fontSize: 20,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      constraints: BoxConstraints.loose(const Size(300, 200)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 20.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Go to the page you want to export'),
            const Text('2. Click on the three dots on the top right corner'),
            const Text('3. Click on export'),
            const Text('4. Click on Markdown & CSV'),
            const Text('5. Click on export'),
            const Text('6. Select the file you just downloaded'),
            const SizedBox(height: 20),
            Center(
              child: FlowyButton(
                text: const FlowyText.medium(
                  'Upload zip file',
                  fontSize: 15,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                onTap: () async {
                  await _importPageFromNotion(
                      parentViewId, importFromNotionType,);
                  if (context.mounted) {
                    FlowyOverlay.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromNotion(
      String parentViewId, ImportFromNotionType importFromNotionType) async {
    final result = await getIt<FilePickerService>().pickFiles(
      type: FileType.custom,
      allowMultiple: importFromNotionType.allowMultiSelect,
      allowedExtensions: importFromNotionType.allowedExtensions,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final File zipfile = File(result.files[0].path!);
    final bytes = await zipfile.readAsBytes();
    final unzipped = ZipDecoder().decodeBytes(bytes);
    print(unzipped.files);
    var markdownFile;
    //this for loop help us in finding our main page markdownfile
    for (final file in unzipped) {
      if (file.isFile) {
        final filename = p.basename(file.name);
        if (filename.endsWith('.md') && !filename.contains("/")) {
          markdownFile = file;
          break;
        }
      }
    }
    //This for will help us store image assets of our page
    List<ArchiveFile> images = [];
    for (final file in unzipped) {
      if (file.isFile) {
        final filename = file.name;
        if (filename.contains("/") &&
            filename.endsWith('.png') &&
            filename.split("/").length - 1 == 1) {
          final assetName = filename.split("/").last;
          final assetPath = filename.split("/").first;
          final asset = await file.content as Uint8List;
          
          images.add(file);
        }
      }
    }
    if (markdownFile == null) {
      return;
    }
  }

  Future<void> _importFile(String parentViewId, ImportType importType) async {
    final result = await getIt<FilePickerService>().pickFiles(
      type: FileType.custom,
      allowMultiple: importType.allowMultiSelect,
      allowedExtensions: importType.allowedExtensions,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      final data = await File(path).readAsString();
      final name = p.basenameWithoutExtension(path);

      switch (importType) {
        case ImportType.markdownOrText:
        case ImportType.historyDocument:
          final bytes = _documentDataFrom(importType, data);
          if (bytes != null) {
            await ImportBackendService.importData(
              bytes,
              name,
              parentViewId,
              ImportTypePB.HistoryDocument,
            );
          }
          break;
        case ImportType.historyDatabase:
          await ImportBackendService.importData(
            utf8.encode(data),
            name,
            parentViewId,
            ImportTypePB.HistoryDatabase,
          );
          break;
        case ImportType.databaseRawData:
          await ImportBackendService.importData(
            utf8.encode(data),
            name,
            parentViewId,
            ImportTypePB.RawDatabase,
          );
          break;
        case ImportType.databaseCSV:
          await ImportBackendService.importData(
            utf8.encode(data),
            name,
            parentViewId,
            ImportTypePB.CSV,
          );
          break;
        default:
          assert(false, 'Unsupported Type $importType');
      }
    }

    importCallback(importType, '', null);
  }

  Future<void> _importPageFromNotion(
    String parentViewId,
    ImportFromNotionType importFromNotionType,
  ) async {
    final result = await getIt<FilePickerService>().pickFiles(
      type: FileType.custom,
      allowMultiple: importFromNotionType.allowMultiSelect,
      allowedExtensions: importFromNotionType.allowedExtensions,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final File zipfile = File(result.files[0].path!);
    final name = p.basenameWithoutExtension(zipfile.path);
    final bytes = await zipfile.readAsBytes();
    final unzipped = ZipDecoder().decodeBytes(bytes);
    dynamic markdownFile;
    //this for loop help us in finding our main page markdownfile
    for (final file in unzipped) {
      if (file.isFile) {
        final filename = p.basename(file.name);
        if (filename.endsWith('.md') && !filename.contains("/")) {
          markdownFile = file;
          break;
        }
      }
    }
    if (markdownFile == null) {
      return;
    }
    //This for will help us store image assets of our page
    final List<ArchiveFile> images = [];
    for (final file in unzipped) {
      if (file.isFile) {
        final filename = file.name;
        if (filename.contains("/") &&
            filename.endsWith('.png') &&
            filename.split("/").length - 1 == 1) {
          images.add(file);
        }
      }
    }

    final String markdownContents =
        utf8.decode(markdownFile.content as Uint8List);
    final String processedMarkdownFile =
        await processMarkdownFile(markdownContents, images);

    final data = _documentDataFrom(
      ImportType.markdownOrText,
      processedMarkdownFile,
    );
    if (data != null) {
      await ImportBackendService.importData(
        bytes,
        name,
        parentViewId,
        ImportTypePB.HistoryDocument,
      );
    }
  }

  Future<String> processMarkdownFile(
    String markdownContents,
    List<ArchiveFile> images,
  ) async {
    final lines = markdownContents.split("\n");
    final newLines = <String>[];
    final assetRegex = RegExp(r'^!\[.*\]\(.*\)$');
    for (final line in lines) {
      if (assetRegex.hasMatch(line.trim())) {
        final imagePath = extractImagePath(
          line,
        );
        if (imagePath != null) {
          final localPath =
              await saveFileLocally(images, Uri.decodeFull(imagePath));
          if (localPath != null) {
            newLines.add(line.replaceFirst(imagePath, localPath));
          }
        }
      } else {
        newLines.add(line);
      }
    }
    return newLines.join("\n");
  }

  String? extractImagePath(String text) {
    const startDelimiter = "![";
    const endDelimiter = "](";
    final startIndex = text.indexOf(startDelimiter);
    final endIndex =
        text.indexOf(endDelimiter, startIndex + startDelimiter.length);

    if (startIndex != -1 && endIndex != -1) {
      return text.substring(endIndex + endDelimiter.length, text.length - 1);
    } else {
      return null;
    }
  }

  Future<String>? saveFileLocally(
    List<ArchiveFile> images,
    String assetName,
  ) async {
    final image = images.firstWhereOrNull(
      (element) => element.name == assetName,
    );
    if (image == null) {
      return '';
    }
    final path = await getIt<ApplicationDataStorage>().getPath();
    final imagePath = p.join(
      path,
      'images',
    );
    final directory = Directory(imagePath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final copyToPath = p.join(
      imagePath,
      '${uuid()}${p.extension(assetName)}',
    );
    await File(copyToPath).writeAsBytes(
      image.content as Uint8List,
    );
    return copyToPath;
  }
}

Uint8List? _documentDataFrom(ImportType importType, String data) {
  switch (importType) {
    case ImportType.markdownOrText:
      final document = markdownToDocument(data);
      return DocumentDataPBFromTo.fromDocument(document)?.writeToBuffer();
    case ImportType.historyDocument:
      final document = EditorMigration.migrateDocument(data);
      return DocumentDataPBFromTo.fromDocument(document)?.writeToBuffer();
    default:
      assert(false, 'Unsupported Type $importType');
      return null;
  }
}
