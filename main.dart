import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // ۱. تنظیم اجرای خودکار با روشن شدن ویندوز (Auto-Startup)
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName.isNotEmpty
            ? packageInfo.appName
            : 'PersianCalendarWidget',
        appPath: Platform.resolvedExecutable,
      );
      await launchAtStartup.enable();
    } catch (e) {
      debugPrint('Launch at startup setup error: $e');
    }

    // ۲. تنظیم پنجره بدون حاشیه و نوار عنوان ویندوز (Borderless & Frameless)
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(500, 548),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAsFrameless();
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class TaskItem {
  String title;
  bool isDone;

  TaskItem({required this.title, this.isDone = false});

  Map<String, dynamic> toJson() => {'title': title, 'isDone': isDone};

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Persian Calendar Widget',
      theme: ThemeData(
        fontFamily: 'Yekan Bakh FaNum',
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: PersianCalendarWidget(),
      ),
    );
  }
}

class PersianCalendarWidget extends StatefulWidget {
  const PersianCalendarWidget({super.key});

  @override
  State<PersianCalendarWidget> createState() => _PersianCalendarWidgetState();
}

class _PersianCalendarWidgetState extends State<PersianCalendarWidget> {
  late Jalali _today;
  late Jalali _displayedMonth;
  late Jalali _selectedDate;

  // وضعیت نمایش صفحه تسک‌های روز انتخاب‌شده
  bool _isTaskViewOpen = false;

  // ذخیره‌سازی تسک‌های هر روز بر اساس کلید تاریخ (مثلاً 1405-09-04)
  final Map<String, List<TaskItem>> _tasksByDate = {};
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();

  // رنگ‌های استخراج شده از طرح فیگما
  static const Color bgColor = Color(0xFF222C36);
  static const Color primaryBlue = Color(0xFF52BDE0);
  static const Color primaryPink = Color(0xFFE02B7B);
  static const Color buttonGray = Color(0xFF4B5767);
  static const Color whiteColor = Color(0xFFFFFFFF);

  final List<String> _weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  // کدهای SVG دقیق استخراج‌شده از فایل فیگما
  static const String _chevronLeftSvg = '''
<svg width="12" height="20" viewBox="0 0 12 20" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M0.29231 10.7138L9.28622 19.7047C9.68086 20.0983 10.3203 20.0983 10.7159 19.7047C11.1105 19.311 11.1105 18.6716 10.7159 18.278L2.43538 10.0005L10.7149 1.72293C11.1095 1.32928 11.1095 0.689884 10.7149 0.295238C10.3203 -0.0984125 9.67987 -0.0984125 9.28522 0.295238L0.291314 9.28607C-0.0972705 9.67565 -0.0972704 10.3251 0.29231 10.7138Z" fill="white"/>
</svg>
''';

  static const String _plusSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M21.8906 9.89062H14.1094V2.10938C14.1094 0.944391 13.165 0 12 0C10.835 0 9.89062 0.944391 9.89062 2.10938V9.89062H2.10938C0.944391 9.89062 0 10.835 0 12C0 13.165 0.944391 14.1094 2.10938 14.1094H9.89062V21.8906C9.89062 23.0556 10.835 24 12 24C13.165 24 14.1094 23.0556 14.1094 21.8906V14.1094H21.8906C23.0556 14.1094 24 13.165 24 12C24 10.835 23.0556 9.89062 21.8906 9.89062Z" fill="white"/>
</svg>
''';

  static const String _checkSvg = '''
<svg width="13" height="10" viewBox="0 0 13 10" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M11.5488 0.000293195C11.3986 0.00459558 11.2561 0.067367 11.1516 0.175227L3.59036 7.71763L0.994271 5.11585C0.940631 5.06022 0.876347 5.01596 0.805246 4.98569C0.734144 4.95542 0.657679 4.93977 0.580404 4.93967C0.0609372 4.93807 -0.196485 5.56954 0.176671 5.93149L3.17223 8.93434C3.18349 8.94643 3.19516 8.95757 3.20725 8.96776C3.26982 9.02647 3.34467 9.07051 3.42638 9.09667C3.50809 9.12284 3.59461 9.13048 3.67964 9.11904C3.76467 9.1076 3.84609 9.07737 3.91798 9.03054C3.98987 8.98371 4.05042 8.92145 4.09525 8.84829L11.9674 0.993538C12.3479 0.62696 12.0766 -0.0157068 11.5488 0.000293195Z" fill="white"/>
</svg>
''';

  static const String _emptyClipboardBoardSvg = '''
<svg width="76" height="96" viewBox="0 0 76 96" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M65.8236 12.5778H57.1386V8.69242C57.1386 7.43536 55.7673 6.86403 54.5103 6.86403H47.768C46.1682 2.29294 42.1685 0.00739924 37.5974 0.00739924C33.0766 -0.162556 28.9646 2.60945 27.4267 6.86403H20.7987C19.5416 6.86403 18.2846 7.43536 18.2846 8.69242V12.5778H9.59932C4.45253 12.6327 0.241919 16.6928 0 21.8341V87.3147C0 92.343 4.57108 95.9997 9.59932 95.9997H65.8236C70.8518 95.9997 75.4229 92.343 75.4229 87.3147V21.8343C75.181 16.6928 70.9704 12.6327 65.8236 12.5778ZM22.8554 11.4351H29.1407C29.6751 11.3698 30.1745 11.1347 30.5653 10.7644C30.9562 10.3941 31.2179 9.90824 31.3121 9.37815C31.9888 6.43093 34.5745 4.31535 37.5974 4.23573C40.5923 4.3265 43.139 6.44865 43.7683 9.37815C43.8679 9.9256 44.1463 10.4245 44.5599 10.7968C44.9735 11.169 45.4989 11.3935 46.0538 11.4351H52.5677V20.5773H22.8554V11.4351ZM70.8518 87.3149C70.8518 89.8291 68.3377 91.4289 65.8236 91.4289H9.59932C7.0852 91.4289 4.57108 89.8291 4.57108 87.3149V21.8343C4.80425 19.2174 6.97234 17.197 9.59932 17.1491H18.2843V22.9772C18.4051 24.2577 19.5141 25.2155 20.7985 25.1486H54.51C55.1408 25.1831 55.7615 24.9789 56.2485 24.5765C56.7355 24.1741 57.0532 23.6032 57.1383 22.9772V17.1489H65.8234C68.4501 17.197 70.6184 19.2172 70.8516 21.8341L70.8518 87.3149Z" fill="white"/>
</svg>
''';

  static const String _emptyClipboardItemsSvg = '''
<svg width="53" height="50" viewBox="0 0 53 50" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M17.4629 18.9969C16.6057 18.0933 15.1826 18.0423 14.2631 18.8827L6.94931 25.8535L3.86386 22.6537C3.00665 21.7501 1.58357 21.6993 0.664014 22.5395C0.237812 22.9859 0 23.5793 0 24.1965C0 24.8137 0.237812 25.4071 0.664014 25.8535L5.34928 30.6532C5.54956 30.8775 5.79662 31.0552 6.07304 31.1737C6.34946 31.2921 6.6485 31.3485 6.94909 31.3389C7.55193 31.3302 8.12694 31.0838 8.54891 30.6532L17.4625 22.1967C18.3462 21.3861 18.4052 20.0125 17.5944 19.129C17.5527 19.0829 17.5088 19.0388 17.4629 18.9969ZM50.2604 23.9107H23.9768C22.7145 23.9107 21.6913 24.9339 21.6913 26.1963C21.6913 27.4586 22.7145 28.4818 23.9768 28.4818H50.2604C51.5227 28.4818 52.546 27.4586 52.546 26.1963C52.546 24.9339 51.5227 23.9107 50.2604 23.9107ZM17.4629 0.71254C16.6057 -0.191047 15.1826 -0.242012 14.2631 0.598361L6.94931 7.56917L3.86386 4.36932C3.00665 3.46573 1.58357 3.41477 0.664014 4.25514C0.237812 4.70153 0 5.29498 0 5.91215C0 6.52933 0.237812 7.12278 0.664014 7.56917L5.34928 12.3688C5.54956 12.5932 5.79662 12.7708 6.07304 12.8893C6.34946 13.0078 6.6485 13.0642 6.94909 13.0546C7.55193 13.0459 8.12694 12.7994 8.54891 12.3688L17.4625 3.91239C18.3462 3.10176 18.4052 1.72812 17.5944 0.844652C17.5527 0.798563 17.5088 0.754478 17.4629 0.71254ZM50.2604 5.62638H23.9768C22.7145 5.62638 21.6913 6.64961 21.6913 7.91192C21.6913 9.17423 22.7145 10.1975 23.9768 10.1975H50.2604C51.5227 10.1975 52.546 9.17423 52.546 7.91192C52.546 6.64961 51.5227 5.62638 50.2604 5.62638ZM17.4629 37.281C16.6057 36.3774 15.1826 36.3267 14.2631 37.1668L6.94931 44.1376L3.86386 40.9378C3.00665 40.0342 1.58357 39.9834 0.664014 40.8236C0.237812 41.27 0 41.8634 0 42.4806C0 43.0978 0.237812 43.6912 0.664014 44.1376L5.34928 48.9373C5.54956 49.1616 5.79662 49.3393 6.07304 49.4578C6.34946 49.5763 6.6485 49.6327 6.94909 49.623C7.55193 49.6144 8.12694 49.3679 8.54891 48.9373L17.4625 40.4808C18.3462 39.6702 18.4052 38.2966 17.5944 37.4131C17.5527 37.367 17.5088 37.3229 17.4629 37.281ZM50.2604 42.1951H23.9768C22.7145 42.1951 21.6913 43.2183 21.6913 44.4806C21.6913 45.7429 22.7145 46.7661 23.9768 46.7661H50.2604C51.5227 46.7661 52.546 45.7429 52.546 44.4806C52.546 43.2183 51.5227 42.1951 50.2604 42.1951Z" fill="white"/>
</svg>
''';

  @override
  void initState() {
    super.initState();
    _today = Jalali.now();
    _displayedMonth = Jalali(_today.year, _today.month, 1);
    _selectedDate = _today;
    _loadTasksFromDisk();
    WidgetsBinding.instance.addPostFrameCallback((_) => _adjustWindowHeight());
  }

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  String _dateKey(Jalali d) => '${d.year}-${d.month}-${d.day}';

  File get _storageFile {
    final dir = Directory.systemTemp.parent;
    final appData = Platform.environment['APPDATA'] ?? dir.path;
    final folder = Directory('$appData/PersianCalendarWidget');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    return File('${folder.path}/tasks.json');
  }

  Future<void> _loadTasksFromDisk() async {
    try {
      final file = _storageFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        setState(() {
          _tasksByDate.clear();
          decoded.forEach((key, value) {
            final list = (value as List)
                .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
                .toList();
            if (list.isNotEmpty) {
              _tasksByDate[key] = list;
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  Future<void> _saveTasksToDisk() async {
    try {
      final file = _storageFile;
      final Map<String, dynamic> data = {};
      _tasksByDate.forEach((key, list) {
        if (list.isNotEmpty) {
          data[key] = list.map((e) => e.toJson()).toList();
        }
      });
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  // تنظیم خودکار ارتفاع پنجره ویندوز
  Future<void> _adjustWindowHeight() async {
    if (!Platform.isWindows) return;
    if (_isTaskViewOpen) {
      await windowManager.setSize(const Size(500, 548));
      return;
    }
    int daysInMonth = _displayedMonth.monthLength;
    int firstDayOffset = _displayedMonth.weekDay - 1;
    bool isSixRows = (firstDayOffset + daysInMonth) > 35;

    double targetHeight = isSixRows ? 616.0 : 548.0;
    await windowManager.setSize(Size(500, targetHeight));
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = _displayedMonth.addMonths(offset);
    });
    _adjustWindowHeight();
  }

  void _goToToday() {
    setState(() {
      _today = Jalali.now();
      _displayedMonth = Jalali(_today.year, _today.month, 1);
      _selectedDate = _today;
    });
    _adjustWindowHeight();
  }

  void _openDayTasks(Jalali date) {
    setState(() {
      _selectedDate = date;
      _isTaskViewOpen = true;
      _taskController.clear();
    });
    _adjustWindowHeight();
  }

  void _closeDayTasks() {
    setState(() {
      _isTaskViewOpen = false;
    });
    _adjustWindowHeight();
  }

  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    final key = _dateKey(_selectedDate);
    setState(() {
      _tasksByDate.putIfAbsent(key, () => []);
      _tasksByDate[key]!.add(TaskItem(title: text));
      _taskController.clear();
    });
    _saveTasksToDisk();
    _taskFocusNode.requestFocus();
  }

  void _toggleTask(int index) {
    final key = _dateKey(_selectedDate);
    final list = _tasksByDate[key];
    if (list == null || index < 0 || index >= list.length) return;
    setState(() {
      list[index].isDone = !list[index].isDone;
    });
    _saveTasksToDisk();
  }

  void _deleteTask(int index) {
    final key = _dateKey(_selectedDate);
    final list = _tasksByDate[key];
    if (list == null || index < 0 || index >= list.length) return;
    setState(() {
      list.removeAt(index);
      if (list.isEmpty) {
        _tasksByDate.remove(key);
      }
    });
    _saveTasksToDisk();
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], persian[i]);
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _isTaskViewOpen) {
          _closeDayTasks();
        }
      },
      child: GestureDetector(
        onPanStart: (_) {
          if (Platform.isWindows) {
            windowManager.startDragging();
          }
        },
        child: _isTaskViewOpen ? _buildTaskPage() : _buildCalendarPage(),
      ),
    );
  }

  // صفحه ۱: تقویم شمسی (Frame 1)
  Widget _buildCalendarPage() {
    int daysInMonth = _displayedMonth.monthLength;
    int firstDayOffset = _displayedMonth.weekDay - 1;
    int totalCells = ((firstDayOffset + daysInMonth) <= 35) ? 35 : 42;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ۱. هدر
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    _toPersianDigits(
                        '${_displayedMonth.formatter.mN} ${_displayedMonth.year}'),
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildNavButton(
                      quarterTurns: 2,
                      onTap: () => _changeMonth(-1),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildNavButton(
                      quarterTurns: 0,
                      onTap: () => _changeMonth(1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ۲. ردیف عنوان روزهای هفته
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekDays.map((day) {
                return Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            // ۳. شبکه روزهای ماه
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                int dayNumber = index - firstDayOffset + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                Jalali currentDate = Jalali(
                  _displayedMonth.year,
                  _displayedMonth.month,
                  dayNumber,
                );

                bool isSelected = currentDate.year == _selectedDate.year &&
                    currentDate.month == _selectedDate.month &&
                    currentDate.day == _selectedDate.day;

                bool hasTasks =
                    (_tasksByDate[_dateKey(currentDate)]?.isNotEmpty ?? false);

                bool isFriday = (index % 7 == 6);

                // اگر برای این روز تسکی ثبت شده باشد، رنگ پس‌زمینه #4B5767 و متن سفید می‌شود (Group 39)
                // در غیر این صورت اگر روز انتخاب شده باشد #E02B7B وگرنه سفید خواهد بود
                Color boxColor;
                Color textColor;

                if (hasTasks) {
                  boxColor = buttonGray; // #4B5767 مطابق طرح
                  textColor = whiteColor;
                } else if (isSelected) {
                  boxColor = primaryPink; // #E02B7B
                  textColor = whiteColor;
                } else {
                  boxColor = whiteColor;
                  textColor = isFriday ? primaryPink : primaryBlue;
                }

                return GestureDetector(
                  onTap: () => _openDayTasks(currentDate),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _toPersianDigits('$dayNumber'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ۴. فوتر
            SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _toPersianDigits(
                        'امروز ${_today.day} ${_today.formatter.mN} ${_today.year}'),
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: _goToToday,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 124,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryPink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'برو به امروز',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // صفحه ۲ و ۳: مدیریت تسک‌های روز انتخاب‌شده (Frame 2 & Frame 3)
  Widget _buildTaskPage() {
    final tasks = _tasksByDate[_dateKey(_selectedDate)] ?? [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 500,
        height: 548,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // ۱. هدر تاریخ روز (y=20 در طرح کلی، ارتفاع ۳۶ همراه با دکمه بازگشت به تقویم)
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    _toPersianDigits(
                        '${_selectedDate.day} ${_selectedDate.formatter.mN} ${_selectedDate.year}'),
                    style: const TextStyle(
                      color: whiteColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // دکمه بازگشت به تقویم در سمت چپ بالا (مشابه Group 46 در x=16, y=16)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildNavButton(
                      quarterTurns: 0,
                      onTap: _closeDayTasks,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20), // فاصله دقیق تا y=72 (16 + 36 + 20 = 72)

            // ۲. بخش افزودن تسک (Group 55 و Group 54 در y=72، ارتفاع ۴۸)
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  // کادر ورودی متن تسک (Group 55: عرض 412، ارتفاع 48، رنگ #4B5767، شعاع 8)
                  Container(
                    width: 412,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: buttonGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _taskController,
                      focusNode: _taskFocusNode,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      onSubmitted: (_) => _addTask(),
                      style: const TextStyle(
                        color: whiteColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'تسک خودرا وارد کنید',
                        hintStyle: TextStyle(
                          color: whiteColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8), // فاصله دقیق ۸ پیکسل (72 - 16 - 48 = 8)

                  // دکمه صورتی افزودن تسک (Group 54: x=16, y=72, 48x48, #E02B7B)
                  GestureDetector(
                    onTap: _addTask,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryPink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SvgPicture.string(
                          _plusSvg,
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ۳. لیست تسک‌ها (Frame 2) یا وضعیت خالی (Frame 3)
            Expanded(
              child: tasks.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.only(top: 24), // شروع از y=144 (72 + 48 + 24 = 144)
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16), // فاصله دقیق بین ردیف‌ها (177 - 144 - 17 = 16)
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskRow(task, index);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // وضعیت بدون تسک (Frame 3 - Group 58 در x=188, y=194)
  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 74), // فاصله دقیق از پایین کادر ورودی (194 - 120 = 74)
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 0,
                child: SvgPicture.string(
                  _emptyClipboardBoardSvg,
                  width: 75.42,
                  height: 96,
                ),
              ),
              Positioned(
                left: 22,
                top: 32,
                child: SvgPicture.string(
                  _emptyClipboardItemsSvg,
                  width: 52.55,
                  height: 49.62,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16), // فاصله دقیق تا متن (306 - (194 + 96) = 16)
        const Text(
          'تسکی یافت نشد',
          style: TextStyle(
            color: whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ردیف هر تسک مطابق با Group 56 و Group 57 در Frame 2
  Widget _buildTaskRow(TaskItem task, int index) {
    return GestureDetector(
      onTap: () => _toggleTask(index),
      // با کلیک راست روی هر تسک می‌توانید آن را حذف کنید
      onSecondaryTap: () => _deleteTask(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // چک‌باکس ۱۶ در ۱۶ (Rectangle 23 در x=468 با شعاع 2 و رنگ #4B5767)
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buttonGray,
                borderRadius: BorderRadius.circular(2),
              ),
              child: task.isDone
                  ? SvgPicture.string(
                      _checkSvg,
                      width: 12,
                      height: 9,
                    )
                  : null,
            ),

            const SizedBox(width: 16), // فاصله ۱۶ پیکسلی بین چک‌باکس و متن (468 - 452 = 16)

            // متن تسک به همراه خط روی متن در حالت انجام‌شده (Line 1)
            Flexible(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _toPersianDigits(task.title),
                      style: const TextStyle(
                        color: whiteColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (task.isDone)
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: whiteColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required int quarterTurns,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: buttonGray,
            shape: BoxShape.circle,
          ),
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: SvgPicture.string(
              _chevronLeftSvg,
              width: 11,
              height: 20,
            ),
          ),
        ),
      ),
    );
  }
}
