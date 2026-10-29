# Đối chiếu backend từ schema ngày 14/10/2026

Đã nhận JSON đầy đủ: 15 bảng public, 49 policies (bao gồm Storage), 6 functions và 7 triggers.
Tất cả ID bài viết, video, bình luận, tin nhắn, hồ sơ, hội thoại và quan hệ bạn bè đều là UUID.
Cột và foreign key cần cho các truy vấn Flutter đã khớp với schema này.

| Phát hiện từ export | Thay đổi |
|---|---|
| Posts thiếu policy UPDATE | Thêm sửa bài của chủ sở hữu; chỉ ghi content/image_url/video_url/media |
| Comments/video_comments thiếu policy DELETE | Cho tác giả xóa bình luận, khóa quyền xóa của người khác |
| Follows ALL chỉ dùng follower_id=auth.uid() | Thêm SELECT cho danh sách người theo dõi/đang theo dõi; giữ quyền ghi theo chủ thể |
| Videos UPDATE dùng USING(true) | Thêm restrictive guard theo chủ sở hữu, giới hạn cột được sửa |
| Profiles RLS UPDATE chỉ giới hạn hàng | Giới hạn cột ghi để client không tự đổi badge/counters/ID |
| Notifications INSERT dùng WITH CHECK(true) | Chặn insert trực tiếp từ client; giữ tạo thông báo bởi trigger |
| Avatar INSERT cho public chỉ kiểm tra bucket | Chặn người chưa đăng nhập; kiểm tra thư mục UUID của người upload |
| Functions SECURITY DEFINER chưa đặt search_path | Dùng tên bảng có schema rõ ràng và search_path rỗng |
| Bình luận chỉ có content | Thêm media và thông báo phù hợp cho ảnh/video |
| Realtime đang có cột cũ | Làm mới các bảng liên quan để gồm media và giữ các bảng khác |
| Unique hội thoại/bạn bè chỉ theo thứ tự 2 ID | Thêm unique không phụ thuộc thứ tự, dừng cài nếu đang có dữ liệu trùng |

Không xóa/đổi ID bài viết, người dùng, hội thoại hay tin nhắn. Không tự ghép hội thoại trùng khi chưa
biết dữ liệu. `KIEM_TRA_TRUOC.sql` chỉ trả số đếm lỗi để xác định có cần xử lý dữ liệu trước hay không.

Cloudinary từ ảnh: `h60ricpv`, Dynamic folders, `social_app_preset` Unsigned,
asset folder `social-app/videos`. Giữ preset cũ; bản mới cần preset Signed riêng `tiniky_signed`.
Chữ ký được tạo trong Edge Function; API secret chỉ nhập vào Supabase Secrets.

Đã đạt kiểm tra cú pháp và 32 kiểm thử SQL cục bộ. Bản public schema được tái tạo từ export;
Auth/Storage internals và grants là mô hình thử nghiệm vì không nằm trong export. Không có user rows
hoặc tin nhắn thật trong fixture. Chưa thử dữ liệu thật, Edge Functions, upload/call hoặc Flutter build.
File `tools/fixtures/supabase_export_20261014.sql` CHỈ dành cho công cụ kiểm thử cục bộ.
Không chạy file fixture trên Supabase.

Lệnh kiểm tra SQL (Node.js, không yêu cầu Flutter):

```powershell
npm install --prefix .sql-check @electric-sql/pglite
$env:PGLITE_MODULE = (Resolve-Path .sql-check/node_modules/@electric-sql/pglite/dist/index.js).Path
$env:SCHEMA_FIXTURE = "exported"
node tools/verify_database.mjs
```

Tài liệu tham khảo:

- [Supabase: RLS và grants](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase: quyền ghi theo cột](https://supabase.com/docs/guides/database/postgres/column-level-security)
- [PostgreSQL: kết hợp policies](https://www.postgresql.org/docs/16/sql-createpolicy.html)
- [Supabase: Authorization của Edge Functions](https://supabase.com/docs/guides/functions/auth-headers)
