import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.initDB();
  runApp(const ClassMonitorApp());
}

// =====================
// COLORS
// =====================
const Color kGreen = Color(0xFF66BB6A);
const Color kBlue = Color(0xFF64B5F6);
const Color kYellow = Color(0xFFFFF9C4);
const Color kPurple = Color(0xFF6A1B9A);
const Color kWhite = Colors.white;
const Color kBlack = Colors.black87;

// =====================
// APP
// =====================
class ClassMonitorApp extends StatelessWidget {
  const ClassMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassMonitorPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: kYellow,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// =====================
// DATABASE HELPER
// =====================
class DBHelper {
  static Database? _db;

  static Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'classmonitorpro.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE admin(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT, email TEXT, password TEXT, institute TEXT)''');
        await db.execute('''CREATE TABLE staff(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staff_id TEXT UNIQUE, name TEXT, 
          shift_time TEXT, shift_period TEXT)''');
        await db.execute('''CREATE TABLE attendance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staff_id TEXT, date TEXT, status TEXT, 
          marked_time TEXT)''');
        await db.execute('''CREATE TABLE holidays(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE, description TEXT)''');
        await db.execute('''CREATE TABLE settings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          weekly_holiday TEXT)''');
      },
    );
  }

  static Database get db => _db!;

  // ADMIN
  static Future<int> insertAdmin(Map<String, dynamic> data) async =>
      await db.insert('admin', data);
  static Future<Map<String, dynamic>?> getAdmin() async {
    final r = await db.query('admin', limit: 1);
    return r.isNotEmpty ? r.first : null;
  }

  static Future<bool> adminExists() async => (await getAdmin()) != null;
  static Future<bool> verifyPassword(String pass) async {
    final r = await db.query('admin', where: 'password = ?', whereArgs: [pass]);
    return r.isNotEmpty;
  }

  static Future<void> updateAdmin(Map<String, dynamic> data) async =>
      await db.update('admin', data, where: 'id = ?', whereArgs: [data['id']]);

  // STAFF
  static Future<int> insertStaff(Map<String, dynamic> data) async =>
      await db.insert('staff', data);
  static Future<List<Map<String, dynamic>>> getAllStaff() async =>
      await db.query('staff', orderBy: 'name ASC');
  static Future<bool> staffIdExists(String id) async {
    final r = await db.query('staff', where: 'staff_id = ?', whereArgs: [id]);
    return r.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> getStaffById(String id) async {
    final r = await db.query('staff', where: 'staff_id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  static Future<void> deleteStaff(int id) async =>
      await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  static Future<void> updateStaff(Map<String, dynamic> data) async =>
      await db.update('staff', data, where: 'id = ?', whereArgs: [data['id']]);

  // ATTENDANCE
  static Future<void> saveAttendance(Map<String, dynamic> data) async {
    final r = await db.query(
      'attendance',
      where: 'staff_id = ? AND date = ?',
      whereArgs: [data['staff_id'], data['date']],
    );
    if (r.isNotEmpty) {
      await db.update(
        'attendance',
        data,
        where: 'staff_id = ? AND date = ?',
        whereArgs: [data['staff_id'], data['date']],
      );
    } else {
      await db.insert('attendance', data);
    }
  }

  static Future<List<Map<String, dynamic>>> getAttendanceByDate(
    String date,
  ) async => await db.query('attendance', where: 'date = ?', whereArgs: [date]);
  static Future<List<Map<String, dynamic>>> getStaffMonthlyAttendance(
    String staffId,
    String month,
  ) async => await db.query(
    'attendance',
    where: 'staff_id = ? AND date LIKE ?',
    whereArgs: [staffId, '$month%'],
  );
  static Future<List<Map<String, dynamic>>> getMonthlyAttendance(
    String month,
  ) async => await db.query(
    'attendance',
    where: 'date LIKE ?',
    whereArgs: ['$month%'],
  );

  // HOLIDAYS
  static Future<void> insertHoliday(Map<String, dynamic> data) async => await db
      .insert('holidays', data, conflictAlgorithm: ConflictAlgorithm.ignore);
  static Future<List<Map<String, dynamic>>> getAllHolidays() async =>
      await db.query('holidays', orderBy: 'date ASC');
  static Future<void> deleteHoliday(int id) async =>
      await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  static Future<bool> isHoliday(String date) async {
    final r = await db.query('holidays', where: 'date = ?', whereArgs: [date]);
    return r.isNotEmpty;
  }

  // SETTINGS
  static Future<void> saveSettings(String weeklyHoliday) async {
    final r = await db.query('settings');
    if (r.isNotEmpty) {
      await db.update('settings', {'weekly_holiday': weeklyHoliday});
    } else {
      await db.insert('settings', {'weekly_holiday': weeklyHoliday});
    }
  }

  static Future<String> getWeeklyHoliday() async {
    final r = await db.query('settings');
    return r.isNotEmpty ? r.first['weekly_holiday'] as String : 'Sunday';
  }
}

// =====================
// SPLASH SCREEN
// =====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final adminExists = await DBHelper.adminExists();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              adminExists ? const LoginScreen() : const RegisterScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, size: 70, color: kWhite),
                ),
                const SizedBox(height: 30),
                const Text(
                  'ClassMonitorPro',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: kWhite,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Staff Management System',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 50),
                const CircularProgressIndicator(color: kGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// REGISTER SCREEN
// =====================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _instituteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _instituteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await DBHelper.insertAdmin({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'institute': _instituteController.text.trim(),
    });
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SlideTransition(
            position: _slideAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.school, size: 50, color: kWhite),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kBlack,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'ClassMonitorPro',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Your Name',
                    icon: Icons.person,
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _instituteController,
                    label: 'Institute Name',
                    icon: Icons.business,
                    validator: (v) =>
                        v!.isEmpty ? 'Institute name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password (min 6 characters)',
                      prefixIcon: const Icon(Icons.lock, color: kGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: kGreen,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: kWhite,
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Minimum 6 characters required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGreen, width: 2),
        ),
        filled: true,
        fillColor: kWhite,
      ),
      validator: validator,
    );
  }
}

// =====================
// LOGIN SCREEN
// =====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final valid = await DBHelper.verifyPassword(
      _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (valid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: kGreen,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school, size: 60, color: kWhite),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ClassMonitorPro',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 50),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: DBHelper.getAdmin(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: kPurple),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      snapshot.data!['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: kBlack,
                                      ),
                                    ),
                                    Text(
                                      snapshot.data!['email'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: kGreen),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: kGreen,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kGreen, width: 2),
                        ),
                        filled: true,
                        fillColor: kWhite,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Password is required' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: kWhite)
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// HOME SCREEN
// =====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _admin;
  int _staffCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final admin = await DBHelper.getAdmin();
    final staff = await DBHelper.getAllStaff();
    setState(() {
      _admin = admin;
      _staffCount = staff.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_admin?['name'] ?? ''}! 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kBlack,
                        ),
                      ),
                      Text(
                        _admin?['institute'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: kPurple,
                    child: Text(
                      _admin?['name']?.substring(0, 1).toUpperCase() ?? 'A',
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Staff: $_staffCount',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Buttons
              const Text(
                'Main Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kBlack,
                ),
              ),
              const SizedBox(height: 12),

              _buildMainButton(
                icon: Icons.person_add,
                title: 'Add Staff',
                subtitle: 'Add new staff member',
                color: kGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStaffScreen()),
                ).then((_) => _loadData()),
              ),
              _buildMainButton(
                icon: Icons.calendar_month,
                title: 'Monthly Public Holidays',
                subtitle: 'Manage holidays & weekly off',
                color: kBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HolidayScreen()),
                ),
              ),
              _buildMainButton(
                icon: Icons.how_to_reg,
                title: 'Mark Today\'s Attendance',
                subtitle: 'Present / Absent',
                color: const Color(0xFF66BB6A),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ),
              ),
              _buildMainButton(
                icon: Icons.bar_chart,
                title: 'Check Monthly Record',
                subtitle: 'Current month summary',
                color: const Color(0xFFFF7043),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MonthlyRecordScreen(),
                  ),
                ),
              ),
              _buildMainButton(
                icon: Icons.history,
                title: 'Last 6 Months Record',
                subtitle: 'Month wise attendance',
                color: const Color(0xFF7E57C2),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SixMonthRecordScreen(),
                  ),
                ),
              ),
              _buildMainButton(
                icon: Icons.search,
                title: 'Check Manually',
                subtitle: 'Search by Staff ID',
                color: const Color(0xFF26A69A),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualCheckScreen()),
                ),
              ),
              _buildMainButton(
                icon: Icons.credit_card,
                title: 'Smart Cards',
                subtitle: 'View & download staff cards',
                color: kPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartCardScreen()),
                ),
              ),
              const SizedBox(height: 24),

              // Small Buttons
              const Text(
                'More',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kBlack,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallButton(
                      icon: Icons.person,
                      title: 'Profile',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallButton(
                      icon: Icons.info,
                      title: 'About Us',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kPurple,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: kWhite, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// ADD STAFF SCREEN
// =====================
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _shiftTimeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _shiftPeriod = 'AM';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _shiftTimeController.dispose();
    super.dispose();
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;
    final idExists = await DBHelper.staffIdExists(_idController.text.trim());
    if (idExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff ID already exists!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await DBHelper.insertStaff({
      'staff_id': _idController.text.trim(),
      'name': _nameController.text.trim(),
      'shift_time': _shiftTimeController.text.trim(),
      'shift_period': _shiftPeriod,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff member added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'Add Staff Member',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Staff Member Name *',
                        prefixIcon: const Icon(Icons.person, color: kGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kGreen, width: 2),
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: 'ID # *',
                        prefixIcon: const Icon(Icons.badge, color: kGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kGreen, width: 2),
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'ID is required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _shiftTimeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Shift Time *',
                              hintText: 'e.g. 9:00',
                              prefixIcon: const Icon(
                                Icons.access_time,
                                color: kGreen,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Shift time is required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _shiftPeriod,
                                items: ['AM', 'PM']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: kGreen,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _shiftPeriod = v!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Staff Member',
                    style: TextStyle(
                      fontSize: 18,
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================
// HOLIDAY SCREEN
// =====================
class HolidayScreen extends StatefulWidget {
  const HolidayScreen({super.key});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> {
  List<Map<String, dynamic>> _holidays = [];
  String _weeklyHoliday = 'Sunday';
  final _descController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final holidays = await DBHelper.getAllHolidays();
    final weekly = await DBHelper.getWeeklyHoliday();
    setState(() {
      _holidays = holidays;
      _weeklyHoliday = weekly;
    });
  }

  Future<void> _saveWeeklyHoliday(String value) async {
    await DBHelper.saveSettings(value);
    setState(() => _weeklyHoliday = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Weekly holiday set to $value'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addHoliday() async {
    if (_selectedDate == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and enter description!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    await DBHelper.insertHoliday({
      'date': dateStr,
      'description': _descController.text.trim(),
    });
    _descController.clear();
    setState(() => _selectedDate = null);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Holiday added!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: kBlue,
        title: const Text(
          'Monthly Public Holidays',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Holiday
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Holiday',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Sunday', 'Friday', 'Both'].map((day) {
                      final selected = _weeklyHoliday == day;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _saveWeeklyHoliday(day),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? kGreen : Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: selected ? kWhite : kBlack,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Add Extra Holiday
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Extra Public Holiday',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: kBlue),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_selectedDate!),
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? Colors.grey
                                  : kBlack,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Eid Holiday',
                      prefixIcon: const Icon(Icons.description, color: kBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addHoliday,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Holiday',
                        style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Holiday List
            const Text(
              'Extra Holidays List',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 12),
            _holidays.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No extra holidays added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _holidays.length,
                    itemBuilder: (context, index) {
                      final h = _holidays[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: kBlue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h['description'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kBlack,
                                    ),
                                  ),
                                  Text(
                                    h['date'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await DBHelper.deleteHoliday(h['id']);
                                await _loadData();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// ATTENDANCE SCREEN
// =====================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _staffList = [];
  Map<String, String> _attendanceStatus = {};
  Map<String, String> _attendanceTime = {};
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final staff = await DBHelper.getAllStaff();
    final attendance = await DBHelper.getAttendanceByDate(_today);
    Map<String, String> statusMap = {};
    Map<String, String> timeMap = {};
    for (var a in attendance) {
      statusMap[a['staff_id']] = a['status'];
      timeMap[a['staff_id']] = a['marked_time'];
    }
    setState(() {
      _staffList = staff;
      _attendanceStatus = statusMap;
      _attendanceTime = timeMap;
      _loading = false;
    });
  }

  String _getStatus(Map<String, dynamic> staff) {
    final now = DateTime.now();
    final shiftTimeStr = staff['shift_time'];
    final shiftPeriod = staff['shift_period'];
    try {
      final parts = shiftTimeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (shiftPeriod == 'PM' && hour != 12) hour += 12;
      if (shiftPeriod == 'AM' && hour == 12) hour = 0;
      final shiftDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      final lateTime = shiftDateTime.add(const Duration(minutes: 4));
      if (now.isAfter(lateTime)) return 'late';
      return 'present';
    } catch (e) {
      return 'present';
    }
  }

  Future<void> _markAttendance(
    Map<String, dynamic> staff,
    String status,
  ) async {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final finalStatus = status == 'present' ? _getStatus(staff) : 'absent';
    await DBHelper.saveAttendance({
      'staff_id': staff['staff_id'],
      'date': _today,
      'status': finalStatus,
      'marked_time': now,
    });
    await _loadData();
  }

  Color _getStatusColor(String? status) {
    if (status == 'present') return Colors.green;
    if (status == 'late') return Colors.orange;
    if (status == 'absent') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: kGreen.withOpacity(0.1),
                  child: Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _staffList.isEmpty
                      ? const Center(
                          child: Text(
                            'No staff members added yet!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staffList.length,
                          itemBuilder: (context, index) {
                            final staff = _staffList[index];
                            final sid = staff['staff_id'];
                            final status = _attendanceStatus[sid];
                            final time = _attendanceTime[sid];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: status != null
                                    ? Border.all(
                                        color: _getStatusColor(status),
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: kGreen.withOpacity(
                                          0.2,
                                        ),
                                        child: Text(
                                          staff['name']
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: kGreen,
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
                                              staff['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: kBlack,
                                              ),
                                            ),
                                            Text(
                                              'ID: ${staff['staff_id']} | Shift: ${staff['shift_time']} ${staff['shift_period']}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (status != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: const TextStyle(
                                              color: kWhite,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (time != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Marked at: $time',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _markAttendance(staff, 'present'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            'Present',
                                            style: TextStyle(color: kWhite),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _markAttendance(staff, 'absent'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            'Absent',
                                            style: TextStyle(color: kWhite),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _markAttendance(staff, 'again'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kBlue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text(
                                            'Again',
                                            style: TextStyle(color: kWhite),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// MONTHLY RECORD SCREEN
// =====================
class MonthlyRecordScreen extends StatefulWidget {
  const MonthlyRecordScreen({super.key});
  @override
  State<MonthlyRecordScreen> createState() => _MonthlyRecordScreenState();
}

class _MonthlyRecordScreenState extends State<MonthlyRecordScreen> {
  List<Map<String, dynamic>> _staffList = [];
  Map<String, Map<String, int>> _records = {};
  int _totalWorkingDays = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final month = DateFormat('yyyy-MM').format(now);
    final staff = await DBHelper.getAllStaff();
    final attendance = await DBHelper.getMonthlyAttendance(month);
    final holidays = await DBHelper.getAllHolidays();
    final weeklyHoliday = await DBHelper.getWeeklyHoliday();

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int workingDays = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(now.year, now.month, d);
      if (date.isAfter(now)) break;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isHoliday = holidays.any((h) => h['date'] == dateStr);
      if (isHoliday) continue;
      bool isWeeklyOff = false;
      if (weeklyHoliday == 'Sunday' && date.weekday == DateTime.sunday)
        isWeeklyOff = true;
      if (weeklyHoliday == 'Friday' && date.weekday == DateTime.friday)
        isWeeklyOff = true;
      if (weeklyHoliday == 'Both' &&
          (date.weekday == DateTime.sunday || date.weekday == DateTime.friday))
        isWeeklyOff = true;
      if (isWeeklyOff) continue;
      workingDays++;
    }

    Map<String, Map<String, int>> records = {};
    for (var s in staff) {
      final sid = s['staff_id'];
      final staffAttendance = attendance
          .where((a) => a['staff_id'] == sid)
          .toList();
      int present = staffAttendance
          .where((a) => a['status'] == 'present')
          .length;
      int late = staffAttendance.where((a) => a['status'] == 'late').length;
      int absent = staffAttendance.where((a) => a['status'] == 'absent').length;
      records[sid] = {'present': present, 'late': late, 'absent': absent};
    }

    setState(() {
      _staffList = staff;
      _records = records;
      _totalWorkingDays = workingDays;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7043),
        title: Text(
          'Monthly Record - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFFF7043).withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.work, color: Color(0xFFFF7043)),
                      const SizedBox(width: 8),
                      Text(
                        'Total Working Days: $_totalWorkingDays',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: kBlack,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _staffList.isEmpty
                      ? const Center(
                          child: Text(
                            'No staff members found!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staffList.length,
                          itemBuilder: (context, index) {
                            final staff = _staffList[index];
                            final sid = staff['staff_id'];
                            final rec =
                                _records[sid] ??
                                {'present': 0, 'late': 0, 'absent': 0};
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staff['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: kBlack,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${staff['staff_id']}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _statBox(
                                        'Total',
                                        '$_totalWorkingDays',
                                        Colors.blue,
                                      ),
                                      _statBox(
                                        'Present',
                                        '${rec['present']}',
                                        Colors.green,
                                      ),
                                      _statBox(
                                        'Late',
                                        '${rec['late']}',
                                        Colors.orange,
                                      ),
                                      _statBox(
                                        'Absent',
                                        '${rec['absent']}',
                                        Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// SIX MONTH RECORD
// =====================
class SixMonthRecordScreen extends StatefulWidget {
  const SixMonthRecordScreen({super.key});
  @override
  State<SixMonthRecordScreen> createState() => _SixMonthRecordScreenState();
}

class _SixMonthRecordScreenState extends State<SixMonthRecordScreen> {
  List<Map<String, dynamic>> _staffList = [];
  List<String> _months = [];
  Map<String, Map<String, Map<String, int>>> _records = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    List<String> months = [];
    for (int i = 6; i >= 1; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('yyyy-MM').format(d));
    }
    final staff = await DBHelper.getAllStaff();
    Map<String, Map<String, Map<String, int>>> records = {};
    for (var s in staff) {
      final sid = s['staff_id'];
      records[sid] = {};
      for (var month in months) {
        final att = await DBHelper.getStaffMonthlyAttendance(sid, month);
        int present = att.where((a) => a['status'] == 'present').length;
        int late = att.where((a) => a['status'] == 'late').length;
        int absent = att.where((a) => a['status'] == 'absent').length;
        records[sid]![month] = {
          'present': present,
          'late': late,
          'absent': absent,
        };
      }
    }
    setState(() {
      _staffList = staff;
      _months = months;
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E57C2),
        title: const Text(
          'Last 6 Months Record',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staffList.isEmpty
          ? const Center(
              child: Text(
                'No staff members found!',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                final sid = staff['staff_id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: kBlack,
                        ),
                      ),
                      Text(
                        'ID: $sid',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const Divider(),
                      ..._months.map((month) {
                        final rec =
                            _records[sid]?[month] ??
                            {'present': 0, 'late': 0, 'absent': 0};
                        final monthName = DateFormat(
                          'MMM yyyy',
                        ).format(DateFormat('yyyy-MM').parse(month));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  monthName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: kBlack,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    _miniStat(
                                      'P',
                                      '${rec['present']}',
                                      Colors.green,
                                    ),
                                    _miniStat(
                                      'L',
                                      '${rec['late']}',
                                      Colors.orange,
                                    ),
                                    _miniStat(
                                      'A',
                                      '${rec['absent']}',
                                      Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// MANUAL CHECK SCREEN
// =====================
class ManualCheckScreen extends StatefulWidget {
  const ManualCheckScreen({super.key});
  @override
  State<ManualCheckScreen> createState() => _ManualCheckScreenState();
}

class _ManualCheckScreenState extends State<ManualCheckScreen> {
  final _idController = TextEditingController();
  Map<String, dynamic>? _staff;
  Map<String, Map<String, int>> _records = {};
  List<String> _months = [];
  bool _searched = false;
  bool _loading = false;

  Future<void> _search() async {
    if (_idController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final staff = await DBHelper.getStaffById(_idController.text.trim());
    if (staff == null) {
      setState(() {
        _staff = null;
        _searched = true;
        _loading = false;
      });
      return;
    }
    final now = DateTime.now();
    List<String> months = [];
    for (int i = 6; i >= 1; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('yyyy-MM').format(d));
    }
    Map<String, Map<String, int>> records = {};
    for (var month in months) {
      final att = await DBHelper.getStaffMonthlyAttendance(
        staff['staff_id'],
        month,
      );
      int present = att.where((a) => a['status'] == 'present').length;
      int late = att.where((a) => a['status'] == 'late').length;
      int absent = att.where((a) => a['status'] == 'absent').length;
      records[month] = {'present': present, 'late': late, 'absent': absent};
    }
    setState(() {
      _staff = staff;
      _records = records;
      _months = months;
      _searched = true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: const Color(0xFF26A69A),
        title: const Text(
          'Check Manually',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: 'Enter Staff ID #',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF26A69A),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF26A69A),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: kWhite,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Search', style: TextStyle(color: kWhite)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const CircularProgressIndicator()
            else if (_searched && _staff == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No staff member found with this ID!',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_staff != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _staff!['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kBlack,
                      ),
                    ),
                    Text(
                      'ID: ${_staff!['staff_id']} | Shift: ${_staff!['shift_time']} ${_staff!['shift_period']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Last 6 Months Record',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kBlack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._months.map((month) {
                      final rec =
                          _records[month] ??
                          {'present': 0, 'late': 0, 'absent': 0};
                      final monthName = DateFormat(
                        'MMMM yyyy',
                      ).format(DateFormat('yyyy-MM').parse(month));
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kYellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                monthName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: kBlack,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  _miniTag('P ${rec['present']}', Colors.green),
                                  _miniTag('L ${rec['late']}', Colors.orange),
                                  _miniTag('A ${rec['absent']}', Colors.red),
                                ],
                              ),
                            ),
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

  Widget _miniTag(String text, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================
// SMART CARD SCREEN
// =====================
class SmartCardScreen extends StatefulWidget {
  const SmartCardScreen({super.key});
  @override
  State<SmartCardScreen> createState() => _SmartCardScreenState();
}

class _SmartCardScreenState extends State<SmartCardScreen> {
  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _admin;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final staff = await DBHelper.getAllStaff();
    final admin = await DBHelper.getAdmin();
    setState(() {
      _staffList = staff;
      _admin = admin;
    });
  }

  Future<void> _downloadCard(Map<String, dynamic> staff) async {
    try {
      final image = await _screenshotController.captureFromWidget(
        _buildCardWidget(staff),
        pixelRatio: 3.0,
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/card_${staff['staff_id']}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card saved: ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCardWidget(Map<String, dynamic> staff) {
    return Material(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _admin?['institute'] ?? 'Institute',
              style: const TextStyle(
                color: kGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 35,
              backgroundColor: kGreen,
              child: Text(
                staff['name'].substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 30,
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              staff['name'],
              style: const TextStyle(
                color: kWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: kGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen),
              ),
              child: Text(
                'ID: ${staff['staff_id']}',
                style: const TextStyle(
                  color: kGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Shift: ${staff['shift_time']} ${staff['shift_period']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const Text(
              'ClassMonitorPro',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: kPurple,
        title: const Text(
          'Smart Cards',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: _staffList.isEmpty
          ? const Center(
              child: Text(
                'No staff members found!\nAdd staff first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      _buildCardWidget(staff),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadCard(staff),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.download, color: kWhite),
                          label: const Text(
                            'Download Card (PNG)',
                            style: TextStyle(color: kWhite),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// =====================
// PROFILE SCREEN
// =====================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _admin;
  List<Map<String, dynamic>> _staffList = [];
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _instituteController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final admin = await DBHelper.getAdmin();
    final staff = await DBHelper.getAllStaff();
    setState(() {
      _admin = admin;
      _staffList = staff;
      if (admin != null) {
        _nameController.text = admin['name'];
        _emailController.text = admin['email'];
        _instituteController.text = admin['institute'];
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_admin == null) return;
    final updatedAdmin = {
      'id': _admin!['id'],
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'institute': _instituteController.text.trim(),
      'password': _passwordController.text.isNotEmpty
          ? _passwordController.text.trim()
          : _admin!['password'],
    };
    await DBHelper.updateAdmin(updatedAdmin);
    setState(() => _isEditing = false);
    _passwordController.clear();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _instituteController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kYellow,
      appBar: AppBar(
        backgroundColor: kPurple,
        title: const Text(
          'Profile',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: kWhite),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Admin Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kGreen,
                    child: Text(
                      _admin?['name']?.substring(0, 1).toUpperCase() ?? 'A',
                      style: const TextStyle(
                        fontSize: 35,
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _admin?['name'] ?? '',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _admin?['email'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _admin?['institute'] ?? '',
                    style: const TextStyle(
                      color: kGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Edit Form
            if (_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person, color: kPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email, color: kPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _instituteController,
                      decoration: InputDecoration(
                        labelText: 'Institute Name',
                        prefixIcon: const Icon(Icons.business, color: kPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password (leave empty to keep)',
                        prefixIcon: const Icon(Icons.lock, color: kPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: kWhite),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Staff List
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: kPurple),
                      const SizedBox(width: 8),
                      Text(
                        'Staff Members (${_staffList.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: kBlack,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _staffList.isEmpty
                      ? const Text(
                          'No staff members added yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Column(
                          children: _staffList
                              .map(
                                (s) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: kGreen.withOpacity(0.2),
                                    child: Text(
                                      s['name'].substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: kGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    s['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kBlack,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'ID: ${s['staff_id']} | ${s['shift_time']} ${s['shift_period']}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await DBHelper.deleteStaff(s['id']);
                                      await _loadData();
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// ABOUT SCREEN
// =====================
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          'About Us',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: kWhite),
        elevation: 0,
      ),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school, size: 60, color: kWhite),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ClassMonitorPro',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: kWhite,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Staff Management System',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kWhite.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'by Al-Hafiz Developers',
                          style: TextStyle(
                            fontSize: 18,
                            color: kGreen,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'Version 1.0.0',
                          style: TextStyle(fontSize: 14, color: Colors.white60),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '© 2026 Al-Hafiz\nAll Rights Reserved',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _featureChip('SQLite'),
                      _featureChip('Offline'),
                      _featureChip('Flutter'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureChip(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGreen),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kGreen,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
