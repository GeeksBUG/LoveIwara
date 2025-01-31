import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/services/app_service.dart';
import 'package:i_iwara/app/services/config_service.dart';
import 'package:i_iwara/app/services/translation_service.dart';
import 'package:i_iwara/app/ui/widgets/MDToastWidget.dart';
import 'package:oktoast/oktoast.dart';
import 'package:i_iwara/app/models/api_result.model.dart';
import 'dart:convert';
import 'dart:async';
import 'package:i_iwara/i18n/strings.g.dart' as slang;

class AITranslationSettingsPage extends StatelessWidget {
  final bool isWideScreen;

  const AITranslationSettingsPage({super.key, this.isWideScreen = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              title: Text(slang.t.translation.translation),
              elevation: 2,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
      body: AITranslationSettingsWidget(),
    );
  }
}

class AITranslationSettingsWidget extends StatefulWidget {
  const AITranslationSettingsWidget({super.key});

  @override
  State<AITranslationSettingsWidget> createState() =>
      _AITranslationSettingsWidgetState();
}

class _AITranslationSettingsWidgetState
    extends State<AITranslationSettingsWidget> {
  final ConfigService configService = Get.find();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final RxBool _isAIEnabled = false.obs;
  final RxBool _isTesting = false.obs;
  final RxBool _isConnectionValid = false.obs;
  final RxBool _hasTested = false.obs;
  final TranslationService translationService = Get.find();
  final Rx<AITestResult?> _testResult = Rx<AITestResult?>(null);
  final debounceDuration = const Duration(milliseconds: 500);
  final GlobalKey<FormState> _formKey = GlobalKey();
  late final TextEditingController _maxTokensController;
  late final TextEditingController _temperatureController;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text =
        configService[ConfigService.AI_TRANSLATION_BASE_URL];
    _modelController.text = configService[ConfigService.AI_TRANSLATION_MODEL];
    _apiKeyController.text =
        configService[ConfigService.AI_TRANSLATION_API_KEY];
    updateSettings();
    _maxTokensController = TextEditingController(
        text:
            configService[ConfigService.AI_TRANSLATION_MAX_TOKENS].toString());
    _temperatureController = TextEditingController(
        text: configService[ConfigService.AI_TRANSLATION_TEMPERATURE]
            .toStringAsFixed(1));
  }

  void updateSettings() {
    _isConnectionValid.value = false;
    _hasTested.value = false;
    _isAIEnabled.value = false;
    _testResult.value = null;
    configService[ConfigService.USE_AI_TRANSLATION] = false;
  }

  Future<void> _testConnection() async {
    _isTesting.value = true;
    final result = await translationService.testAITranslation(
      _baseUrlController.text.trim(),
      _modelController.text.trim(),
      _apiKeyController.text.trim(),
    );
    _testResult.value = result.data;
    _isConnectionValid.value = result.data?.connectionValid ?? false;
    _hasTested.value = true;
    _isTesting.value = false;
  }

  void _showValidationDialog() {
    Get.dialog(
      AlertDialog(
        // title: Text('需要验证'),
        title: Text(slang.t.translation.needVerification),
        content: Text(slang.t.translation.needVerificationContent),
        actions: [
          TextButton(
            onPressed: () => AppService.tryPop(),
            child: Text(slang.t.translation.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDisclaimerCard(context),
        _buildAPIConfigSection(context),
        _buildPreviewSection(context),
        _buildTestConnectionSection(context),
        _buildEnableSection(context),
        const SafeArea(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _buildDisclaimerCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: colorScheme.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(slang.t.translation.disclaimer,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: RichText(
                text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant, height: 1.5),
                    children: [
                  TextSpan(
                      text: '${slang.t.translation.riskWarning}:\n',
                      style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500)),
                  TextSpan(
                    text: '• ${slang.t.translation.dureToRisk1}\n'
                        '• ${slang.t.translation.dureToRisk2}\n\n',
                  ),
                  TextSpan(
                      text: '${slang.t.translation.operationSuggestion}:\n',
                      style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500)),
                  TextSpan(
                      text: '1. ${slang.t.translation.operationSuggestion1}\n'
                          '2. ${slang.t.translation.operationSuggestion2}\n')
                ])),
          )
        ],
      ),
    );
  }

  Widget _buildAPIConfigSection(BuildContext context) {
    return Form(
      key: _formKey,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slang.t.translation.apiConfig,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(slang.t.translation.modifyConfigWillAutoCloseAITranslation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.2)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 16,
                children: [
                  _buildInputSection(
                    context: context,
                    label: slang.t.translation.apiAddress,
                    controller: _baseUrlController,
                    hintText: 'https://api.example.com/v1',
                    configKey: ConfigService.AI_TRANSLATION_BASE_URL,
                    icon: Icons.link,
                  ),
                  _buildInputSection(
                    context: context,
                    label: slang.t.translation.modelName,
                    controller: _modelController,
                    hintText: slang.t.translation.modelNameHintText,
                    configKey: ConfigService.AI_TRANSLATION_MODEL,
                    icon: Icons.model_training,
                  ),
                  _buildApiKeyInputSection(context),
                  _buildNumberInputSection(
                    context: context,
                    label: slang.t.translation.maxTokens,
                    configKey: ConfigService.AI_TRANSLATION_MAX_TOKENS,
                    icon: Icons.numbers,
                    hintText: slang.t.translation.maxTokensHintText,
                    controller: _maxTokensController,
                    defaultValue:
                        configService[ConfigService.AI_TRANSLATION_MAX_TOKENS],
                  ),
                  _buildNumberInputSection(
                    context: context,
                    label: slang.t.translation.temperature,
                    configKey: ConfigService.AI_TRANSLATION_TEMPERATURE,
                    icon: Icons.thermostat,
                    hintText: slang.t.translation.temperatureHintText,
                    controller: _temperatureController,
                    defaultValue:
                        configService[ConfigService.AI_TRANSLATION_TEMPERATURE],
                    isDouble: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestConnectionSection(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(slang.t.translation.testConnection,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                _buildTestButton(),
              ],
            ),
          ),
          const Divider(height: 1),
          Obx(() {
            if (_testResult.value == null) {
              return _buildInfoCard(
                context: context,
                child: Text(slang.t.translation.clickTestButtonToVerifyAPIConnection,
                    style: Theme.of(context).textTheme.bodyMedium),
              );
            }
            return _buildTestResultSection(context);
          }),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(slang.t.translation.requestPreview,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildRequestPreview(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableSection(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Obx(() => SwitchListTile(
            title:
                Text(slang.t.translation.enableAITranslation, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(_isAIEnabled.value ? slang.t.translation.enabled : slang.t.translation.disabled,
                style: Theme.of(context).textTheme.bodySmall),
            value: _isAIEnabled.value,
            onChanged: _handleSwitchChange,
            secondary: Icon(Icons.translate,
                color: Theme.of(context).colorScheme.primary),
          )),
    );
  }

  Widget _buildTestButton() {
    return Obx(() => ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          onPressed: _handleTestConnection,
          icon: _isTesting.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bolt, size: 20),
          label: Text(_isTesting.value ? slang.t.translation.testing : slang.t.translation.testNow),
        ));
  }

  Widget _buildTestResultSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(() {
      final isValid = _testResult.value!.connectionValid;
      return _buildInfoCard(
        color:
            isValid ? colorScheme.primaryContainer : colorScheme.errorContainer,
        context: context,
        child: Column(
          spacing: 16,
          children: [
            _buildStatusRow(
              slang.t.translation.connectionStatus,
              isValid ? slang.t.translation.success : slang.t.translation.failed,
              isValid,
              successColor: colorScheme.onPrimaryContainer,
              errorColor: colorScheme.onErrorContainer,
            ),
            _buildStatusRow(
              slang.t.translation.information,
              _testResult.value!.custMessage,
              _testResult.value!.custMessage.isNotEmpty,
              successColor: colorScheme.onPrimaryContainer,
              errorColor: colorScheme.onErrorContainer,
            ),
            if (_testResult.value!.rawResponse != null) ...[
              ExpansionTile(
                title: Text(slang.t.translation.viewRawResponse,
                    style: Theme.of(context).textTheme.bodySmall),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        _formatJson(_testResult.value!.rawResponse!),
                        style: TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  )
                ],
              )
            ]
          ],
        ),
      );
    });
  }

  Widget _buildStatusRow(
    String label,
    String value,
    bool isSuccess, {
    Color? successColor,
    Color? errorColor,
  }) {
    final colorScheme = Get.context!.theme.colorScheme;
    final effectiveSuccessColor = successColor ?? colorScheme.primary;
    final effectiveErrorColor = errorColor ?? colorScheme.error;

    return Row(
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? effectiveSuccessColor : effectiveErrorColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.onSurfaceVariant)),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isSuccess
                          ? effectiveSuccessColor
                          : effectiveErrorColor)),
            ],
          ),
        )
      ],
    );
  }

  void _handleTestConnection() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      showToastWidget(
          MDToastWidget(message: slang.t.translation.pleaseCheckInputParametersFormat, type: MDToastType.error),
          position: ToastPosition.bottom);
      return;
    }

    if (_baseUrlController.text.isEmpty ||
        _modelController.text.isEmpty ||
        _apiKeyController.text.isEmpty) {
      showToastWidget(
          MDToastWidget(message: slang.t.translation.pleaseFillInAPIAddressModelNameAndKey, type: MDToastType.warning),
          position: ToastPosition.bottom);
      return;
    }

    _testConnection();
  }

  void _handleSwitchChange(bool value) {
    final form = _formKey.currentState;
    if (value) {
      if (form == null || !form.validate()) {
        showToastWidget(
            // MDToastWidget(message: '请先填写有效的配置参数', type: MDToastType.error),
            MDToastWidget(message: slang.t.translation.pleaseFillInValidConfigurationParameters, type: MDToastType.error),
            position: ToastPosition.bottom);
        return;
      }
      if (!_isConnectionValid.value) {
        _showValidationDialog();
        return;
      }
      if (!_hasTested.value) {
        showToastWidget(
            // MDToastWidget(message: '请先完成连接测试', type: MDToastType.warning),
            MDToastWidget(message: slang.t.translation.pleaseCompleteConnectionTest, type: MDToastType.warning),
            position: ToastPosition.bottom);
        return;
      }
    }
    _isAIEnabled.value = value;
    configService[ConfigService.USE_AI_TRANSLATION] = value;
  }

  Widget _buildRequestPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      final baseUrl =
          configService[ConfigService.AI_TRANSLATION_BASE_URL] ?? '';
      final model = configService[ConfigService.AI_TRANSLATION_MODEL] ?? '';
      final apiKey = configService[ConfigService.AI_TRANSLATION_API_KEY] ?? '';

      final endpoint = baseUrl.isNotEmpty
          ? '${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}chat/completions'
          : slang.t.translation.notConfigured;

      final maxTokens =
          configService[ConfigService.AI_TRANSLATION_MAX_TOKENS] ?? 500;
      final temperature =
          configService[ConfigService.AI_TRANSLATION_TEMPERATURE] ?? 0.3;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigRow(
              icon: Icons.link,
              label: '${slang.t.translation.apiEndpoint}:',
              value: endpoint,
              valueStyle: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  color: colorScheme.onSurfaceVariant),
              context: context),
          _buildConfigRow(
              icon: Icons.model_training,
              label: '${slang.t.translation.modelName}:',
              value: model.isNotEmpty ? model : slang.t.translation.notConfigured,
              warning: model.isEmpty,
              context: context),
          _buildConfigRow(
              icon: Icons.key,
              label: '${slang.t.translation.authenticationStatus}:',
              value: apiKey.isNotEmpty ? slang.t.translation.configuredKey : slang.t.translation.notConfiguredKey,
              warning: apiKey.isEmpty,
              context: context),
          _buildConfigRow(
              icon: Icons.numbers,
              label: '${slang.t.translation.maxTokens}:',
              value: maxTokens.toString(),
              context: context),
          _buildConfigRow(
              icon: Icons.thermostat,
              label: '${slang.t.translation.temperature}:',
              value: temperature.toStringAsFixed(1),
              context: context),
        ],
      );
    });
  }

  Widget _buildConfigRow(
      {required IconData icon,
      required String label,
      required String value,
      bool warning = false,
      TextStyle? valueStyle,
      required BuildContext context}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value,
                    style: valueStyle ??
                        TextStyle(
                            color: warning
                                ? colorScheme.error
                                : colorScheme.onSurface,
                            fontFamily: 'Roboto')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInputSection({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String configKey,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 20,
                color: Get.isDarkMode ? Colors.white70 : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return slang.t.translation.thisFieldCannotBeEmpty;
            }
            return null;
          },
          onChanged: (value) {
            configService[configKey] = value;
            if (configKey == ConfigService.AI_TRANSLATION_BASE_URL ||
                configKey == ConfigService.AI_TRANSLATION_MODEL ||
                configKey == ConfigService.AI_TRANSLATION_API_KEY) {
              configService[ConfigService.USE_AI_TRANSLATION] = false;
              _isAIEnabled.value = false;
              _isConnectionValid.value = false;
              _hasTested.value = false;
              _testResult.value = null;
            }
          },
        ),
      ],
    );
  }

  Widget _buildApiKeyInputSection(BuildContext context) {
    final RxBool obscureText = true.obs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.key,
                size: 20,
                color: Get.isDarkMode ? Colors.white70 : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(slang.t.translation.apiKey, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() => TextFormField(
              controller: _apiKeyController,
              obscureText: obscureText.value,
              decoration: InputDecoration(
                hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () => obscureText.toggle(),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return slang.t.translation.apiKeyCannotBeEmpty;
                }
                return null;
              },
              onChanged: (value) {
                configService[ConfigService.AI_TRANSLATION_API_KEY] = value;
                configService[ConfigService.USE_AI_TRANSLATION] = false;
                _isAIEnabled.value = false;
                _isConnectionValid.value = false;
                _hasTested.value = false;
                _testResult.value = null;
              },
            )),
      ],
    );
  }

  Widget _buildNumberInputSection({
    required BuildContext context,
    required String label,
    required String configKey,
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    required num defaultValue,
    bool isDouble = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isDouble
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            errorMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return slang.t.translation.thisFieldCannotBeEmpty;
            if (isDouble) {
              final numValue = double.tryParse(value);
              if (numValue == null) return slang.t.translation.pleaseEnterValidNumber;
              // if (numValue < 0 || numValue > 2) return '范围0.0-2.0';
              if (numValue < 0 || numValue > 2) return '${slang.t.translation.range}${slang.t.translation.temperatureHintText}';
            } else {
              final intValue = int.tryParse(value);
              if (intValue == null) return slang.t.translation.pleaseEnterValidNumber;
              if (intValue <= 0) return '${slang.t.translation.mustBeGreaterThan}0';
            }
            return null;
          },
          onChanged: (value) {
            if (value.isEmpty) return;

            final parsedValue = isDouble
                ? double.tryParse(value) ?? defaultValue.toDouble()
                : int.tryParse(value) ?? defaultValue.toInt();

            final clampedValue = isDouble
                ? parsedValue.clamp(0.0, 2.0)
                : parsedValue.clamp(1, 10000);

            configService[configKey] = clampedValue;

            if (configKey == ConfigService.AI_TRANSLATION_MAX_TOKENS ||
                configKey == ConfigService.AI_TRANSLATION_TEMPERATURE) {
              configService[ConfigService.USE_AI_TRANSLATION] = false;
              _isAIEnabled.value = false;
            }

            if (isDouble && value.endsWith('.') && !value.contains('..')) {
              return;
            }
            controller.value = controller.value.copyWith(
                text: isDouble
                    ? clampedValue.toStringAsFixed(1)
                    : clampedValue.toString(),
                selection: TextSelection.collapsed(
                    offset: clampedValue.toString().length));
          },
          inputFormatters: [
            if (isDouble)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
            if (!isDouble) FilteringTextInputFormatter.digitsOnly
          ],
        ),
      ],
    );
  }

  String _formatJson(String jsonString) {
    try {
      final parsed = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(parsed);
    } catch (e) {
      return jsonString;
    }
  }

  Widget _buildInfoCard({
    Color? color,
    required BuildContext context,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: theme.colorScheme.outlineVariant, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
