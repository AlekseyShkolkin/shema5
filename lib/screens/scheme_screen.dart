import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/scheme_data.dart';
import '../models/apparatus.dart';
import '../models/task.dart';
import '../data/tasks_data.dart';
import '../data/dependencies_data.dart';

class SchemeScreen extends StatefulWidget {
  const SchemeScreen({super.key});

  @override
  _SchemeScreenState createState() => _SchemeScreenState();
}

class _SchemeScreenState extends State<SchemeScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, String> _initialApparatusStates = {};
  Map<String, String> _initialApparatusStatuses = {};
  double _scale = 1.0;
  Apparatus? _selectedApparatus;
  final TransformationController _transformationController =
      TransformationController();

  final AppSettings appSettings = AppSettings();
  bool _enableAdditionalSafetyMeasures = false;

  void _toggleAdditionalSafetyMeasures(bool value) {
    setState(() {
      _enableAdditionalSafetyMeasures = value;
    });
  }

  @override
  void initState() {
    super.initState();
    _saveInitialStates();
  }

  void _saveInitialStates() {
    // Сохраняем исходные состояния из scheme_data.dart
    for (var apparatus in apparatusList) {
      _initialApparatusStates[apparatus.id] = apparatus.state;
      _initialApparatusStatuses[apparatus.id] = apparatus.status;
    }
  }

  TrainingTask? _currentTask;
  List<TaskStep> _completedSteps = [];
  List<String> _mistakes = [];
  bool _isTaskMode = false;

  Text? _getActionDisabledReason(Apparatus apparatus, ApparatusAction action) {
    if (action.id == 'pz' || action.id.contains('zz')) {
      // Проверяем специальные сообщения для заземления
      final groundingReason = _getGroundingDisabledReason(apparatus);
      if (groundingReason != null) {
        return Text(
          groundingReason,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        );
      }

      // Стандартная проверка отключенного состояния
      if (apparatus.state != 'off') {
        return const Text(
          'Сначала необходимо отключить аппарат',
          style: TextStyle(color: Colors.red, fontSize: 12),
        );
      }
    }

    if (action.id == 'turn_on') {
      final enableReason = _getEnableDisabledReason(apparatus);
      if (enableReason != null) {
        return Text(
          enableReason,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        );
      }
    }

    if (action.id == 'turn_off' && apparatus.state == 'off') {
      return const Text(
        'Аппарат уже отключен',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    return null;
  }

// Доступные действия для аппаратов
  Map<String, List<ApparatusAction>> get apparatusActions {
    // Базовые действия для всех аппаратов (кроме passive)
    List<ApparatusAction> getBaseActions(String apparatusType) {
      return [
        ApparatusAction(
          id: 'turn_on',
          name: 'Включить',
          onSelected: (apparatus) {
            apparatus.changeState('on');
            apparatus.changeStatus('on');
            if (_enableAdditionalSafetyMeasures) {
              apparatus.clearSafetyMeasures();
            }
          },
          isEnabled: (apparatus) =>
              apparatus.state == 'off' &&
              apparatus.status != 'zz' &&
              _canEnableApparatus(apparatus),
        ),
        ApparatusAction(
          id: 'turn_off',
          name: 'Отключить',
          description:
              'Произведены необходимые отключения и (или) отсоединения',
          executionOrder: 1,
          onSelected: (apparatus) {
            apparatus.changeState('off');
            apparatus.changeStatus('off');
            if (_enableAdditionalSafetyMeasures) {
              apparatus.clearSafetyMeasures();
            }
          },
          isEnabled: (apparatus) => apparatus.state == 'on',
        ),
      ];
    }

    // Дополнительные мероприятия (общие для всех аппаратов)
    List<ApparatusAction> getSafetyMeasuresActions() {
      if (!_enableAdditionalSafetyMeasures) return [];

      return [
        ApparatusAction(
          id: 'lock',
          name: 'Запереть',
          description:
              'Приняты меры, препятствующие подаче напряжения на место работы',
          executionOrder: 2,
          onSelected: (apparatus) {
            apparatus.addSafetyMeasure('locked');
          },
          isEnabled: (apparatus) =>
              apparatus.state == 'off' && !apparatus.hasSafetyMeasure('locked'),
          isSafetyMeasure: true,
        ),
        ApparatusAction(
          id: 'prohibit_sign',
          name: 'Вывесить запрещающий плакат',
          description:
              'На приводах ручного и на ключах дистанционного управления вывешены запрещающие плакаты',
          executionOrder: 3,
          onSelected: (apparatus) {
            apparatus.addSafetyMeasure('prohibit_sign');
          },
          isEnabled: (apparatus) =>
              apparatus.state == 'off' &&
              apparatus.hasSafetyMeasure('locked') &&
              !apparatus.hasSafetyMeasure('prohibit_sign'),
          isSafetyMeasure: true,
        ),
        ApparatusAction(
          id: 'check_voltage',
          name: 'Проверить отсутствие напряжения',
          description: 'Проверено отсутствие напряжения на токоведущих частях',
          executionOrder: 4,
          onSelected: (apparatus) {
            apparatus.addSafetyMeasure('voltage_checked');
          },
          isEnabled: (apparatus) =>
              apparatus.state == 'off' &&
              apparatus.hasSafetyMeasure('locked') &&
              apparatus.hasSafetyMeasure('prohibit_sign') &&
              !apparatus.hasSafetyMeasure('voltage_checked'),
          isSafetyMeasure: true,
        ),
      ];
    }

    // Действия с заземлением (для аппаратов, которые поддерживают заземление)
    List<ApparatusAction> getGroundingActions(String apparatusType) {
      final baseActions = <ApparatusAction>[];

      // Установка заземления
      baseActions.add(ApparatusAction(
        id: 'zz_mode',
        name: apparatusType == 'opora'
            ? 'Установить ПЗ'
            : 'Установить заземление',
        description: apparatusType == 'opora'
            ? 'Установлено переносное заземление'
            : 'Установлено переносное заземление (включены заземляющие ножи)',
        executionOrder: _enableAdditionalSafetyMeasures ? 5 : 2,
        onSelected: (apparatus) {
          if (apparatusType == 'opora') {
            apparatus.changeStatus('zz');
          } else {
            apparatus.changeState('off');
            apparatus.changeStatus('zz');
          }
        },
        isEnabled: (apparatus) {
          if (apparatusType == 'opora') {
            return _checkGroundingDependencies(apparatus);
          }

          if (_enableAdditionalSafetyMeasures) {
            return apparatus.state == 'off' &&
                _canInstallGrounding(apparatus) &&
                apparatus.hasSafetyMeasure('locked') &&
                apparatus.hasSafetyMeasure('prohibit_sign') &&
                apparatus.hasSafetyMeasure('voltage_checked');
          } else {
            return apparatus.state == 'off' && _canInstallGrounding(apparatus);
          }
        },
      ));

      // Плакаты после заземления (ТОЛЬКО для не-опор)
      if (_enableAdditionalSafetyMeasures && apparatusType != 'opora') {
        baseActions.add(ApparatusAction(
          id: 'safety_signs',
          name: 'Вывесить указательные и предупреждающие плакаты',
          description: 'Вывешены указательные плакаты "Заземлено"',
          executionOrder: 6,
          onSelected: (apparatus) {
            apparatus.addSafetyMeasure('safety_signs');
          },
          isEnabled: (apparatus) =>
              apparatus.status == 'zz' &&
              !apparatus.hasSafetyMeasure('safety_signs'),
          isSafetyMeasure: true,
        ));
      }

      // Снятие заземления
      baseActions.add(ApparatusAction(
        id: apparatusType == 'opora' ? 'pz_off' : 'zz_mode_off',
        name: apparatusType == 'opora' ? 'Снять ПЗ' : 'Снять заземление',
        executionOrder: _enableAdditionalSafetyMeasures ? 7 : 3,
        onSelected: (apparatus) {
          apparatus.changeStatus('off');
          if (_enableAdditionalSafetyMeasures) {
            apparatus.clearSafetyMeasures();
          }
        },
        isEnabled: (apparatus) => apparatus.status == 'zz',
      ));

      return baseActions;
    }

    return {
      'vacuum_breaker': [
        ...getBaseActions('vacuum_breaker'),
        ...getSafetyMeasuresActions(),
        ...getGroundingActions('vacuum_breaker'),
      ],
      'circuit_breaker': [
        ...getBaseActions('circuit_breaker'),
        ...getSafetyMeasuresActions(),
        ...getGroundingActions('circuit_breaker'),
      ],
      'avtomat': [
        ...getBaseActions('avtomat'),
        // Для автоматических выключателей можно добавить только базовые мероприятия
        ...getSafetyMeasuresActions().where((action) =>
            action.id != 'zz_mode' &&
            action.id != 'zz_mode_off' &&
            action.id != 'safety_signs'),
      ],
      'opora': [
        ApparatusAction(
          id: 'check_voltage',
          name: 'Проверить отсутствие напряжения',
          description: 'Проверено отсутствие напряжения на токоведущих частях',
          executionOrder: 1,
          onSelected: (apparatus) {
            apparatus.addSafetyMeasure('voltage_checked');
          },
          isEnabled: (apparatus) => !apparatus
              .hasSafetyMeasure('voltage_checked'), // ← ТОЛЬКО ЭТА ПРОВЕРКА
          isSafetyMeasure: true,
        ),
        ApparatusAction(
          id: 'pz',
          name: 'Установить ПЗ',
          description: 'Установлено переносное заземление',
          executionOrder: 2,
          onSelected: (apparatus) {
            apparatus.changeStatus('zz');
          },
          isEnabled: (apparatus) {
            if (_enableAdditionalSafetyMeasures) {
              return _checkGroundingDependencies(apparatus) &&
                  apparatus.hasSafetyMeasure('voltage_checked');
            } else {
              return _checkGroundingDependencies(apparatus);
            }
          },
        ),
        ApparatusAction(
          id: 'pz_off',
          name: 'Снять ПЗ',
          executionOrder: 4,
          onSelected: (apparatus) {
            apparatus.changeStatus('off');
            if (_enableAdditionalSafetyMeasures) {
              apparatus.clearSafetyMeasures();
            }
          },
          isEnabled: (apparatus) => apparatus.status == 'zz',
        ),
      ],
      'passive': [],
    };
  }

  // Вспомогательная функция для получения действий с сортировкой по порядку выполнения
  List<ApparatusAction> getActionsForApparatus(Apparatus apparatus) {
    final String actionKey = apparatus.actionGroup;
    final actions = apparatusActions[actionKey] ?? [];

    List<ApparatusAction> filteredActions;

    if (_isTaskMode) {
      // РЕЖИМ ЗАДАНИЙ: показываем ВСЕ действия
      filteredActions = List.from(actions);
    } else {
      // ТРЕНИРОВОЧНЫЙ РЕЖИМ: показываем ВСЕ действия, но блокируем недоступные
      filteredActions = List.from(actions); // Не фильтруем, показываем все

      // Сортируем по порядку выполнения
      filteredActions
          .sort((a, b) => a.executionOrder.compareTo(b.executionOrder));
    }

    return filteredActions;
  }

  void _showWhyActionDisabled(Apparatus apparatus, ApparatusAction action) {
    String reason = 'Действие недоступно';

    final bool isOn = apparatus.state == 'on';
    final bool isOff = apparatus.state == 'off';
    final bool isGrounded = apparatus.status == 'zz';
    final bool hasLock = apparatus.hasSafetyMeasure('locked');
    final bool hasProhibitSign = apparatus.hasSafetyMeasure('prohibit_sign');
    final bool hasVoltageChecked =
        apparatus.hasSafetyMeasure('voltage_checked');

    switch (action.id) {
      case 'turn_on':
        if (isGrounded)
          reason = 'Нельзя включить заземленный аппарат!';
        else if (hasLock)
          reason = 'Нельзя включить заблокированный аппарат!';
        else if (!isOff)
          reason = 'Аппарат уже включен.';
        else
          reason = 'Выполните предыдущие действия по порядку.';
        break;

      case 'turn_off':
        if (!isOn)
          reason = 'Аппарат уже отключен.';
        else if (isGrounded)
          reason = 'Аппарат уже заземлен.';
        else
          reason = 'Выполните действия по порядку.';
        break;

      case 'lock':
        if (!isOff)
          reason = 'Сначала отключите аппарат.';
        else if (hasLock)
          reason = 'Аппарат уже заблокирован.';
        else if (isGrounded)
          reason = 'Аппарат уже заземлен.';
        else
          reason = 'Выполните отключение аппарата сначала.';
        break;

      case 'prohibit_sign':
        if (!hasLock)
          reason = 'Сначала заблокируйте аппарат.';
        else if (hasProhibitSign)
          reason = 'Плакат уже вывешен.';
        else if (isGrounded)
          reason = 'Аппарат уже заземлен.';
        else
          reason = 'Выполните блокировку аппарата сначала.';
        break;

      case 'check_voltage':
        if (!hasProhibitSign)
          reason = 'Сначала вывесьте запрещающий плакат.';
        else if (hasVoltageChecked)
          reason = 'Напряжение уже проверено.';
        else if (isGrounded)
          reason = 'Аппарат уже заземлен.';
        else
          reason = 'Выполните установку плакатов сначала.';
        break;

      case 'zz_mode':
      case 'pz':
        if (!hasVoltageChecked)
          reason = 'Сначала проверьте отсутствие напряжения.';
        else if (isGrounded)
          reason = 'Заземление уже установлено.';
        else
          reason = 'Выполните проверку напряжения сначала.';
        break;

      case 'safety_signs':
        if (!isGrounded)
          reason = 'Сначала установите заземление.';
        else if (apparatus.hasSafetyMeasure('safety_signs'))
          reason = 'Плакаты уже вывешены.';
        else
          reason = 'Выполните установку заземления сначала.';
        break;

      case 'zz_mode_off':
      case 'pz_off':
        if (!isGrounded)
          reason = 'Заземление не установлено.';
        else
          reason = 'Выполните предыдущие действия.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showTrainingModeFeedback(Apparatus apparatus, ApparatusAction action) {
    String message = '✅ ${action.name} выполнено!';

    // Подсказка о следующем действии
    final nextActions = _getNextAvailableAction(
        apparatus, apparatusActions[apparatus.actionGroup] ?? []);
    if (nextActions.isNotEmpty) {
      message += '\nСледующее: ${nextActions.first.name}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<ApparatusAction> _getNextAvailableAction(
      Apparatus apparatus, List<ApparatusAction> allActions) {
    final availableActions = <ApparatusAction>[];

    // Текущее состояние аппарата
    final bool isOn = apparatus.state == 'on';
    final bool isOff = apparatus.state == 'off';
    final bool isGrounded = apparatus.status == 'zz';
    final bool hasLock = apparatus.hasSafetyMeasure('locked');
    final bool hasProhibitSign = apparatus.hasSafetyMeasure('prohibit_sign');
    final bool hasVoltageChecked =
        apparatus.hasSafetyMeasure('voltage_checked');
    final bool hasSafetySigns = apparatus.hasSafetyMeasure('safety_signs');

    // Определяем какое действие должно быть следующим по строгой последовательности
    for (final action in allActions) {
      bool isAvailable = action.isEnabled(apparatus); // Базовая проверка

      // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА ПОСЛЕДОВАТЕЛЬНОСТИ
      // ДЛЯ ОПОР - ОСОБЫЕ ПРАВИЛА!
      if (isAvailable &&
          (apparatus.type == 'opora' || apparatus.actionGroup == 'opora')) {
        switch (action.id) {
          case 'check_voltage':
            // Для опор проверка напряжения доступна всегда (не зависит от состояния)
            isAvailable = !hasVoltageChecked;
            break;

          case 'pz':
            // Установка ПЗ доступна после проверки напряжения
            isAvailable = hasVoltageChecked && !isGrounded;
            break;

          case 'safety_signs':
            // Плакаты доступны после установки ПЗ
            isAvailable = isGrounded && !hasSafetySigns;
            break;

          case 'pz_off':
            // Снятие ПЗ доступно когда ПЗ установлено
            isAvailable = isGrounded;
            break;

          default:
            // Для остальных действий оставляем как есть
            break;
        }
      }
      // ДЛЯ ОБЫЧНЫХ АППАРАТОВ - СТАРАЯ ЛОГИКА
      else if (isAvailable) {
        switch (action.id) {
          case 'turn_off':
            isAvailable = isOn && !isGrounded;
            break;
          case 'lock':
            isAvailable = isOff && !hasLock && !isGrounded;
            break;
          case 'prohibit_sign':
            isAvailable = isOff && hasLock && !hasProhibitSign && !isGrounded;
            break;
          case 'check_voltage':
            isAvailable = isOff &&
                hasLock &&
                hasProhibitSign &&
                !hasVoltageChecked &&
                !isGrounded;
            break;
          case 'zz_mode':
          case 'pz':
            isAvailable = isOff &&
                hasLock &&
                hasProhibitSign &&
                hasVoltageChecked &&
                !isGrounded;
            break;
          case 'safety_signs':
            isAvailable = isOff && isGrounded && !hasSafetySigns;
            break;
          case 'zz_mode_off':
          case 'pz_off':
            isAvailable = isGrounded;
            break;
          case 'turn_on':
            isAvailable = isOff && !isGrounded && !hasLock;
            break;
        }
      }

      if (isAvailable) {
        availableActions.add(action);
      }
    }

    // Сортируем по порядку выполнения
    availableActions
        .sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

    return availableActions;
  }

  bool _canInstallGrounding(Apparatus apparatus) {
    // Для опор проверяем только зависимости, не их собственное состояние
    if (apparatus.type == 'opora' || apparatus.actionGroup == 'opora') {
      return _checkGroundingDependencies(apparatus);
    }

    // Для всех остальных аппаратов проверяем и состояние и зависимости
    return apparatus.state == 'off' && _checkGroundingDependencies(apparatus);
  }

  bool _checkGroundingDependencies(Apparatus apparatus) {
    // Для опор не проверяем состояние, только зависимости
    if (apparatus.type == 'opora' || apparatus.actionGroup == 'opora') {
      // Только проверка зависимостей от других аппаратов
      if (groundingDependenciesSpecial.containsKey(apparatus.id)) {
        return false;
      }

      // Проверяем условие "И"
      if (groundingDependenciesAND.containsKey(apparatus.id)) {
        final dependencies = groundingDependenciesAND[apparatus.id]!;
        for (var apparatusId in dependencies) {
          final depApparatus = apparatusList.firstWhere(
            (a) => a.id == apparatusId,
            orElse: () => _createDummyApparatus(),
          );
          if (depApparatus.state != 'off') {
            return false;
          }
        }
        return true;
      }

      // Проверяем условие "ИЛИ"
      if (groundingDependenciesOR.containsKey(apparatus.id)) {
        final dependencies = groundingDependenciesOR[apparatus.id]!;
        for (var apparatusId in dependencies) {
          final depApparatus = apparatusList.firstWhere(
            (a) => a.id == apparatusId,
            orElse: () => _createDummyApparatus(),
          );
          if (depApparatus.state == 'off') {
            return true;
          }
        }
        return false;
      }

      return true;
    }
    // Сначала проверяем специальные случаи
    if (groundingDependenciesSpecial.containsKey(apparatus.id)) {
      return false;
    }

    // Проверяем условие "И"
    if (groundingDependenciesAND.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesAND[apparatus.id]!;

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        // Все должны быть отключены (И)
        if (depApparatus.state != 'off') {
          return false;
        }
      }
      return true;
    }

    // Проверяем условие "ИЛИ"
    if (groundingDependenciesOR.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesOR[apparatus.id]!;

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        // Хотя бы один должен быть отключен (ИЛИ)
        if (depApparatus.state == 'off') {
          return true;
        }
      }
      return false;
    }

    return true;
  }

  bool _canEnableApparatus(Apparatus apparatus) {
    // Стандартные проверки
    if (groundingDependenciesSpecial.containsKey(apparatus.id)) {
      return false;
    }

    // Проверки зависимостей заземления
    if (groundingDependenciesAND.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesAND[apparatus.id]!;
      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );
        if (depApparatus.status == 'zz') {
          return false;
        }
      }
    }

    if (groundingDependenciesOR.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesOR[apparatus.id]!;
      bool hasGrounding = false;
      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );
        if (depApparatus.status == 'zz') {
          hasGrounding = true;
          break;
        }
      }
      if (hasGrounding) {
        return false;
      }
    }

    // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: если включены доп. мероприятия
    if (_enableAdditionalSafetyMeasures) {
      // Для заземленного аппарата проверяем выполнение всех мероприятий
      if (apparatus.state == 'off' && apparatus.status == 'zz') {
        final requiredMeasures = [
          'locked',
          'prohibit_sign',
          'voltage_checked',
          'safety_signs'
        ];
        return requiredMeasures
            .every((measure) => apparatus.hasSafetyMeasure(measure));
      }
    }

    return true;
  }

  String? _getEnableDisabledReason(Apparatus apparatus) {
    if (groundingDependenciesSpecial.containsKey(apparatus.id)) {
      return 'Включение запрещено';
    }

    final List<String> groundedApparatus = [];

    // Проверяем условия "И"
    if (groundingDependenciesAND.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesAND[apparatus.id]!;

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        if (depApparatus.status == 'zz') {
          final apparatusName = apparatusList
              .firstWhere((a) => a.id == apparatusId,
                  orElse: () => _createDummyApparatus())
              .name;
          groundedApparatus.add('$apparatusName (установлено ПЗ)');
        }
      }
    }

    // Проверяем условия "ИЛИ"
    if (groundingDependenciesOR.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesOR[apparatus.id]!;

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        if (depApparatus.status == 'zz') {
          final apparatusName = apparatusList
              .firstWhere((a) => a.id == apparatusId,
                  orElse: () => _createDummyApparatus())
              .name;
          groundedApparatus.add('$apparatusName (установлено ПЗ)');
        }
      }
    }

    if (groundedApparatus.isNotEmpty) {
      return 'Сначала снимите ПЗ: ${groundedApparatus.join(', ')}';
    }

    return null;
  }

  String? _getGroundingDisabledReason(Apparatus apparatus) {
    // Специальные случаи
    if (groundingDependenciesSpecial.containsKey(apparatus.id)) {
      return 'Нельзя ставить ПЗ на стороннюю ВЛ';
    }

    // Условие "И"
    if (groundingDependenciesAND.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesAND[apparatus.id]!;
      final List<String> requiredApparatus = [];

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        if (depApparatus.state != 'off') {
          final apparatusName = apparatusList
              .firstWhere((a) => a.id == apparatusId,
                  orElse: () => _createDummyApparatus())
              .name;
          requiredApparatus.add(apparatusName);
        }
      }

      if (requiredApparatus.isNotEmpty) {
        return 'Требуется отключить: ${requiredApparatus.join(', ')}';
      }
    }

    // Условие "ИЛИ"
    if (groundingDependenciesOR.containsKey(apparatus.id)) {
      final dependencies = groundingDependenciesOR[apparatus.id]!;
      final List<String> requiredOptions = [];

      for (var apparatusId in dependencies) {
        final depApparatus = apparatusList.firstWhere(
          (a) => a.id == apparatusId,
          orElse: () => _createDummyApparatus(),
        );

        if (depApparatus.state != 'off') {
          final apparatusName = apparatusList
              .firstWhere((a) => a.id == apparatusId,
                  orElse: () => _createDummyApparatus())
              .name;
          requiredOptions.add(apparatusName);
        }
      }

      if (requiredOptions.isNotEmpty &&
          requiredOptions.length == dependencies.length) {
        return 'Требуется отключить один из перечисленных коммутационных аппаратов: ${requiredOptions.join(', ')}';
      }
    }

    return null;
  }

// Вспомогательный метод для создания dummy-аппарата
  Apparatus _createDummyApparatus() {
    return Apparatus(
      id: 'dummy',
      type: 'dummy',
      actionGroup: 'dummy',
      name: 'Неизвестный аппарат',
      x: 0,
      y: 0,
      width: 0,
      height: 0,
      availableActions: [],
      imagePrefix: 'dummy',
      state: 'on', // Предполагаем включенным для безопасности
      status: 'on',
    );
  }

  double get _maxX {
    double maxX = 0;
    for (var apparatus in apparatusList) {
      double right = apparatus.x + apparatus.width;
      maxX = math.max(maxX, right);
      if (apparatus.labelX != null) {
        maxX = math.max(maxX, apparatus.labelX! + 100);
      }
    }
    return maxX * 1.2;
  }

  double get _maxY {
    double maxY = 0;
    for (var apparatus in apparatusList) {
      double bottom = apparatus.y + apparatus.height;
      maxY = math.max(maxY, bottom);
      if (apparatus.labelY != null) {
        maxY = math.max(maxY, apparatus.labelY! + 30);
      }
    }
    return maxY * 1.2;
  }

  @override
  bool get wantKeepAlive => true;

  String _getApparatusImagePath(Apparatus apparatus) {
    return apparatus.getImagePath();
  }

  void _startTask(TrainingTask task) {
    setState(() {
      _currentTask = task;
      _isTaskMode = true;
      _completedSteps = [];
      _mistakes = [];
      _enableAdditionalSafetyMeasures = true;
      _resetApparatusToInitialState();
    });
  }

  void _resetApparatusToInitialState() {
    for (var apparatus in apparatusList) {
      // Возвращаем аппараты к их исходным состояниям из scheme_data.dart
      apparatus.changeState(_initialApparatusStates[apparatus.id] ?? 'on');
      apparatus.changeStatus(_initialApparatusStatuses[apparatus.id] ?? 'on');
      apparatus.clearSafetyMeasures();
    }

    // Сброс зума
    _transformationController.value = Matrix4.identity();
    _scale = 1.0;
  }

  // НОВЫЙ: Метод для цвета оценки
  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.lightGreen;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 30) return Colors.orangeAccent;
    return Colors.red;
  }

  void _completeTask() {
    final result = _evaluateTask();

    // Определяем заголовок в зависимости от результата
    String title;
    if (result.isCompleted) {
      title = 'Задание выполнено идеально! 🎯';
    } else if (result.earnedScore > 0) {
      title = 'Задание завершено с ошибками';
    } else {
      title = 'Задание провалено ❌';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Оценка
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${result.earnedScore}/${result.maxScore} ⚡',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '(${result.percentage.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: _getScoreColor(result.percentage),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 16),

              // // Прогресс
              // Text(
              //   'Правильно выполнено: ${result.completedCorrectly}/${result.totalSteps} шагов',
              //   style: const TextStyle(fontWeight: FontWeight.bold),
              // ),
              // const SizedBox(height: 8),

              // Ошибки
              if (result.mistakes.isNotEmpty) ...[
                const Text('Ошибки выполнения:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange)),
                ...result.mistakes.map((error) => Text('• $error',
                    style: const TextStyle(color: Colors.orange))),
                const SizedBox(height: 8),
              ],

              // Нарушения безопасности
              if (result.safetyViolations.isNotEmpty) ...[
                const Text('Нарушения безопасности:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                ...result.safetyViolations.map((violation) => Text(
                    '• $violation',
                    style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 8),
              ],

              // Правильные шаги (показываем только если есть что-то правильное)
              if (result.correctSteps.isNotEmpty && result.isCompleted) ...[
                const Text('Правильно выполненные шаги:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                ...result.correctSteps.map((step) => Text('• $step',
                    style: const TextStyle(color: Colors.green))),
              ],

              // Мотивационное сообщение
              if (result.isCompleted) ...[
                const SizedBox(height: 16),
                const Text(
                    'Отличная работа! Все действия выполнены правильно! ✅',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ] else if (result.earnedScore > 0) ...[
                const SizedBox(height: 16),
                const Text('Попробуйте еще раз для улучшения результата! 🔄',
                    style: TextStyle(color: Colors.blue)),
              ] else ...[
                const SizedBox(height: 16),
                const Text(
                    'Необходимо повторить теорию и попробовать снова! 📚',
                    style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isTaskMode = false;
                _currentTask = null;
                _completedSteps = [];
                _mistakes = [];
                _resetApparatusToInitialState(); // Сбрасываем схему при закрытии диалога
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // НОВЫЙ: Обновленный метод оценки
  TaskResult _evaluateTask() {
    int earnedScore = 0;
    int completedCorrectly = 0;
    List<String> mistakes = [];
    List<String> safetyViolations = [];
    List<String> correctSteps = [];

    // Проверяем правильность выполнения шагов (включая мероприятия)
    for (int i = 0; i < _currentTask!.steps.length; i++) {
      if (i < _completedSteps.length) {
        final completedStep = _completedSteps[i];
        final requiredStep = _currentTask!.steps[i];

        bool stepCorrect =
            completedStep.apparatusId == requiredStep.apparatusId &&
                completedStep.requiredAction == requiredStep.requiredAction;

        // Дополнительная проверка для мероприятий
        if (stepCorrect && requiredStep.requiredSafetyMeasure != null) {
          final apparatus = apparatusList.firstWhere(
            (a) => a.id == requiredStep.apparatusId,
            orElse: () => _createDummyApparatus(),
          );
          stepCorrect =
              apparatus.hasSafetyMeasure(requiredStep.requiredSafetyMeasure!);
        }

        if (stepCorrect) {
          earnedScore += 1;
          completedCorrectly += 1;
          correctSteps.add(requiredStep.description);
        } else {
          String mistakeDescription = 'Шаг ${i + 1}: ';
          if (completedStep.apparatusId != requiredStep.apparatusId) {
            mistakeDescription += 'Выбран не тот аппарат';
          } else if (completedStep.requiredAction !=
              requiredStep.requiredAction) {
            mistakeDescription += 'Неправильное действие';
          } else {
            mistakeDescription += 'Не выполнено дополнительное мероприятие';
          }
          mistakeDescription += ' (Ожидалось: ${requiredStep.description})';

          mistakes.add(mistakeDescription);
          earnedScore = math.max(0, earnedScore - 1);
        }
      }
    }

    // Проверяем выполнение всех мероприятий
    for (final step in _currentTask!.steps) {
      if (step.requiredSafetyMeasure != null) {
        final apparatus = apparatusList.firstWhere(
          (a) => a.id == step.apparatusId,
          orElse: () => _createDummyApparatus(),
        );
        if (!apparatus.hasSafetyMeasure(step.requiredSafetyMeasure!)) {
          safetyViolations.add('Не выполнено мероприятие: ${step.description}');
          earnedScore = math.max(0, earnedScore - 1);
        }
      }
    }

    // Штрафы за пропущенные шаги
    final missedSteps = _currentTask!.steps.length - _completedSteps.length;
    if (missedSteps > 0) {
      safetyViolations.add('Пропущено шагов: $missedSteps');
      earnedScore = math.max(0, earnedScore - missedSteps);
    }

    // Дополнительные штрафы
    if (_mistakes.isNotEmpty) {
      safetyViolations.addAll(_mistakes);
      earnedScore = math.max(0, earnedScore - _mistakes.length);
    }

    earnedScore = earnedScore.clamp(0, _currentTask!.maxScore);

    final bool isPerfectlyCompleted =
        completedCorrectly == _currentTask!.steps.length &&
            mistakes.isEmpty &&
            safetyViolations.isEmpty;

    return TaskResult(
      maxScore: _currentTask!.maxScore,
      earnedScore: earnedScore,
      correctSteps: correctSteps,
      mistakes: mistakes,
      safetyViolations: safetyViolations,
      isCompleted: isPerfectlyCompleted,
      totalSteps: _currentTask!.steps.length,
      completedCorrectly: completedCorrectly,
    );
  }

  void _onApparatusAction(Apparatus apparatus, String actionId) {
    if (!_isTaskMode || _currentTask == null) return;
    if (_completedSteps.length >= _currentTask!.steps.length) return;

    final nextStep = _currentTask!.steps[_completedSteps.length];

    // В РЕЖИМЕ ЗАДАНИЙ проверяем только соответствие шагу из tasks_data.dart
    bool isCorrectAction = apparatus.id == nextStep.apparatusId &&
        actionId == nextStep.requiredAction;

    if (isCorrectAction) {
      // ПРАВИЛЬНОЕ ДЕЙСТВИЕ - выполняем изменения на аппарате
      setState(() {
        _completedSteps.add(nextStep);

        // Находим и выполняем действие на аппарате
        final actions = apparatusActions[apparatus.actionGroup] ?? [];
        final action = actions.firstWhere(
          (a) => a.id == actionId,
          orElse: () => _createDummyAction(),
        );

        action.onSelected(apparatus);

        // Принудительно устанавливаем требуемое состояние из задания
        if (nextStep.requiredState.isNotEmpty) {
          if (nextStep.requiredState == 'off') {
            apparatus.changeState('off');
          } else if (nextStep.requiredState == 'zz') {
            apparatus.changeStatus('zz');
          }
        }

        // Принудительно добавляем требуемое мероприятие безопасности
        if (nextStep.requiredSafetyMeasure != null) {
          apparatus.addSafetyMeasure(nextStep.requiredSafetyMeasure!);
        }
      });

      _showSuccessMessage('✅ Правильное действие!');

      if (_completedSteps.length == _currentTask!.steps.length) {
        _completeTask();
      }
    } else {
      // НЕПРАВИЛЬНОЕ ДЕЙСТВИЕ - ФИКСИРУЕМ ОШИБКУ, НО НЕ ВЫПОЛНЯЕМ ДЕЙСТВИЕ НА АППАРАТЕ
      setState(() {
        String errorMessage;

        if (apparatus.id != nextStep.apparatusId) {
          errorMessage =
              'Шаг ${_completedSteps.length + 1}: Выбран не тот аппарат. Ожидалось действие с: ${_getApparatusNameById(nextStep.apparatusId)}';
        } else {
          errorMessage =
              'Шаг ${_completedSteps.length + 1}: Неправильное действие. Ожидалось: ${_getActionNameById(nextStep.requiredAction)}';
        }

        _mistakes.add(errorMessage);

        // НЕ выполняем action.onSelected(apparatus) - это ключевое изменение!
        // Аппараты НЕ изменяются при неправильном действии
      });

      _showSafetyWarning('❌ Неправильное действие! Попробуйте снова.');
    }
  }

// Вспомогательный метод для создания dummy-действия
  ApparatusAction _createDummyAction() {
    return ApparatusAction(
      id: 'dummy',
      name: 'Dummy',
      onSelected: (_) {},
      isEnabled: (_) => false,
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

// Вспомогательные методы для получения названий
  String _getApparatusNameById(String apparatusId) {
    final apparatus = apparatusList.firstWhere(
      (a) => a.id == apparatusId,
      orElse: () => _createDummyApparatus(),
    );
    return apparatus.name;
  }

  String _getActionNameById(String actionId) {
    final allActions = apparatusActions.values.expand((x) => x).toList();
    final action = allActions.firstWhere(
      (a) => a.id == actionId,
      orElse: () => ApparatusAction(
        id: actionId,
        name: actionId,
        onSelected: (_) {},
        isEnabled: (_) => true,
      ),
    );
    return action.name;
  }

  void _showActionMenu(Apparatus apparatus, BuildContext context) {
    final actions = getActionsForApparatus(apparatus);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    apparatus.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isTaskMode && _currentTask != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Задание: ${_currentTask!.title}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Шаг ${_completedSteps.length + 1} из ${_currentTask!.steps.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (actions.isEmpty) const Text('Нет доступных действий'),
                  ...(_isTaskMode ? _shuffleActions(actions) : actions)
                      .map((action) {
                    final bool isActuallyEnabled = action.isEnabled(apparatus);
                    final bool canBeSelected =
                        _isTaskMode ? true : isActuallyEnabled;

                    return ListTile(
                      leading: _getActionIcon(action.id),
                      title: Text(
                        action.name,
                        style: TextStyle(
                          color: _isTaskMode
                              ? Colors.black
                              : (isActuallyEnabled
                                  ? Colors.black
                                  : Colors.grey),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      subtitle: _enableAdditionalSafetyMeasures &&
                              action.description.isNotEmpty
                          ? Text(
                              action.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: _isTaskMode
                                    ? Colors.black54
                                    : (isActuallyEnabled
                                        ? Colors.black54
                                        : Colors.grey),
                              ),
                            )
                          : null,
                      trailing: _isTaskMode
                          ? const Icon(Icons.help_outline,
                              color: Colors.blue, size: 16)
                          : (isActuallyEnabled
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green, size: 16)
                              : const Icon(Icons.block,
                                  color: Colors.red, size: 16)),
                      onTap: canBeSelected
                          ? () {
                              Navigator.pop(context);
                              setState(() {
                                // КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: В режиме заданий НЕ выполняем действие здесь
                                if (!_isTaskMode) {
                                  // В тренировочном режиме выполняем действие сразу
                                  action.onSelected(apparatus);
                                  _showTrainingModeFeedback(apparatus, action);
                                  _updateRelatedApparatus(apparatus, action.id);
                                } else {
                                  // В режиме заданий проверяем правильность в _onApparatusAction
                                  // и только там выполняем действие если оно правильное
                                  _onApparatusAction(apparatus, action.id);
                                }
                              });
                            }
                          : null,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Метод для перемешивания действий в режиме заданий
  List<ApparatusAction> _shuffleActions(List<ApparatusAction> actions) {
    final shuffled = List<ApparatusAction>.from(actions);
    shuffled.shuffle();
    return shuffled;
  }

// НОВЫЙ МЕТОД: Отображение информации о текущем шаге
  Widget _buildCurrentStepInfo(Apparatus apparatus) {
    final nextStep = _currentTask!.steps[_completedSteps.length];
    final isNextStep = apparatus.id == nextStep.apparatusId;
    final isCorrectApparatus = isNextStep;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCorrectApparatus
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCorrectApparatus ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isCorrectApparatus ? Icons.check_circle : Icons.warning,
                    color: isCorrectApparatus ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCorrectApparatus ? 'Текущий шаг' : 'Не тот аппарат',
                      style: TextStyle(
                        color:
                            isCorrectApparatus ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${_completedSteps.length + 1}/${_currentTask!.steps.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                nextStep.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isCorrectApparatus ? Colors.black : Colors.orange,
                  fontWeight:
                      isCorrectApparatus ? FontWeight.normal : FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (nextStep.safetyNote.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '⚠ ${nextStep.safetyNote}',
                  style: const TextStyle(fontSize: 10, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

// НОВЫЙ МЕТОД: Индикатор прогресса
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _currentTask!.steps.length > 0
              ? _completedSteps.length / _currentTask!.steps.length
              : 0,
          backgroundColor: Colors.grey[300],
          color: Colors.blue,
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        Text(
          'Выполнено: ${_completedSteps.length}/${_currentTask!.steps.length} шагов',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showTaskSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.7, // Ограничиваем высоту
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Выберите задание',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              // Позволяем списку занимать доступное пространство
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: trainingTasks.length,
                itemBuilder: (context, index) {
                  final task = trainingTasks[index];
                  return ListTile(
                    leading: const Icon(Icons.bolt, color: Colors.amber),
                    title: Text(task.title),
                    subtitle: Text('Сложность: ${task.difficulty}'),
                    trailing: Text('${task.maxScore} ⚡'),
                    onTap: () {
                      Navigator.pop(context);
                      _startTask(task);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateRelatedApparatus(Apparatus changedApparatus, String actionId) {}

  void _showSafetyWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }

  bool _canApparatusChangeState(Apparatus apparatus) {
    // Аппараты, которые НЕ могут менять состояние (всегда белый текст)
    final nonSwitchableTypes = [
      'opora',
      'passive',
      'namevl1',
    ];

    return !nonSwitchableTypes.contains(apparatus.type) &&
        !nonSwitchableTypes.contains(apparatus.actionGroup);
  }

  Widget _buildApparatusLabel(Apparatus apparatus) {
    if (!apparatus.showLabel) return const SizedBox.shrink();

    // Определяем цвет текста
    Color textColor = Colors.white; // по умолчанию белый

    // Только для аппаратов, которые могут менять состояние
    if (_canApparatusChangeState(apparatus)) {
      if (apparatus.state == 'off') {
        textColor = Colors.redAccent.shade400; // Отключен - красный
      } else if (apparatus.state == 'on') {
        textColor = Colors.lightGreenAccent; // Включен - зеленый
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            apparatus.name,
            style: TextStyle(
              color: textColor,
              fontSize: apparatus.name.length > 20 ? 8 : 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isTaskMode
              ? _currentTask?.title ?? 'Режим заданий'
              : 'Режим тренажёра',
          style: const TextStyle(fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isTaskMode) {
              setState(() {
                _isTaskMode = false;
                _currentTask = null;
                _completedSteps = [];
              });
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        actions: [
          Tooltip(
            message: 'Дополнительные мероприятия по подготовке рабочего места',
            child: Row(
              children: [
                const Icon(Icons.security, size: 16),
                const SizedBox(width: 4),
                Switch(
                  value: _enableAdditionalSafetyMeasures,
                  onChanged: _toggleAdditionalSafetyMeasures,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_isTaskMode)
            IconButton(
              icon: const Icon(Icons.assignment),
              onPressed: _showTaskSelection,
              tooltip: 'Выбрать задание',
            ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () =>
                setState(() => _scale = (_scale * 1.2).clamp(0.1, 5.0)),
            tooltip: 'Увеличить',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () =>
                setState(() => _scale = (_scale / 1.2).clamp(0.1, 5.0)),
            tooltip: 'Уменьшить',
          ),
        ],
      ),
      body: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false,
        minScale: 0.1,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        onInteractionUpdate: (ScaleUpdateDetails details) {
          setState(() => _scale = details.scale);
        },
        child: Container(
            width: _maxX,
            height: _maxY,
            color: Colors.grey[100],
            child: Stack(
              children: [
                // 1. Аппараты
                for (Apparatus apparatus in apparatusList)
                  Positioned(
                    left: apparatus.x,
                    top: apparatus.y,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedApparatus = apparatus);
                        _showActionMenu(apparatus, context);
                      },
                      child: Container(
                        width: apparatus.width,
                        height: apparatus.height,
                        child: apparatus.rotation != 0
                            ? Transform.rotate(
                                angle: apparatus.rotation,
                                child: Image.asset(
                                  _getApparatusImagePath(apparatus),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                _getApparatusImagePath(apparatus),
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  ),

                // 2. Подписи аппаратов
                for (Apparatus apparatus in apparatusList)
                  if (apparatus.showLabel)
                    Positioned(
                      left: apparatus.labelOffset.dx,
                      top: apparatus.labelOffset.dy,
                      child: _buildApparatusLabel(apparatus),
                    ),

                // 3. Индикаторы мероприятий
                for (Apparatus apparatus in apparatusList)
                  if (apparatus.showLabel)
                    Positioned(
                      left: apparatus.labelOffset.dx - 20,
                      top: apparatus.labelOffset.dy - 22,
                      child: _buildSafetyMeasureIndicators(apparatus),
                    ),
              ],
            )),
      ),
      bottomNavigationBar: _isTaskMode
          ? _buildTaskProgressPanel()
          : _selectedApparatus != null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: const Border(
                      top: BorderSide(color: Colors.blue, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        _getApparatusImagePath(_selectedApparatus!),
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text('Выбран: ${_selectedApparatus!.name}'),
                    ],
                  ),
                )
              : null,
    );
  }

  Widget _buildTaskProgressPanel() {
    return GestureDetector(
      onTap: () {
        _showTaskProgressDetails();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        color: Colors.blue[50],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Прогресс-бар
            LinearProgressIndicator(
              value: _currentTask != null
                  ? _completedSteps.length / _currentTask!.steps.length
                  : 0,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
              minHeight: 6,
            ),
            const SizedBox(height: 8),

            // Статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Шаг ${_completedSteps.length + 1} из ${_currentTask?.steps.length ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_mistakes.isNotEmpty)
                  Text(
                    'Ошибок: ${_mistakes.length}',
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),

            // Подсказка
            const SizedBox(height: 4),
            Text(
              'Нажмите для просмотра выполненных шагов',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskProgressDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6, // Уменьшили высоту
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTask?.title ?? 'Задание',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (_currentTask?.description != null)
                          Text(
                            _currentTask!.description!,
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Прогресс
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _currentTask != null
                        ? _completedSteps.length / _currentTask!.steps.length
                        : 0,
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Прогресс: ${_completedSteps.length}/${_currentTask?.steps.length ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${((_completedSteps.length / (_currentTask?.steps.length ?? 1)) * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_mistakes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ошибок: ${_mistakes.length}',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),

            // Список выполненных шагов
            Expanded(
              child: _completedSteps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Шаги ещё не выполнялись',
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Начните выполнение задания',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Выполненные шаги:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._completedSteps.asMap().entries.map((entry) {
                          final index = entry.key;
                          final step = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.description,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (step.safetyNote.isNotEmpty)
                                        Text(
                                          '⚠ ${step.safetyNote}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildSafetyMeasureIndicators(Apparatus apparatus) {
  final indicators = <Widget>[];

  // УБИРАЕМ состояния аппарата (включен/отключен) - теперь это в цвете текста

  // Мероприятия безопасности
  if (apparatus.hasSafetyMeasure('locked')) {
    indicators.add(_buildIndicator(Icons.lock, 'Заблокировано', Colors.red));
  }

  if (apparatus.hasSafetyMeasure('prohibit_sign')) {
    indicators.add(_buildIndicator(
        Icons.do_not_disturb, 'Запрещающий плакат', Colors.red));
  }

  if (apparatus.hasSafetyMeasure('voltage_checked')) {
    indicators.add(_buildIndicator(
        Icons.offline_bolt, 'Напряжение проверено', Colors.green));
  }

  if (apparatus.hasSafetyMeasure('safety_signs')) {
    indicators.add(_buildIndicator(
        Icons.report_problem_rounded, 'Плакат "Заземлено"', Colors.blue));
  }
  // Статус заземления
  if (apparatus.status == 'zz') {
    indicators
        .add(_buildIndicator(Icons.filter_list_sharp, 'Заземлен', Colors.blue));
  }

  // Если нет индикаторов - возвращаем пустой контейнер
  if (indicators.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: indicators,
    ),
  );
}

Widget _buildIndicator(IconData icon, String tooltip, Color color) {
  return Container(
    margin: const EdgeInsets.only(right: 4),
    child: Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        color: color,
        size: 15,
      ),
    ),
  );
}

Widget _getActionIcon(String actionId) {
  final iconData = _getActionIconData(actionId);
  final color = _getActionColor(actionId);

  return Icon(iconData, color: color, size: 30);
}

IconData _getActionIconData(String actionId) {
  switch (actionId) {
    case 'turn_on':
      return Icons.power;
    case 'turn_off':
      return Icons.power_off;
    case 'lock':
      return Icons.lock;
    case 'prohibit_sign':
      return Icons.do_not_disturb;
    case 'check_voltage':
      return Icons.offline_bolt;
    case 'zz_mode':
    case 'pz':
      return Icons.filter_list_sharp;
    case 'safety_signs':
      return Icons.report_problem_rounded;
    case 'zz_mode_off':
    case 'pz_off':
      return Icons.filter_list_sharp;
    default:
      return Icons.build;
  }
}

Color _getActionColor(String actionId) {
  switch (actionId) {
    case 'turn_on':
      return Colors.green;
    case 'turn_off':
      return Colors.red;
    case 'lock':
      return Colors.red;
    case 'prohibit_sign':
      return Colors.red;
    case 'check_voltage':
      return Colors.green;
    case 'zz_mode':
    case 'pz':
      return Colors.blue;
    case 'safety_signs':
      return Colors.blue;
    case 'zz_mode_off':
    case 'pz_off':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

class AppSettings {
  bool enableAdditionalSafetyMeasures = false;

  void toggleAdditionalSafetyMeasures(bool value) {
    enableAdditionalSafetyMeasures = value;
    print(
        'DEBUG: Additional safety measures ${value ? 'enabled' : 'disabled'}');
  }
}
