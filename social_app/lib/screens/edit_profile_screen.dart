import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class EditProfileScreen extends
  const EditProfileScreen({
    super.key,
    required this.profile,
    this.onlyAvatar = false,
    this.onlyCover = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;

  late TextEditingController _username;
  late TextEditingController _bio;
  late TextEditingController _hometown;
  late TextEditingController _currentCity;
  late TextEditingController _work;
  late TextEditingController _education;
  late TextEditingController _relationship;

  Uint8List? _avatarBytes;
  Uint8List? _coverBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _username =
        TextEditingController(text: widget.profile?['username'] ?? '');
    _bio = TextEditingController(text: widget.profile?['bio'] ?? '');
    _hometown =
        TextEditingController(text: widget.profile?['hometown'] ?? '');
    _currentCity = TextEditingController(
        text: widget.profile?['current_city'] ?? '');

    if (widget.onlyAvatar) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _pickAvatar());
    } else if (widget.onlyCover) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _pickCover());
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    _hometown.dispose();
    _currentCity.dispose();
    _work.dispose();
    _education.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _coverBytes = bytes);
  Future<void> _save() async {
    if (_isSaving) return;
    // Kiểm tra nếu là onlyCover/onlyAvatar thì phải có ảnh
    if (widget.onlyAvatar && _avatarBytes == null) {
      _showError('Vui lòng chọn ảnh đại diện');
      return;
    }
    if (widget.onlyCover && _coverBytes == null) {
      _showError('Vui lòng chọn ảnh bìa');
      return;
    }

    setState(() => _isSaving = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      _showError('Chưa đăng nhập');
      return;
    }

    try {
      if ((_avatarBytes?.length ?? 0) > 10 * 1024 * 1024 ||
          (_coverBytes?.length ?? 0) > 10 * 1024 * 1024) {
        throw Exception('Ảnh đại diện và ảnh bìa tối đa 10 MB mỗi ảnh.');
      }
      String? avatarUrl = widget.profile?['avatar_url'];
      String? coverUrl = widget.profile?['cover_url'];

      // Upload avatar
      if (_avatarBytes != null) {
        final path =
            '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      // Upload cover
      if (_coverBytes != null) {
        final path =
            '${user.id}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('avatars')
            .uploadBinary(path, _coverBytes!);
        coverUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      }

      // Chuẩn bị data update
      final Map<String, dynamic> updateData = {
        'avatar_url': avatarUrl,
        'cover_url': coverUrl,
      };

      // Nếu không phải onlyAvatar/onlyCover thì update thêm các field text
      if (!widget.onlyAvatar && !widget.onlyCover) {
        updateData['username'] = _username.text.trim();
        updateData['bio'] = _bio.text.trim();
        updateData['hometown'] = _hometown.text.trim();
        updateData['current_city'] = _currentCity.text.trim();
        updateData['work'] = _work.text.trim();
        updateData['education'] = _education.text.trim();
        updateData['relationship_status'] = _relationship.text.trim();
      }


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thành công! ✅'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showForm = !widget.onlyAvatar && !widget.onlyCover;
    final title = widget.onlyAvatar
        ? 'Đổi ảnh đại diện'
        : widget.onlyCover
            ? 'Đổi ảnh bìa'
            : 'Chỉnh sửa trang cá nhân';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(title),
        actions: [
          // LUÔN hiển thị nút LƯU
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gradStart),
                  )
                : const Text(
                    'LƯU',
                    style: TextStyle(
                      color: AppColors.gradStart,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== PREVIEW AVATAR / COVER =====
            if (widget.onlyAvatar) _buildAvatarPreview(isDark)
            else if (widget.onlyCover) _buildCoverPreview(isDark)
            else ...[
              _buildCoverPreview(isDark),
              const SizedBox(height: 20),
              _buildAvatarPreview(isDark),
            ],

            // ===== FORM =====
            if (showForm) ...[
              const SizedBox(height: 20),
              _buildField(Icons.person_outline, 'Tên hiển thị', _username,
                  isDark),
              _buildField(Icons.info_outline, 'Tiểu sử', _bio, isDark,
                  maxLines: 3),
              _buildField(
                  Icons.home_outlined, 'Quê quán', _hometown, isDark),
              _buildField(Icons.location_on_outlined, 'Nơi ở',
                  _currentCity, isDark),
              _buildField(
                  Icons.work_outline, 'Công việc', _work, isDark),
              _buildField(Icons.school_outlined, 'Học vấn', _education,
                  isDark),
              _buildField(Icons.favorite_outline, 'Mối quan hệ',
                  _relationship, isDark),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gradStart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          'LƯU THAY ĐỔI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ]
            // ===== NÚT CHO ONLY AVATAR/COVER =====
            else ...[
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed:
                      widget.onlyAvatar ? _pickAvatar : _pickCover,
                  icon: Icon(
                    Icons.image_outlined,
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  label: Text(
                    'CHỌN ẢNH KHÁC',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gradStart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          'LƯU',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================
  // AVATAR PREVIEW
  // ============================================
  Widget _buildAvatarPreview(bool isDark) {
    final avatarUrl = widget.profile?['avatar_url'];
    return Center(
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primaryGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkBg : Colors.white,
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.gradStart,
                  backgroundImage: _avatarBytes != null
                      ? MemoryImage(_avatarBytes!)
                      : (avatarUrl != null && avatarUrl.toString().isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null),
                  child: _avatarBytes == null &&
                          (avatarUrl == null ||
                              avatarUrl.toString().isEmpty)
                      ? const Icon(Icons.person,
                          size: 60, color: Colors.white)
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gradStart,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBg : Colors.white,
                    width: 3,
                  ),
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // COVER PREVIEW (Tỷ lệ chữ nhật 1.78:1)
  // ============================================
  Widget _buildCoverPreview(bool isDark) {
    final coverUrl = widget.profile?['cover_url'];
    return GestureDetector(
      onTap: _pickCover,
      child: AspectRatio(
        aspectRatio: 1.78,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _coverBytes == null &&
                    (coverUrl == null || coverUrl.toString().isEmpty)
                ? AppGradients.primaryGradient
                : null,
            image: _coverBytes != null
                ? DecorationImage(
                    image: MemoryImage(_coverBytes!), fit: BoxFit.cover)
                : (coverUrl != null && coverUrl.toString().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(coverUrl), fit: BoxFit.cover)
                    : null),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt,
                  color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // TEXT FIELD
  // ============================================
  Widget _buildField(
      IconData icon, String label, TextEditingController controller,
      bool isDark,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.gradStart),
          filled: true,
          fillColor: isDark ? AppColors.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.gradStart, width: 2),
          ),
        ),
      ),
    );
  }
}
