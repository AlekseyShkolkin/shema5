import 'dart:ui';

class Apparatus {
  final String id;
  final String type; // Для логики и изображений
  final String actionGroup; // Группа действий (может совпадать у разных типов)
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  String state;
  String status;
  List<String> availableActions;
  final String imagePrefix;
  final double rotation;
  final double? labelX; // Необязательное поле
  final double? labelY; // Необязательное поле
  final bool showLabel;
  List<String> safetyMeasures = [];

  Apparatus({
    required this.id,
    required this.type,
    required this.actionGroup, // Новая поле для группировки действий
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.state = 'off',
    this.status = 'on',
    required this.availableActions,
    required this.imagePrefix,
    this.rotation = 0,
    this.labelX, // Необязательный параметр
    this.labelY, // Необязательный параметр
    this.showLabel = true,
  });

  // Геттер для получения координат подписи
  Offset get labelOffset {
    if (labelX != null && labelY != null) {
      return Offset(labelX!, labelY!); // Абсолютное позиционирование
    }
    return Offset(x, y - 25); // Относительное позиционирование (по умолчанию)
  }

  String getImagePath() {
    String folder = _getFolderByType();
    print('DEBUG: folder = "$folder", imagePrefix = "$imagePrefix"');
    if (status == 'zz') {
      return 'assets/images/$folder/${imagePrefix}zz.png';
    } else if (state == 'on') {
      return 'assets/images/$folder/${imagePrefix}on.png';
    } else {
      return 'assets/images/$folder/${imagePrefix}off.png';
    }
  }

  String _getFolderByType() {
    print('DEBUG: type = "$type"');
    switch (type) {
      case 'akb1':
      case 'dg1':
      case 'avr1':
        return 'avr';
      case 'vv1':
      case 'ps1':
        return 'vv';
      case 'lr1':
      case 'lr2':
      case 'lr3':
      case 'lr4':
      case 'lr5':
        return 'lr';
      case 'kl1':
      case 'kl2':
        return 'kl';
      case 'mtp1':
      case 'ukz1':
      case 'zru1':
        return 'tp';
      case 'ku1':
      case 'lch1':
      case 'lch2':
        return 'lch';
      case 'vl1':
      case 'vl2':
      case 'vl3':
      case 'vl4':
      case 'vl5':
      case 'vl6':
        return 'vl';
      case 'nmtp1':
      case 'nmtp2':
      case 'nmtp3':
      case 'nmtp4':
      case 'nkptm1':
      case 'nkptm2':
      case 'nkptm3':
      case 'nkptm4':
      case 'nukz1':
      case 'nukz2':
      case 'nukz3':
      case 'nukz4':
      case 'nukz5':
      case 'nukz6':
      case 'namevl1':
        return 'np';
      default:
        return 'common';
    }
  }

  void changeState(String newState) {
    state = newState; // ← должно изменять состояние
    print('DEBUG: Changed state of $id to $newState');
  }

  void changeStatus(String newStatus) {
    status = newStatus; // ← должно изменять статус
    print('DEBUG: Changed status of $id to $newStatus');
  }

  void addSafetyMeasure(String measure) {
    if (!safetyMeasures.contains(measure)) {
      safetyMeasures.add(measure);
      print('DEBUG: Added safety measure "$measure" to $id');
    }
  }

  void removeSafetyMeasure(String measure) {
    safetyMeasures.remove(measure);
    print('DEBUG: Removed safety measure "$measure" from $id');
  }

  void clearSafetyMeasures() {
    safetyMeasures.clear();
    print('DEBUG: Cleared all safety measures from $id');
  }

  bool hasSafetyMeasure(String measure) {
    return safetyMeasures.contains(measure);
  }

  bool get isReadyForOperation {
    if (state == 'off' && status == 'zz') {
      // Проверяем что все требуемые мероприятия выполнены
      final requiredMeasures = [
        'locked',
        'prohibit_sign',
        'voltage_checked',
        'safety_signs'
      ];
      return requiredMeasures
          .every((measure) => safetyMeasures.contains(measure));
    }
    return true;
  }
}

class ApparatusAction {
  final String id;
  final String name;
  final String description;
  final int executionOrder;
  final Function(Apparatus) onSelected;
  final bool Function(Apparatus) isEnabled; // Функция проверки доступности
  final bool isSafetyMeasure;

  ApparatusAction({
    required this.id,
    required this.name,
    this.description = '',
    this.executionOrder = 0,
    required this.onSelected,
    required this.isEnabled, // Обязательная проверка
    this.isSafetyMeasure = false,
  });
}
