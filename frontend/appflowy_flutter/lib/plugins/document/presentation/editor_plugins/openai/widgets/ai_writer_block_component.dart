import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/build_context_extension.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/markdown_text_robot.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/openai/service/error.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/openai/widgets/ai_writer_block_operations.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/openai/widgets/ai_writer_block_widgets.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/openai/widgets/discard_dialog.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/openai/widgets/loading.dart';
import 'package:appflowy/user/application/ai_service.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

import 'ai_limit_dialog.dart';

class AIWriterBlockKeys {
  const AIWriterBlockKeys._();

  static const String type = 'auto_completion';
  static const String prompt = 'prompt';
  static const String startSelection = 'start_selection';
  static const String generationCount = 'generation_count';

  static String getRewritePrompt(String previousOutput, String prompt) {
    return 'I am not satisfied with your previous response ($previousOutput) to the query ($prompt). Please provide an alternative response.';
  }
}

Node aiWriterNode({
  String prompt = '',
  required Selection start,
}) {
  return Node(
    type: AIWriterBlockKeys.type,
    attributes: {
      AIWriterBlockKeys.prompt: prompt,
      AIWriterBlockKeys.startSelection: start.toJson(),
      AIWriterBlockKeys.generationCount: 0,
    },
  );
}

class AIWriterBlockComponentBuilder extends BlockComponentBuilder {
  AIWriterBlockComponentBuilder();

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return AIWriterBlockComponent(
      key: node.key,
      node: node,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) =>
      node.children.isEmpty &&
      node.attributes[AIWriterBlockKeys.prompt] is String &&
      node.attributes[AIWriterBlockKeys.startSelection] is Map;
}

class AIWriterBlockComponent extends BlockComponentStatefulWidget {
  const AIWriterBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<AIWriterBlockComponent> createState() => _AIWriterBlockComponentState();
}

class _AIWriterBlockComponentState extends State<AIWriterBlockComponent> {
  final controller = TextEditingController();
  final textFieldFocusNode = FocusNode();

  late final editorState = context.read<EditorState>();
  late final SelectionGestureInterceptor interceptor;
  late final AIWriterBlockOperations aiWriterOperations =
      AIWriterBlockOperations(
    editorState: editorState,
    aiWriterNode: widget.node,
  );

  String get prompt => widget.node.attributes[AIWriterBlockKeys.prompt];
  int get generationCount =>
      widget.node.attributes[AIWriterBlockKeys.generationCount] ?? 0;
  Selection? get startSelection {
    final selection = widget.node.attributes[AIWriterBlockKeys.startSelection];
    if (selection != null) {
      return Selection.fromJson(selection);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _subscribeSelectionGesture();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      editorState.selection = null;
      textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _onExit();
    _unsubscribeSelectionGesture();
    controller.dispose();
    textFieldFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UniversalPlatform.isMobile) {
      return const SizedBox.shrink();
    }

    final child = Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AIWriterBlockHeader(),
            const Space(0, 10),
            if (prompt.isEmpty && generationCount < 1) ...[
              _buildInputWidget(context),
              const Space(0, 10),
              AIWriterBlockInputField(
                onGenerate: _onGenerate,
                onExit: _onExit,
              ),
            ] else ...[
              AIWriterBlockFooter(
                onKeep: _onExit,
                onRewrite: _onRewrite,
                onDiscard: _onDiscard,
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: child,
    );
  }

  Widget _buildInputWidget(BuildContext context) {
    return FlowyTextField(
      hintText: LocaleKeys.document_plugins_autoGeneratorHintText.tr(),
      controller: controller,
      maxLines: 5,
      focusNode: textFieldFocusNode,
      autoFocus: false,
      hintTextConstraints: const BoxConstraints(),
    );
  }

  Future<void> _onExit() async {
    await aiWriterOperations.removeAIWriterNode(widget.node);
  }

  Future<void> _onGenerate() async {
    await aiWriterOperations.updatePromptText(controller.text);

    if (!_isAIWriterEnabled) {
      Log.error('AI Writer is not enabled');
      return;
    }

    final markdownTextRobot = MarkdownTextRobot(
      editorState: editorState,
    );

    BarrierDialog? barrierDialog;

    final aiRepository = AppFlowyAIService();
    await aiRepository.streamCompletion(
      text: controller.text,
      completionType: CompletionTypePB.ContinueWriting,
      onStart: () async {
        if (mounted) {
          barrierDialog = BarrierDialog(context);
          barrierDialog?.show();
          await aiWriterOperations.ensurePreviousNodeIsEmptyParagraphNode();
          markdownTextRobot.start();
        }
      },
      onProcess: (text) async {
        await markdownTextRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        barrierDialog?.dismiss();
        await markdownTextRobot.stop();
      },
      onError: (error) async {
        barrierDialog?.dismiss();
        _showAIWriterError(error);
      },
    );

    await aiWriterOperations.updateGenerationCount(generationCount + 1);
  }

  Future<void> _onDiscard() async {
    await aiWriterOperations.discardCurrentResponse(
      aiWriterNode: widget.node,
      selection: startSelection,
    );
    return _onExit();
  }

  Future<void> _onRewrite() async {
    final previousOutput = _getPreviousOutput();
    if (previousOutput == null) {
      return;
    }

    // discard the current response
    await aiWriterOperations.discardCurrentResponse(
      aiWriterNode: widget.node,
      selection: startSelection,
    );

    if (!_isAIWriterEnabled) {
      return;
    }

    final markdownTextRobot = MarkdownTextRobot(
      editorState: editorState,
    );
    final aiService = AppFlowyAIService();
    await aiService.streamCompletion(
      text: AIWriterBlockKeys.getRewritePrompt(previousOutput, prompt),
      completionType: CompletionTypePB.ContinueWriting,
      onStart: () async {
        await aiWriterOperations.ensurePreviousNodeIsEmptyParagraphNode();

        markdownTextRobot.start();
      },
      onProcess: (text) async {
        await markdownTextRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        await markdownTextRobot.stop();
      },
      onError: (error) {
        _showAIWriterError(error);
      },
    );

    await aiWriterOperations.updateGenerationCount(generationCount + 1);
  }

  String? _getPreviousOutput() {
    final startSelection = this.startSelection;
    if (startSelection != null) {
      final end = widget.node.previous?.path;

      if (end != null) {
        final result = editorState
            .getNodesInSelection(
          startSelection.copyWith(end: Position(path: end)),
        )
            .fold(
          '',
          (previousValue, element) {
            final delta = element.delta;
            if (delta != null) {
              return "$previousValue\n${delta.toPlainText()}";
            } else {
              return previousValue;
            }
          },
        );
        return result.trim();
      }
    }
    return null;
  }

  void _subscribeSelectionGesture() {
    interceptor = SelectionGestureInterceptor(
      key: AIWriterBlockKeys.type,
      canTap: (details) {
        if (!context.isOffsetInside(details.globalPosition)) {
          if (prompt.isNotEmpty || controller.text.isNotEmpty) {
            // show dialog
            showDialog(
              context: context,
              builder: (_) => DiscardDialog(
                onConfirm: _onDiscard,
                onCancel: () {},
              ),
            );
          } else if (controller.text.isEmpty) {
            _onExit();
          }
        }
        editorState.service.keyboardService?.disable();
        return false;
      },
    );
    editorState.service.selectionService.registerGestureInterceptor(
      interceptor,
    );
  }

  void _unsubscribeSelectionGesture() {
    editorState.service.selectionService.unregisterGestureInterceptor(
      AIWriterBlockKeys.type,
    );
  }

  void _showAIWriterError(AIError error) {
    if (mounted) {
      if (error.isLimitExceeded) {
        showAILimitDialog(context, error.message);
      } else {
        showToastNotification(
          context,
          message: error.message,
          type: ToastificationType.error,
        );
      }
    }
  }

  bool get _isAIWriterEnabled {
    final userProfile = context.read<DocumentBloc>().state.userProfilePB;
    final isAIWriterEnabled = userProfile != null;

    if (!isAIWriterEnabled) {
      showToastNotification(
        context,
        message: LocaleKeys.document_plugins_autoGeneratorCantGetOpenAIKey.tr(),
        type: ToastificationType.error,
      );
    }

    return isAIWriterEnabled;
  }
}
