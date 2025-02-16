import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/models/api_result.model.dart';
import 'package:i_iwara/app/services/config_service.dart';
import 'package:i_iwara/app/services/translation_service.dart';
import 'package:i_iwara/app/ui/widgets/translation_powered_by_widget.dart';
import 'package:i_iwara/common/constants.dart';
import 'package:i_iwara/i18n/strings.g.dart' as slang;
import 'package:i_iwara/utils/vibrate_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:i_iwara/app/ui/widgets/ai_translation_toggle_button.dart';
import 'package:i_iwara/app/ui/widgets/translation_language_selector.dart';

class TranslationDialog extends StatefulWidget {
  final String text;
  final bool defaultLanguageKeyMode;

  const TranslationDialog({
    super.key,
    required this.text,
    this.defaultLanguageKeyMode = true,
  });

  @override
  State<TranslationDialog> createState() => _TranslationDialogState();
}

class _TranslationDialogState extends State<TranslationDialog> {
  final ConfigService _configService = Get.find();
  final TranslationService _translationService = Get.find();

  bool _isTranslating = false;
  String? _translatedText;
  String? _error;

  Future<void> _handleTranslation() async {
    if (_isTranslating) return;

    if (!mounted) return;
    setState(() {
      _isTranslating = true;
      _error = null;
    });

    final targetLanguage = widget.defaultLanguageKeyMode 
        ? null 
        : _configService.currentTargetLanguage;

    ApiResult<String> result = await _translationService.translate(
      widget.text,
      targetLanguage: targetLanguage,
    );

    if (!mounted) return;
    setState(() {
      _isTranslating = false;
      if (result.isSuccess) {
        _translatedText = result.data;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // 弹窗出现后自动开始翻译
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleTranslation();
    });
  }

  Widget _buildLanguageSelector() {
    final configService = Get.find<ConfigService>();
    final t = slang.Translations.of(context);

    final currentLanguage = widget.defaultLanguageKeyMode
        ? configService.currentTranslationLanguage
        : configService.currentTargetLanguage;

    final updateMethod = widget.defaultLanguageKeyMode
        ? configService.updateTranslationLanguage
        : configService.updateTargetLanguage;

    final selectedSort = CommonConstants.translationSorts.firstWhere(
      (sort) => sort.extData == currentLanguage,
      orElse: () => CommonConstants.translationSorts.first,
    );
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TranslationLanguageSelector(
          usePopupMenu: true,
          selectedLanguage: selectedSort,
          onLanguageSelected: (sort) {
            updateMethod(sort);
            setState(() => _translatedText = null);
            _handleTranslation();
          },
        ),
      ],
    );
  }

  Widget _buildTextContainer(
    BuildContext context, {
    required String title,
    required Widget content,
  }) {
    final t = slang.Translations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: title == t.common.originalText
              ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.15)
              : null,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title == t.common.originalText)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: content,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: content,
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    children: [
                      if (title == t.common.translationResult)
                        translationPoweredByWidget(context, fontSize: 12),
                      if (title == t.common.translationResult && _translatedText != null)
                        Tooltip(
                          message: t.download.copy,
                          child: IconButton(
                            icon: const Icon(Icons.content_copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _translatedText!));
                              VibrateUtils.vibrate();
                              Get.showSnackbar(GetSnackBar(
                                message: t.download.copySuccess,
                                duration: const Duration(seconds: 2),
                              ));
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: '80%'.toString().contains('%') 
                ? MediaQuery.of(context).size.width * 0.8 
                : double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: '60%'.toString().contains('%') 
                ? MediaQuery.of(context).size.width * 0.6 
                : double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = slang.Translations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildLanguageSelector(),
                  const Spacer(),
                  const AITranslationToggleButton(compact: true),
                ],
              ),
            ),
            const Divider(height: 1),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 原文
                      _buildTextContainer(
                        context,
                        title: t.common.originalText,
                        content: SelectableText(widget.text),
                      ),

                      const SizedBox(height: 16),

                      // 译文
                      _buildTextContainer(
                        context,
                        title: t.common.translationResult,
                        content: _isTranslating
                            ? _buildShimmerLoading(theme)
                            : _error != null
                                ? Text(
                                    _error!,
                                    style: TextStyle(color: theme.colorScheme.error),
                                  )
                                : SelectableText(_translatedText ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
