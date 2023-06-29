import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/more/cubit/document_appearance_cubit.dart';
import 'package:appflowy/workspace/application/appearance.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/theme_upload/theme_upload_view.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/plugins/bloc/dynamic_plugin_bloc.dart';
import 'package:flowy_infra/plugins/bloc/dynamic_plugin_event.dart';
import 'package:flowy_infra/plugins/bloc/dynamic_plugin_state.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'levenshtein.dart';

class SettingsAppearanceView extends StatelessWidget {
  const SettingsAppearanceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: BlocProvider<DynamicPluginBloc>(
        create: (_) => DynamicPluginBloc(),
        child: BlocBuilder<AppearanceSettingsCubit, AppearanceSettingsState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BrightnessSetting(currentThemeMode: state.themeMode),
                ThemeFontFamilySetting(
                  currentFontFamily: state.font,
                ),
                ColorSchemeSetting(
                  currentTheme: state.appTheme.themeName,
                  bloc: context.read<DynamicPluginBloc>(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ColorSchemeSetting extends StatelessWidget {
  const ColorSchemeSetting({
    super.key,
    required this.currentTheme,
    required this.bloc,
  });

  final String currentTheme;
  final DynamicPluginBloc bloc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FlowyText.medium(
            LocaleKeys.settings_appearance_theme.tr(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ThemeUploadOverlayButton(bloc: bloc),
        const SizedBox(width: 4),
        ThemeSelectionPopover(currentTheme: currentTheme, bloc: bloc),
      ],
    );
  }
}

class ThemeUploadOverlayButton extends StatelessWidget {
  const ThemeUploadOverlayButton({super.key, required this.bloc});

  final DynamicPluginBloc bloc;

  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      width: 24,
      icon: const FlowySvg(name: 'folder'),
      iconColorOnHover: Theme.of(context).colorScheme.onPrimary,
      onPressed: () => Dialogs.show(
        context,
        child: BlocProvider<DynamicPluginBloc>.value(
          value: bloc,
          child: const FlowyDialog(
            constraints: BoxConstraints(maxHeight: 300),
            child: ThemeUploadWidget(),
          ),
        ),
      ).then((value) {
        if (value == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: FlowyText.medium(
              color: Theme.of(context).colorScheme.onPrimary,
              LocaleKeys.settings_appearance_themeUpload_uploadSuccess.tr(),
            ),
          ),
        );
      }),
    );
  }
}

class ThemeSelectionPopover extends StatelessWidget {
  const ThemeSelectionPopover({
    super.key,
    required this.currentTheme,
    required this.bloc,
  });

  final String currentTheme;
  final DynamicPluginBloc bloc;

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      direction: PopoverDirection.bottomWithRightAligned,
      child: FlowyTextButton(
        currentTheme,
        fontColor: Theme.of(context).colorScheme.onBackground,
        fillColor: Colors.transparent,
        onPressed: () {},
      ),
      popupBuilder: (BuildContext context) {
        return IntrinsicWidth(
          child: BlocBuilder<DynamicPluginBloc, DynamicPluginState>(
            bloc: bloc..add(DynamicPluginEvent.load()),
            buildWhen: (previous, current) => current is Ready,
            builder: (context, state) {
              return state.when(
                uninitialized: () => const SizedBox.shrink(),
                processing: () => const SizedBox.shrink(),
                compilationFailure: (message) => const SizedBox.shrink(),
                deletionFailure: (message) => const SizedBox.shrink(),
                deletionSuccess: () => const SizedBox.shrink(),
                compilationSuccess: () => const SizedBox.shrink(),
                ready: (plugins) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...AppTheme.builtins
                        .map(
                          (theme) => _themeItemButton(context, theme.themeName),
                        )
                        .toList(),
                    if (plugins.isNotEmpty) ...[
                      const Divider(),
                      ...plugins
                          .map((plugin) => plugin.theme)
                          .whereType<AppTheme>()
                          .map(
                            (theme) => _themeItemButton(
                              context,
                              theme.themeName,
                              false,
                            ),
                          )
                          .toList()
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _themeItemButton(
    BuildContext context,
    String theme, [
    bool isBuiltin = true,
  ]) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: FlowyButton(
              text: FlowyText.medium(theme),
              rightIcon: currentTheme == theme
                  ? const FlowySvg(name: 'grid/checkmark')
                  : null,
              onTap: () {
                if (currentTheme != theme) {
                  context.read<AppearanceSettingsCubit>().setTheme(theme);
                }
              },
            ),
          ),
          if (!isBuiltin)
            FlowyIconButton(
              icon: const FlowySvg(name: 'home/close'),
              width: 20,
              onPressed: () =>
                  bloc.add(DynamicPluginEvent.removePlugin(name: theme)),
            )
        ],
      ),
    );
  }
}

class BrightnessSetting extends StatelessWidget {
  final ThemeMode currentThemeMode;
  const BrightnessSetting({required this.currentThemeMode, super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeSettingDropDown(
      label: LocaleKeys.settings_appearance_themeMode_label.tr(),
      currentValue: _themeModeLabelText(currentThemeMode),
      popupBuilder: (_) => IntrinsicHeight(
        child: Column(
          children: [
            _themeModeItemButton(context, ThemeMode.light),
            _themeModeItemButton(context, ThemeMode.dark),
            _themeModeItemButton(context, ThemeMode.system),
          ],
        ),
      ),
    );
  }

  Widget _themeModeItemButton(BuildContext context, ThemeMode themeMode) {
    return SizedBox(
      height: 32,
      child: FlowyButton(
        text: FlowyText.medium(_themeModeLabelText(themeMode)),
        rightIcon: currentThemeMode == themeMode
            ? const FlowySvg(name: 'grid/checkmark')
            : null,
        onTap: () {
          if (currentThemeMode != themeMode) {
            context.read<AppearanceSettingsCubit>().setThemeMode(themeMode);
          }
        },
      ),
    );
  }

  String _themeModeLabelText(ThemeMode themeMode) {
    switch (themeMode) {
      case (ThemeMode.light):
        return LocaleKeys.settings_appearance_themeMode_light.tr();
      case (ThemeMode.dark):
        return LocaleKeys.settings_appearance_themeMode_dark.tr();
      case (ThemeMode.system):
        return LocaleKeys.settings_appearance_themeMode_system.tr();
      default:
        return "";
    }
  }
}

class ThemeFontFamilySetting extends StatefulWidget {
  const ThemeFontFamilySetting({
    super.key,
    required this.currentFontFamily,
  });

  final String currentFontFamily;

  @override
  State<ThemeFontFamilySetting> createState() => _ThemeFontFamilySettingState();
}

class _ThemeFontFamilySettingState extends State<ThemeFontFamilySetting> {
  final List<String> availableFonts = GoogleFonts.asMap().keys.toList();
  final ValueNotifier<String> query = ValueNotifier('');

  @override
  Widget build(BuildContext context) {
    return ThemeSettingDropDown(
      label: LocaleKeys.settings_appearance_fontFamily_label.tr(),
      currentValue: parseFontFamilyName(widget.currentFontFamily),
      popupBuilder: (_) => ListView(
        shrinkWrap: true,
        children: [
          FlowyTextField(
            hintText: LocaleKeys.settings_appearance_fontFamily_search.tr(),
            autoClearWhenDone: true,
            debounceDuration: const Duration(milliseconds: 300),
            onChanged: (value) {
              query.value = value;
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder(
            valueListenable: query,
            builder: (context, value, child) {
              var displayed = availableFonts;
              if (value.isNotEmpty) {
                displayed = availableFonts
                    .where(
                      (font) => font
                          .toLowerCase()
                          .contains(value.toLowerCase().toString()),
                    )
                    .sorted((a, b) => levenshtein(a, b))
                    .toList();
              }
              return ListView.builder(
                itemBuilder: (context, index) => _fontFamilyItemButton(
                  context,
                  GoogleFonts.getFont(displayed[index]),
                ),
                itemCount: displayed.length,
                shrinkWrap: true,
              );
            },
          ),
        ],
      ),
    );
  }

  String parseFontFamilyName(String fontFamilyName) {
    final camelCase = RegExp('(?<=[a-z])[A-Z]');
    return fontFamilyName
        .replaceAll('_regular', '')
        .replaceAllMapped(camelCase, (m) => ' ${m.group(0)}');
  }

  Widget _fontFamilyItemButton(BuildContext context, TextStyle style) {
    return SizedBox(
      key: UniqueKey(),
      height: 32,
      child: FlowyButton(
        text: FlowyText.medium(
          parseFontFamilyName(style.fontFamily!),
          fontFamily: style.fontFamily!,
        ),
        rightIcon: widget.currentFontFamily == style.fontFamily
            ? const FlowySvg(name: 'grid/checkmark')
            : null,
        onTap: () {
          if (widget.currentFontFamily != style.fontFamily) {
            context
                .read<AppearanceSettingsCubit>()
                .setFontFamily(style.fontFamily!);
            context
                .read<DocumentAppearanceCubit>()
                .syncFontFamily(style.fontFamily!);
          }
        },
      ),
    );
  }
}

class ThemeSettingDropDown extends StatefulWidget {
  const ThemeSettingDropDown({
    super.key,
    required this.label,
    required this.currentValue,
    required this.popupBuilder,
  });

  final String label;
  final String currentValue;
  final Widget Function(BuildContext) popupBuilder;

  @override
  State<ThemeSettingDropDown> createState() => _ThemeSettingDropDownState();
}

class _ThemeSettingDropDownState extends State<ThemeSettingDropDown> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FlowyText.medium(
            widget.label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppFlowyPopover(
          direction: PopoverDirection.bottomWithRightAligned,
          popupBuilder: widget.popupBuilder,
          constraints: const BoxConstraints(
            minWidth: 80,
            maxWidth: 160,
            maxHeight: 400,
          ),
          child: FlowyTextButton(
            widget.currentValue,
            fontColor: Theme.of(context).colorScheme.onBackground,
            fillColor: Colors.transparent,
          ),
        ),
      ],
    );
  }
}
