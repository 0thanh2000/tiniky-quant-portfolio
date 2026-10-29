# Tiniky social_app

Ứng dụng Flutter với Supabase và Cloudinary.

Bản dọn lint ngày 14/10/2026: cập nhật `lib` và `pubspec.yaml` trong project đang dùng,
chạy `flutter pub get`, `flutter analyze`, `flutter test`, rồi build APK khi các bước trước đạt.
Log analyzer bạn gửi trước bản này có 0 error, 7 warning, 97 info. Chưa có APK được nghiệm thu.

Bắt đầu ở **[HUONG_DAN.md](HUONG_DAN.md)**. Bản sửa gồm các chức năng bảng tin đa phương tiện,
trang cá nhân/bạn bè, chat, bình luận, chia sẻ và gọi WebRTC foreground.

Đã đối chiếu schema Supabase bạn gửi ngày 14/10/2026 và bổ sung migration 004.
Ảnh chẩn đoán có hai bản ghi tự kết nối. Chạy `supabase/SUA_HAI_BAN_GHI_TU_KET_NOI.sql`
một lần để sao lưu rồi dọn hai bản ghi trước khi cài, theo hướng dẫn.
Chạy `supabase/KIEM_TRA_TRUOC.sql` trước. Lần cài đầu có thể dùng `supabase/INSTALLER_SQL_EDITOR.sql`
thay cho việc chạy bốn migration riêng, theo hướng dẫn. Không chạy cả hai cách.

Bạn đã xác nhận cài SQL và deploy 6 Edge Functions thành công. Các hướng dẫn cài database
phía trên chỉ dành cho môi trường chưa áp dụng migration. Xem hướng dẫn để kiểm tra Signed Cloudinary,
private chat storage và TURN; upload/cuộc gọi chưa được nghiệm thu trên điện thoại.
