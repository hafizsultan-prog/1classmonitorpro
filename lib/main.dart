import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

// ========== DATABASE HELPER ==========
class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = p.join(await getDatabasesPath(), 'classmonitorpro.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE staff (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            shiftTime TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            staffId TEXT NOT NULL,
            staffName TEXT NOT NULL,
            date TEXT NOT NULL,
            scanTime TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE admin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            password TEXT NOT NULL,
            whatsapp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<void> saveAdmin(
    String name,
    String email,
    String password,
    String whatsapp,
  ) async {
    final database = await db;
    await database.delete('admin');
    await database.insert('admin', {
      'name': name,
      'email': email,
      'password': password,
      'whatsapp': whatsapp,
    });
  }

  static Future<Map<String, dynamic>?> getAdmin() async {
    final database = await db;
    final result = await database.query('admin', limit: 1);
    return result.isEmpty ? null : result.first;
  }

  static Future<bool> loginAdmin(String email, String password) async {
    final database = await db;
    final result = await database.query(
      'admin',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty;
  }

  static Future<bool> addStaff(String id, String name, String shiftTime) async {
    final database = await db;
    final existing = await database.query(
      'staff',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (existing.isNotEmpty) return false;
    await database.insert('staff', {
      'id': id,
      'name': name,
      'shiftTime': shiftTime,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return true;
  }

  static Future<List<Map<String, dynamic>>> getAllStaff() async {
    final database = await db;
    return await database.query('staff', orderBy: 'name ASC');
  }

  static Future<Map<String, dynamic>?> getStaffById(String id) async {
    final database = await db;
    final result = await database.query(
      'staff',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isEmpty ? null : result.first;
  }

  static Future<void> deleteStaff(String id) async {
    final database = await db;
    await database.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> markAttendance(
    String staffId,
    String staffName,
    String date,
    String scanTime,
    String status,
  ) async {
    final database = await db;
    final existing = await database.query(
      'attendance',
      where: 'staffId = ? AND date = ?',
      whereArgs: [staffId, date],
    );
    if (existing.isNotEmpty) return false;
    await database.insert('attendance', {
      'staffId': staffId,
      'staffName': staffName,
      'date': date,
      'scanTime': scanTime,
      'status': status,
    });
    return true;
  }

  static Future<List<Map<String, dynamic>>> getTodayAttendance() async {
    final database = await db;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return await database.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [today],
    );
  }

  static Future<List<Map<String, dynamic>>> getAttendanceByStaff(
    String staffId,
  ) async {
    final database = await db;
    final now = DateTime.now();
    final fiveMonthsAgo = DateTime(now.year, now.month - 5, now.day);
    final fromDate =
        '${fiveMonthsAgo.year}-${fiveMonthsAgo.month.toString().padLeft(2, '0')}-${fiveMonthsAgo.day.toString().padLeft(2, '0')}';
    return await database.query(
      'attendance',
      where: 'staffId = ? AND date >= ?',
      whereArgs: [staffId, fromDate],
      orderBy: 'date DESC',
    );
  }

  static Future<List<Map<String, dynamic>>>
  getAllAttendanceLast5Months() async {
    final database = await db;
    final now = DateTime.now();
    final fiveMonthsAgo = DateTime(now.year, now.month - 5, now.day);
    final fromDate =
        '${fiveMonthsAgo.year}-${fiveMonthsAgo.month.toString().padLeft(2, '0')}-${fiveMonthsAgo.day.toString().padLeft(2, '0')}';
    return await database.query(
      'attendance',
      where: 'date >= ?',
      whereArgs: [fromDate],
      orderBy: 'date DESC',
    );
  }
}

// ========== MAIN ==========
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

// ========== SPLASH SCREEN ==========
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rocketController;
  late AnimationController _starsController;
  late AnimationController _fadeController;
  late AnimationController _textController;
  late Animation<double> _rocketAnim;
  late Animation<double> _starsAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _textAnim;
  late Animation<Offset> _slideAnim;
  @override
  void initState() {
    super.initState();
    _rocketController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _rocketAnim = Tween<double>(begin: -20.0, end: 20.0).animate(
      CurvedAnimation(parent: _rocketController, curve: Curves.easeInOut),
    );
    _starsAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_starsController);
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _textAnim = CurvedAnimation(parent: _textController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 4), () async {
        if (!mounted) return;
        final admin = await DBHelper.getAdmin();
        if (!mounted) return;
        if (admin != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HomeScreen(name: admin['name'], email: admin['email']),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _starsController.dispose();
    _fadeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D2B),
              Color(0xFF1A1A4E),
              Color(0xFF2D1B69),
              Color(0xFF4C1D95),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _starsAnim,
                builder: (context, child) => CustomPaint(
                  painter: StarsPainter(_starsAnim.value),
                  size: Size.infinite,
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rocketAnim,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _rocketAnim.value),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🚀', style: TextStyle(fontSize: 55)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _textAnim,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFE879F9),
                                  Color(0xFF818CF8),
                                  Color(0xFF38BDF8),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'ClassMonitorPro',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: const Text(
                                'Staff Management System',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C3AED),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarsPainter extends CustomPainter {
  final double progress;
  StarsPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2.5 + 0.5;
      final opacity = (sin((progress + i / 100) * 2 * pi) + 1) / 2;
      final paint = Paint()..color = Colors.white.withOpacity(opacity * 0.9);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(StarsPainter oldDelegate) => true;
}

// ========== LOGIN SCREEN ==========
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _isSignUp = false;
  bool _isLoading = false;
  late AnimationController _robotController;
  late Animation<double> _robotAnim;

  @override
  void initState() {
    super.initState();
    _robotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _robotAnim = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(parent: _robotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _robotController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String name = _nameController.text.trim();
    String whatsapp = _whatsappController.text.trim();
    if (_isSignUp) {
      if (name.isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          whatsapp.isEmpty) {
        setState(() {
          _errorMessage = 'All fields are required!';
          _isLoading = false;
        });
        return;
      }
      if (!_isValidEmail(email)) {
        setState(() {
          _errorMessage = 'Invalid email address!';
          _isLoading = false;
        });
        return;
      }
      if (password.length < 6) {
        setState(() {
          _errorMessage = 'Password must be at least 6 characters!';
          _isLoading = false;
        });
        return;
      }
      if (whatsapp.length < 10) {
        setState(() {
          _errorMessage = 'Invalid WhatsApp number!';
          _isLoading = false;
        });
        return;
      }
      await DBHelper.saveAdmin(name, email, password, whatsapp);
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(name: name, email: email),
          ),
        );
    } else {
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter email and password!';
          _isLoading = false;
        });
        return;
      }
      final success = await DBHelper.loginAdmin(email, password);
      if (success) {
        final admin = await DBHelper.getAdmin();
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HomeScreen(name: admin!['name'], email: admin['email']),
            ),
          );
      } else {
        setState(() {
          _errorMessage = 'Incorrect email or password!';
          _isLoading = false;
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white60),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white60,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF6B21A8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _robotAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_robotAnim.value, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Text('🤖', style: TextStyle(fontSize: 60)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome!',
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const Text(
                  'ClassMonitorPro',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Staff Management System',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 24),
                if (_isSignUp) ...[
                  _buildField(_nameController, 'Your Name', Icons.person),
                  const SizedBox(height: 14),
                ],
                _buildField(
                  _emailController,
                  'Email Address',
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _buildField(
                  _passwordController,
                  'Password',
                  Icons.lock,
                  isPassword: true,
                ),
                const SizedBox(height: 14),
                if (_isSignUp) ...[
                  _buildField(
                    _whatsappController,
                    'WhatsApp Number',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Login',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = '';
                  }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Login'
                        : 'Create new account',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== HOME SCREEN ==========
class HomeScreen extends StatefulWidget {
  final String name;
  final String email;
  const HomeScreen({super.key, required this.name, required this.email});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _staffCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStaffCount();
  }

  Future<void> _loadStaffCount() async {
    final staff = await DBHelper.getAllStaff();
    if (mounted) setState(() => _staffCount = staff.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4C1D95), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ClassMonitorPro',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          'Welcome, ${widget.name}! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.name.isNotEmpty
                            ? widget.name[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Staff Members: $_staffCount',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
                children: [
                  _DashCard(
                    icon: Icons.group_add,
                    label: 'Staff Members',
                    subtitle: 'Add & Manage',
                    color: const Color(0xFF6366F1),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StaffDataScreen(),
                        ),
                      );
                      _loadStaffCount();
                    },
                  ),
                  _DashCard(
                    icon: Icons.qr_code,
                    label: 'QR Generator',
                    subtitle: 'Generate Cards',
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QRGeneratorScreen(),
                      ),
                    ),
                  ),
                  _DashCard(
                    icon: Icons.today,
                    label: "Today's Attendance",
                    subtitle: "Today's Record",
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TodayAttendanceScreen(),
                      ),
                    ),
                  ),
                  _DashCard(
                    icon: Icons.history,
                    label: '3-5 Month Record',
                    subtitle: 'Past Records',
                    color: const Color(0xFFEF4444),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ThreeMonthRecordScreen(),
                      ),
                    ),
                  ),
                  _DashCard(
                    icon: Icons.manage_search,
                    label: 'Check Record',
                    subtitle: 'Search by ID',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CheckRecordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BottomBtn(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(name: widget.name, email: widget.email),
                    ),
                  ),
                ),
                _BottomBtn(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan QR',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                    );
                    _loadStaffCount();
                  },
                ),
                _BottomBtn(
                  icon: Icons.info_outline,
                  label: 'About Us',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _DashCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4C1D95).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4C1D95), size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF4C1D95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== STAFF DATA SCREEN ==========
class StaffDataScreen extends StatefulWidget {
  const StaffDataScreen({super.key});
  @override
  State<StaffDataScreen> createState() => _StaffDataScreenState();
}

class _StaffDataScreenState extends State<StaffDataScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _shiftController = TextEditingController();
  List<Map<String, dynamic>> _staffList = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final staff = await DBHelper.getAllStaff();
    if (mounted) setState(() => _staffList = staff);
  }

  Future<void> _saveStaff() async {
    String name = _nameController.text.trim();
    String id = _idController.text.trim();
    String shift = _shiftController.text.trim();
    if (name.isEmpty || id.isEmpty || shift.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final success = await DBHelper.addStaff(id, name, shift);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been saved!'),
          backgroundColor: Colors.green,
        ),
      );
      _nameController.clear();
      _idController.clear();
      _shiftController.clear();
      await _loadStaff();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This Staff ID already exists!'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String hint = '',
  }) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4C1D95)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4C1D95), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          'Staff Members',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.group_add, color: Color(0xFF4C1D95)),
                      SizedBox(width: 8),
                      Text(
                        'Add New Staff Member',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C1D95),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field(_nameController, 'Staff Name', Icons.person),
                  const SizedBox(height: 14),
                  _field(
                    _idController,
                    'Staff ID (Must be unique)',
                    Icons.badge,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _shiftController,
                    'Shift Time (e.g. 8:00 AM)',
                    Icons.access_time,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveStaff,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Staff Member',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C1D95),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_staffList.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.people, color: Color(0xFF4C1D95)),
                  const SizedBox(width: 8),
                  Text(
                    'Registered Staff (${_staffList.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._staffList.map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4C1D95),
                      child: Text(
                        (s['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      s['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('ID: ${s['id']} | Shift: ${s['shiftTime']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await DBHelper.deleteStaff(s['id']);
                        await _loadStaff();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ========== QR GENERATOR SCREEN ==========
class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});
  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final staff = await DBHelper.getAllStaff();
    if (mounted) setState(() => _staffList = staff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          'QR Generator',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _staffList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Please add staff members first!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                final qrData =
                    '${staff['id']}|${staff['name']}|${staff['shiftTime']}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.1),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4C1D95), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'ClassMonitorPro',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 2,
                                ),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 160,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              staff['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _InfoChip(Icons.badge, 'ID: ${staff['id']}'),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  Icons.access_time,
                                  staff['shiftTime'],
                                ),
                              ],
                            ),
                          ],
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4C1D95).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4C1D95)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4C1D95)),
          ),
        ],
      ),
    );
  }
}

// ========== SCAN QR SCREEN ==========
class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});
  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _scanned = false;
  String _result = '';
  Color _resultColor = Colors.green;

  Future<void> _processQR(String qrData) async {
    if (_scanned) return;
    setState(() => _scanned = true);
    final parts = qrData.split('|');
    if (parts.length < 3) {
      setState(() {
        _result = 'Invalid QR Code!';
        _resultColor = Colors.red;
      });
      return;
    }
    String staffId = parts[0];
    String staffName = parts[1];
    String shiftTime = parts[2];
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final shiftClean = shiftTime.replaceAll(' AM', '').replaceAll(' PM', '');
    final shiftParts = shiftClean.split(':');
    int shiftHour = int.tryParse(shiftParts[0]) ?? 8;
    int shiftMin = shiftParts.length > 1 ? int.tryParse(shiftParts[1]) ?? 0 : 0;
    if (shiftTime.contains('PM') && shiftHour != 12) shiftHour += 12;
    String status = 'present';
    if (now.hour > shiftHour ||
        (now.hour == shiftHour && now.minute > shiftMin + 5))
      status = 'late';
    final success = await DBHelper.markAttendance(
      staffId,
      staffName,
      today,
      timeStr,
      status,
    );
    if (success) {
      setState(() {
        _result =
            '$staffName\n${status == 'late' ? 'Late Present!' : 'Present!'}\nTime: $timeStr';
        _resultColor = status == 'late' ? Colors.orange : Colors.green;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$staffName attendance marked!'),
            backgroundColor: _resultColor,
          ),
        );
    } else {
      setState(() {
        _result = '$staffName attendance already marked today!';
        _resultColor = Colors.orange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_scanned)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => setState(() {
                _scanned = false;
                _result = '';
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Camera will open\non Android device',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_result.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: _resultColor.withOpacity(0.1),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _resultColor,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_scanned) {
                    setState(() {
                      _scanned = false;
                      _result = '';
                    });
                  } else {
                    await _processQR('S001|Ali Hassan|8:00 AM');
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_scanned ? 'Scan Again' : 'Demo Scan (Test)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C1D95),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== TODAY ATTENDANCE ==========
class TodayAttendanceScreen extends StatefulWidget {
  const TodayAttendanceScreen({super.key});
  @override
  State<TodayAttendanceScreen> createState() => _TodayAttendanceScreenState();
}

class _TodayAttendanceScreenState extends State<TodayAttendanceScreen> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final records = await DBHelper.getTodayAttendance();
    if (mounted) setState(() => _records = records);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          "Today's Attendance",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance recorded today!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final r = _records[index];
                final status = r['status'] as String;
                Color boxColor = Colors.white;
                Color textColor = Colors.black;
                Color statusColor = Colors.green;
                String statusLabel = 'Present';
                String boxLabel = 'P';
                if (status == 'late') {
                  boxColor = Colors.yellow;
                  statusColor = Colors.orange;
                  statusLabel = 'Late';
                } else if (status == 'absent') {
                  boxColor = Colors.red;
                  textColor = Colors.white;
                  statusColor = Colors.red;
                  statusLabel = 'Absent';
                  boxLabel = 'A';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: boxColor,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          boxLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      r['staffName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'ID: ${r['staffId']} | Time: ${r['scanTime']}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ========== 3-5 MONTH RECORD ==========
class ThreeMonthRecordScreen extends StatefulWidget {
  const ThreeMonthRecordScreen({super.key});
  @override
  State<ThreeMonthRecordScreen> createState() => _ThreeMonthRecordScreenState();
}

class _ThreeMonthRecordScreenState extends State<ThreeMonthRecordScreen> {
  List<Map<String, dynamic>> _staffList = [];
  Map<String, Map<String, int>> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final staff = await DBHelper.getAllStaff();
    final allAttendance = await DBHelper.getAllAttendanceLast5Months();
    Map<String, Map<String, int>> stats = {};
    for (var s in staff) {
      String id = s['id'];
      final records = allAttendance.where((r) => r['staffId'] == id).toList();
      stats[id] = {
        'total': records.length,
        'present': records.where((r) => r['status'] == 'present').length,
        'late': records.where((r) => r['status'] == 'late').length,
        'absent': records.where((r) => r['status'] == 'absent').length,
      };
    }
    if (mounted)
      setState(() {
        _staffList = staff;
        _stats = stats;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          '3-5 Month Record',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _staffList.isEmpty
          ? const Center(
              child: Text(
                'No staff members found!',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                final stat =
                    _stats[staff['id']] ??
                    {'total': 0, 'present': 0, 'late': 0, 'absent': 0};
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF4C1D95),
                              radius: 18,
                              child: Text(
                                (staff['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'ID: ${staff['id']} | Shift: ${staff['shiftTime']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatCard(
                              'Total Days',
                              '${stat['total']}',
                              const Color(0xFF6366F1),
                            ),
                            _StatCard(
                              'Present',
                              '${stat['present']}',
                              const Color(0xFF10B981),
                            ),
                            _StatCard(
                              'Late',
                              '${stat['late']}',
                              const Color(0xFFF59E0B),
                            ),
                            _StatCard(
                              'Absent',
                              '${stat['absent']}',
                              const Color(0xFFEF4444),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ========== CHECK RECORD ==========
class CheckRecordScreen extends StatefulWidget {
  const CheckRecordScreen({super.key});
  @override
  State<CheckRecordScreen> createState() => _CheckRecordScreenState();
}

class _CheckRecordScreenState extends State<CheckRecordScreen> {
  final _idController = TextEditingController();
  Map<String, dynamic>? _foundStaff;
  List<Map<String, dynamic>> _records = [];
  bool _isSearching = false;

  Future<void> _search() async {
    String id = _idController.text.trim();
    if (id.isEmpty) return;
    setState(() => _isSearching = true);
    final staff = await DBHelper.getStaffById(id);
    if (staff == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff ID not found!'),
            backgroundColor: Colors.red,
          ),
        );
      setState(() {
        _foundStaff = null;
        _records = [];
        _isSearching = false;
      });
      return;
    }
    final records = await DBHelper.getAttendanceByStaff(id);
    if (mounted)
      setState(() {
        _foundStaff = staff;
        _records = records;
        _isSearching = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    int present = _records.where((r) => r['status'] == 'present').length;
    int late = _records.where((r) => r['status'] == 'late').length;
    int absent = _records.where((r) => r['status'] == 'absent').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C1D95),
        title: const Text(
          'Check Record',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        hintText: 'Enter Staff ID',
                        prefixIcon: Icon(Icons.badge, color: Color(0xFF4C1D95)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSearching ? null : _search,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C1D95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_foundStaff != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF4C1D95),
                      child: Text(
                        (_foundStaff!['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _foundStaff!['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${_foundStaff!['id']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Shift: ${_foundStaff!['shiftTime']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCard(
                          'Total',
                          '${_records.length}',
                          const Color(0xFF6366F1),
                        ),
                        _StatCard(
                          'Present',
                          '$present',
                          const Color(0xFF10B981),
                        ),
                        _StatCard('Late', '$late', const Color(0xFFF59E0B)),
                        _StatCard('Absent', '$absent', const Color(0xFFEF4444)),
                      ],
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

// ========== PROFILE SCREEN ==========
class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  const ProfileScreen({super.key, required this.name, required this.email});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _staffCount = 0;
  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final staff = await DBHelper.getAllStaff();
    if (mounted)
      setState(() {
        _staffCount = staff.length;
        _staffList = staff;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4C1D95), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _InfoTile(Icons.person, 'Admin Name', widget.name),
                  _InfoTile(Icons.email, 'Login Email', widget.email),
                  _InfoTile(
                    Icons.people,
                    'Total Staff',
                    '$_staffCount members',
                  ),
                  if (_staffList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Staff Members',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4C1D95),
                              ),
                            ),
                          ),
                          ..._staffList.map(
                            (s) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4C1D95),
                                radius: 16,
                                child: Text(
                                  (s['name'] as String)[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                s['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('ID: ${s['id']}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4C1D95).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4C1D95), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========== ABOUT US ==========
class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});
  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_rotateController);
    _pulseAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(_pulseController);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('About Us', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          CustomPaint(painter: StarsPainter(0.5), size: Size.infinite),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: AnimatedBuilder(
                      animation: _rotateAnim,
                      builder: (context, child) => Transform.rotate(
                        angle: _rotateAnim.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🚀', style: TextStyle(fontSize: 45)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFE879F9),
                      Color(0xFF818CF8),
                      Color(0xFF38BDF8),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'ClassMonitorPro',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: const Text(
                    'Staff Management System',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Fast & easy staff attendance tracking with QR scanning technology.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
