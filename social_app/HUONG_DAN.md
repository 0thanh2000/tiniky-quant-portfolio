# Tiniky — hướng dẫn nhận bản sửa và cấu hình

Bản này là mã nguồn đã sửa, CHƯA phải APK đã build hoặc bản đã triển khai lên tài khoản của bạn.
Giữ màu xanh, thanh điều hướng và bố cục chính hiện có; làm lại phần chat/bình luận.
Đọc phần kiểm chứng cuối tài liệu trước khi đưa lên ứng dụng thật.

**Trạng thái đã xác nhận qua ảnh/log của bạn ngày 14/10/2026:** đã sao lưu/dọn hai bản ghi lỗi,
chạy kiểm tra dữ liệu toàn bộ 0, installer SQL báo Success, deploy đủ 6 Edge Functions.
`flutter pub get` đã thành công. Log analyzer trước bản dọn lint có 0 error, 7 warning và 97 info.
Người dùng đã báo hoàn tất nhập Cloudinary Secrets; chưa kiểm thử upload thực tế.

**Bản cập nhật Flutter hiện tại:** thay thư mục `lib` và file `pubspec.yaml` trong project đang dùng
bằng bản trong ZIP mới. Giữ `pubspec.lock` mà máy bạn vừa tạo và chạy lại `flutter pub get`.
Sau đó chạy `flutter analyze`, `flutter test` rồi `flutter build apk --debug` nếu các bước trước đạt.
Phần SQL/Edge Functions đã triển khai không cần chạy lại khi chỉ cập nhật các file Flutter này.
Các phần hướng dẫn cài database bên dưới dành cho môi trường chưa cài.

**Cập nhật sau khi nhận schema ngày 14/10/2026:** đã đối chiếu 15 bảng public,
49 policies, 6 functions và 7 triggers từ kết quả bạn gửi. Có thêm migration 004
và file cài đặt gộp dành cho SQL Editor. Chưa chạy SQL lên tài khoản của bạn.

**Cập nhật theo ảnh chẩn đoán 14/10:** có một hội thoại tự nhắn, 0 tin nhắn, và một quan hệ
tự kết bạn ở trạng thái accepted. Chạy `supabase/SUA_HAI_BAN_GHI_TU_KET_NOI.sql` một lần
trước installer. File sẽ sao lưu hai bản ghi trong bảng riêng tư `app_repair_archive`, rồi dọn
hai bản ghi lỗi. Không xóa tin nhắn hoặc các quan hệ hợp lệ. Nếu có tin nhắn mới hoặc dữ liệu khác
ảnh chẩn đoán, file tự dừng và hoàn tác. Kết quả mong đợi `so_ban_ghi_da_sao_luu = 2`.

**Sau đó:** mở `supabase/KIEM_TRA_TRUOC.sql`, sao chép vào SQL Editor và Run.
Nếu cả 5 dòng `issue_count` đều bằng 0, có thể thử `supabase/INSTALLER_SQL_EDITOR.sql`
trên project kiểm thử có cùng schema/dữ liệu. Nếu có số lớn hơn 0, gửi kết quả kiểm tra;
không chạy installer hoặc xóa dữ liệu để bỏ qua lỗi. Xem phần 3 để triển khai.

## 1. Việc bạn cần làm ngay: gửi cấu trúc Supabase và preset Cloudinary

Bạn không cần tải mã Flutter lên Supabase hay Cloudinary để tôi xem cấu hình.
Bạn cần lấy thông tin từ hai dịch vụ và tải kết quả vào cuộc trò chuyện.

### Supabase — cách làm bằng giao diện, không cần cài Docker

1. Đăng nhập Supabase Dashboard và mở đúng project đang dùng cho app.
2. Mở **SQL Editor → New query**.
3. Mở file `supabase/export_structure.sql` trong gói này bằng VS Code/Notepad.
4. Sao chép toàn bộ nội dung file vào SQL Editor, nhấn **Run**.
5. Kết quả có cột `schema_export`. Dùng nút xuất kết quả JSON/CSV nếu có;
   hoặc sao chép đầy đủ ô kết quả vào file `supabase_structure.json` (Notepad → Save As → UTF-8).
6. Gửi file kết quả vào cuộc trò chuyện.

Đây là truy vấn chỉ đọc cấu trúc, không sửa bảng và không xuất tin nhắn/người dùng.
Nó thu thập cột, kiểu dữ liệu, khóa ngoại, index, RLS, functions, triggers,
thông tin bucket và các bảng đã bật Realtime. Nếu trước đây bạn viết bí mật trực tiếp
trong thân SQL function, hãy thay giá trị bí mật đó bằng `REDACTED` trước khi gửi.

Schema bạn gửi đã được đối chiếu: ID các bảng liên quan đều là UUID và các cột cần dùng đã khớp.
File xuất không chứa dữ liệu nên chưa biết có cặp hội thoại/bạn bè trùng hai chiều hay không.
`KIEM_TRA_TRUOC.sql` kiểm tra phần này bằng số đếm, không xuất tin nhắn hoặc danh sách người dùng.
Nếu database thay đổi sau lần export này, cần đối chiếu lại trước khi triển khai.

Trong ZIP gốc đã có bốn Edge Functions `notify-like`, `notify-comment`, `notify-follow`, `notify-chat`.
Nếu bản đang chạy trên Supabase khác bản trong ZIP, mở **Edge Functions → tên function → Code**,
sao chép source vào file `.ts` rồi gửi. Không gửi giá trị trong mục Secrets.
Nếu dùng CLI đã cài, có thể dùng `supabase functions download --project-ref YOUR_PROJECT_REF`.

### Cloudinary — thông tin cần gửi

1. Mở Cloudinary Console đúng product environment.
2. Vào **Settings → Upload → Upload presets** (hoặc mục **Upload Presets** trong Settings).
3. Tìm preset đang dùng, mở **Edit**.
4. Chụp các mục: tên preset, Signed/Unsigned, allowed formats, giới hạn dung lượng,
   folder/asset folder, incoming/eager transformations nếu có.
5. Gửi ảnh và **Cloud name** vào cuộc trò chuyện. Không gửi API secret.

Ảnh bạn gửi đã xác nhận Cloud name **`h60ricpv`**, chế độ **Dynamic folders**,
preset **`social_app_preset`** là **Unsigned**, asset folder **`social-app/videos`**.
Giữ preset này để app cũ còn dùng được; tạo preset Signed riêng cho bản mới.
Mã cũ dùng preset tên `social_app_preset` cho video, còn ảnh bài viết dùng Supabase Storage.
Bản sửa dùng upload Cloudinary có chữ ký cho nội dung công khai. Vì vậy preset mới cần là **Signed**;
chỉ có tên preset cũ chưa đủ để bật upload mới.

## 2. Những thay đổi trong mã nguồn

| Phần | Hành vi đã triển khai trong code |
|---|---|
| Bảng tin | Bài chữ, nhiều ảnh, video hoặc kết hợp; tối đa 10 tệp/bài |
| Soạn/sửa bài | Xem trước, bỏ từng tệp, thêm tệp, giữ tệp đã upload khi retry cùng lần soạn |
| Bài dài | Thu gọn 5 dòng, bấm nội dung/“Xem đầy đủ” mở trang chi tiết |
| Trang cá nhân | Nút đăng bài, tab Bạn bè, ảnh/video từ các bài mới xuất hiện trong tab tương ứng |
| Kết bạn | Gửi lời mời tự theo dõi; chấp nhận tạo theo dõi chiều ngược lại; xử lý lời mời đến khác lời mời đi |
| Chia sẻ | Bảng chia sẻ hệ thống cho bài viết, hồ sơ và video; đường dẫn `tiniky://...` |
| Chat | Danh sách hội thoại gần đây, tìm người, gửi chữ/ảnh/video ngắn, mở tệp toàn màn hình, tải tin cũ |
| Bình luận | Giao diện hỗ trợ sáng/tối, ảnh/video, xóa bình luận của mình, tải thêm, cập nhật realtime |
| Cuộc gọi | Gọi thoại/video 1–1 khi app đang mở; nhận/từ chối/kết thúc, mic, camera, loa, đổi camera |
| Backend | Migration bổ sung, RLS riêng tư cho chat/cuộc gọi, signed upload, TURN credentials ngắn hạn |
| Độ ổn định | Giữ bản nháp khi gửi lỗi, chặn gửi lặp, cache tách theo tài khoản, giới hạn lần tải dữ liệu |

Quy ước: hủy lời mời hoặc hủy kết bạn **không tự bỏ theo dõi**. Người dùng có nút Bỏ theo dõi riêng.
Danh sách bạn bè được hiển thị cho người dùng đã đăng nhập, chỉ gồm quan hệ đã chấp nhận.
Bài công khai và bình luận dùng Cloudinary; tệp chat dùng bucket **private** `chat-media` trên Supabase.
Các URL ký để xem tệp chat có hạn một giờ và được cấp lại khi mở tệp.

## 3. Triển khai Supabase theo schema đã đối chiếu

Thử trên project kiểm thử có cùng schema trước, sao lưu dữ liệu và giữ bản ứng dụng cũ.
Có hai cách cài. **Chọn một cách**, không chạy cả installer và các migration riêng.

**Cách A — SQL Editor, lần cài đầu:**

1. Nếu còn hai bản ghi tự kết nối đúng như ảnh đã gửi, chạy `supabase/SUA_HAI_BAN_GHI_TU_KET_NOI.sql` trước.
   File chạy một lần, sao lưu rồi dọn hai bản ghi lỗi; không chạy lại khi đã thành công.
2. Chạy `supabase/KIEM_TRA_TRUOC.sql`. Cả 5 số đếm phải bằng 0.
3. Mở `supabase/INSTALLER_SQL_EDITOR.sql` bằng VS Code/Notepad, Ctrl+A → Ctrl+C.
4. Trong SQL Editor mở **New**, dán toàn bộ nội dung, bấm **Run**.
5. Nếu báo thành công, phần database của bản mới đã được cài; tiếp tục cấu hình/deploy Edge Functions.
6. Installer dùng một transaction. Nếu báo lỗi, mọi thay đổi trong lần chạy đó được hoàn tác.
   Gửi nguyên lỗi để kiểm tra. Nếu phiên SQL còn báo transaction aborted, chạy `ROLLBACK;` trong phiên đó.

**Cách B — project dùng migration CLI hoặc đã áp dụng một phần:**
Chạy các file còn thiếu theo đúng thứ tự:

1. `supabase/migrations/202610130001_social_features.sql`
2. `supabase/migrations/202610130002_upload_limits.sql`
3. `supabase/migrations/202610130003_notification_limits.sql`
4. `supabase/migrations/202610140004_schema_alignment.sql`

Mỗi file có transaction riêng. Chỉ chạy một lần; nếu đã áp dụng thành công không chạy lại.
Nếu preflight/index báo lỗi, gửi nguyên thông báo lỗi; không tự xóa bảng hoặc bỏ constraint.
Migration 004 bổ sung quyền sửa bài/xóa bình luận, mở danh sách follow cho người đã đăng nhập,
giới hạn sửa video theo chủ sở hữu, khóa cột huy hiệu/counters, chặn thông báo giả và upload avatar
ẩn danh. Thông báo vẫn được tạo bởi 7 trigger gốc; các function được giữ hành vi và dùng tên bảng
có schema rõ ràng. Chỉ chủ tài khoản sửa thông tin hồ sơ; cột xác minh do backend quản lý.
Số lượt xem video hiện có được giữ; client không được tự chỉnh `views`. Mã Flutter hiện tại không
ghi nhận lượt xem mới, nên thay đổi quyền này không thay thế một hệ thống đếm view chống gian lận.

Migration tạo bucket `chat-media`, khóa quyền đọc theo thành viên hội thoại, thêm trường media,
RPC tạo hội thoại tránh trùng, tự theo dõi khi kết bạn và các bảng signaling.
Realtime thêm các bảng cần thiết và làm mới column list để bao gồm media; các bảng khác vẫn được giữ.
Kiểm tra Dashboard → Database → Publications/Replication nếu chưa thấy các bảng này.

## 4. Bật upload Cloudinary có chữ ký

1. Ở màn hình Upload presets trong ảnh bạn gửi, bấm **Add Upload Preset**.
   Đặt tên **`tiniky_signed`**, chọn **Signing mode = Signed**, rồi **Save**.
   Không sửa preset `social_app_preset` đang phục vụ bản app cũ.
2. Chỉ cho phép định dạng ảnh/video ứng dụng dùng: jpg, jpeg, png, webp, gif, heic, heif, mp4, mov, webm.
   Chỉnh danh sách theo định dạng tài khoản Cloudinary hỗ trợ.
3. Đặt giới hạn dung lượng ở phía Cloudinary nếu tùy chọn preset/tài khoản hỗ trợ.
   App kiểm tra ảnh tối đa 10 MB, video tối đa 50 MB và 60 giây; cần kiểm tra thêm phía server
   nếu yêu cầu chống client đã bị sửa. Cấu hình preset là phần bắt buộc trước khi dùng thật.
4. Vào Supabase → **Edge Functions → Secrets**, nhập:
   `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CLOUDINARY_SIGNED_PRESET`.
5. Chỉ nhập giá trị thật trong Dashboard. File `supabase/functions/.env.example` chỉ là mẫu.
6. Deploy `cloudinary-sign` cùng thư mục `_shared`. Không nhúng API secret vào Dart.

Nếu đã cài Supabase CLI (Windows có thể chạy qua `npx supabase` khi đã cài Node.js):

```powershell
npx supabase login
npx supabase functions deploy --project-ref pezfnmvomhjvsjgrlper --use-api
```

Chạy ở thư mục có `pubspec.yaml` và `supabase/config.toml`, không chạy trong Windows/System32.
Lệnh trên dùng ID thật của project và deploy qua API, không yêu cầu Docker.
Đăng nhập trên máy của bạn; không gửi token/mật khẩu cho tôi.
Giữ `verify_jwt = true` như `supabase/config.toml`. Function còn xác minh người dùng bằng `getUser()`.
Các function thông báo dùng `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY` trong Secrets.
Bản mới kiểm tra người gửi/sự kiện từ database; không tin tên người gửi hay người nhận do client tự khai.
Thiếu OneSignal chỉ ảnh hưởng push, không ảnh hưởng lưu tin nhắn/bình luận.

## 5. Gọi thoại/video: cần TURN và hai thiết bị thật

Supabase trao đổi tín hiệu cuộc gọi; Cloudinary lưu media; hai dịch vụ này không tự thay thế TURN.
Function `turn-credentials` trong gói này dùng cơ chế **coturn REST shared secret**, không phải
bất kỳ API TURN bên thứ ba nào. Nếu bạn chọn nhà cung cấp có API cấp token riêng, cần đổi function cho đúng.

Cấu hình máy chủ coturn cần tối thiểu:

```ini
use-auth-secret
static-auth-secret=GIU_BI_MAT_TREN_SERVER
realm=turn.ten-mien-cua-ban.vn
fingerprint
```

Cần domain, TLS certificate, cổng UDP/TCP 3478, TLS 5349 và dải cổng relay được mở theo cấu hình coturn.
Đặt `TURN_HOST` (chỉ hostname) và `TURN_SHARED_SECRET` trong Supabase Secrets.
Tài khoản TURN trả về có hạn một giờ; bản này không hứa hỗ trợ cuộc gọi vượt thời hạn đó.

**Phạm vi hiện tại:** hai app đã đăng nhập và đang mở ở foreground. App sẽ kết thúc cuộc gọi khi đưa
xuống background. Chưa có Android Telecom/foreground service/CallKit/PushKit để đổ chuông khi app
bị đóng hoặc màn hình khóa. Nút gọi có luồng WebRTC thật, nhưng chưa thử kết nối thực tế trên thiết bị.
Không xem đây là tính năng cuộc gọi production đã được nghiệm thu.

## 6. Chia sẻ đường dẫn

`Share` mở bảng chia sẻ của điện thoại với link `tiniky://post/UUID`, `tiniky://profile/UUID`
hoặc `tiniky://video/UUID`. App xử lý mở đúng nội dung sau đăng nhập.
Người nhận cần cài app; một số ứng dụng nhắn tin không làm custom-scheme link thành liên kết bấm được.
Chưa có trang web preview và HTTPS App Links/Universal Links cho người chưa cài app.
Muốn chia sẻ đại trà cần cung cấp domain để bổ sung trang đích, assetlinks.json và apple-app-site-association.

## 7. Chạy dự án trên Windows

Giải nén vào thư mục mới để vẫn giữ bản gốc. Mở bằng VS Code, mở Terminal tại thư mục có `pubspec.yaml`.
Giữ Flutter tương thích với phiên bản dự án gốc (ZIP ghi nhận 3.47.7); không cần tự nâng/hạ SDK chỉ vì bản sửa.

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run
```

Bản sửa thêm `flutter_webrtc`, `share_plus`, `app_links`. `pubspec.lock` cũ được giữ để hạn chế thay đổi
các gói đã có; `flutter pub get` phải cập nhật phần phụ thuộc mới. Chưa xác nhận resolution/build ở đây.
Có thể có lint/deprecation từ mã gốc; gửi toàn bộ phần `error` và log build nếu lệnh báo lỗi.

Sau khi debug chạy đúng:

```powershell
flutter build apk --debug
```

APK debug thường nằm ở `build/app/outputs/flutter-apk/app-debug.apk`.
Bản Android gốc đang dùng debug signing cho release và applicationId `com.example.social_app`;
chưa phải cấu hình phát hành Play Store. iOS cần macOS/Xcode và cấu hình ký của bạn.
Không có Android SDK/device trong môi trường sửa này nên chưa build APK.

Nếu Windows báo `Could not close incremental caches` ở các task `compileDebugKotlin`,
bản này đã thêm `kotlin.incremental=false` vào `android/gradle.properties`.
Đây là cách tắt incremental compilation được Kotlin hỗ trợ; các lần build sau có thể chậm hơn.
Log hiện tại xác nhận lỗi cache nhưng chưa có đầy đủ nguyên nhân bên trong.
Sau khi cập nhật file cấu hình, dừng build đang chạy, rồi chạy tại thư mục có `pubspec.yaml`:

```powershell
Push-Location .\android
.\gradlew.bat --stop
Pop-Location
flutter clean
flutter pub get
flutter build apk --debug 2>&1 | Out-File -Encoding utf8 apk_build.txt
Get-Content .\apk_build.txt -Tail 80
```

Nếu còn lỗi, gửi toàn bộ `apk_build.txt` để đọc cả nguyên nhân trước phần cuối log.
Không xóa cache Gradle/Pub toàn máy chỉ từ đoạn lỗi này.
Để biết test nào thất bại và lỗi cụ thể, chạy riêng:

```powershell
flutter test --reporter expanded 2>&1 | Out-File -Encoding utf8 flutter_test.txt
```

Gửi `flutter_test.txt` nếu test vẫn thất bại sau cập nhật.

## 8. Những gì đã kiểm tra và phần chưa kiểm tra

- Đã phân tích cú pháp toàn bộ 48 file Dart trong lib, 1 file test và 8 file TypeScript của Edge Functions;
  kiểm tra import nội bộ, cú pháp SQL, AndroidManifest.xml và Info.plist.
  Kiểm tra cú pháp không thay thế kiểm tra kiểu Dart/Deno hoặc build ứng dụng.
- Đã chạy 32 kiểm thử tích hợp PostgreSQL cục bộ trên bản tái tạo từ schema bạn gửi: follow,
  kết bạn, chat riêng tư, quyền gọi, hạn mức upload/push, sửa bài/xóa bình luận, khóa cột xác minh,
  chặn sửa video người khác/thông báo giả/upload avatar ẩn danh, hashtag tiếng Việt và Realtime.
  Installer cũng đã được thử thành công, thử chạy lại, thử cặp hội thoại trùng và xác nhận giữ dữ liệu.
  Public columns/constraints/functions/policies/triggers được tái tạo từ export; Auth/Storage internals
  và grants được mô phỏng vì export không có phần này. Đây không phải kiểm thử trên server thật.
- Đã kiểm tra thêm 5 tình huống dọn hai bản ghi tự kết nối: sao lưu đủ, giữ dữ liệu hợp lệ,
  khóa bản sao khỏi tài khoản thường, chạy lại phải dừng, có tin nhắn mới phải hoàn tác và cài installer sau dọn.
- Có thêm Flutter tests cho đọc bài cũ/mới, đường dẫn tệp riêng tư, bài dài, giữ draft khi lỗi,
  chặn gửi lặp và tab Bạn bè trên màn hình nhỏ. Log mới bạn gửi xác nhận cả 5 test đạt
  (`00:01 +5: All tests passed!`) sau khi sửa lỗi RenderFlex ở tab trang cá nhân.
  Tab có chiều rộng tối thiểu 104 px và tự giãn theo nội dung,
  giữ màu sắc, badge, thanh gạch chân và cuộn ngang. Test vẫn kiểm tra không có lỗi layout
  và bấm Bạn bè chọn đúng tab; cuộn tới nhãn thay vì phụ thuộc một khoảng kéo cố định.
  Bản hiện tại chỉ thêm ngoặc cho nhánh xử lý lỗi tải media, không đổi logic hoặc test.
- Khởi tạo Flutter để chạy analyze/test đã bị cơ chế kiểm tra tự động chặn vì công cụ phát sinh
  request tới endpoint metadata của hạ tầng. Đã dừng thao tác đó, không thử vượt chặn.
- Log `flutter analyze` do bạn chạy trước bản dọn lint có 104 mục, gồm 0 error, 7 warning và 97 info.
  Bản dọn lint sửa các mục được báo: API deprecated, biến/import dư, const, logging, kiểm tra mounted sau async.
  Log analyzer mới xác nhận chỉ còn 1 info về ngoặc ở `media_gallery.dart`, không có error/warning.
  Bản này thêm `{}` cho nhánh `snapshot.hasError`. Kiểm tra cú pháp đã đạt;
  cần chạy lại analyzer trên máy của bạn để xác nhận không còn mục được báo.
- Android debug build trên Windows đã thành công sau khi tắt Kotlin incremental compilation,
  theo log bạn gửi kết thúc bằng `Built build\app\outputs\flutter-apk\app-debug.apk`.
  Lệnh `gradlew.bat --stop` trực tiếp báo thiếu JAVA_HOME, nhưng Flutter vẫn build được.
  Chưa build lại sau bản sửa tab trang cá nhân này.
  Chưa xác nhận iOS build, upload Cloudinary thật hay cuộc gọi hai điện thoại.
- Bạn đã chạy installer SQL và deploy đủ 6 Edge Functions theo ảnh/log gửi lại.
  Chưa trực tiếp kiểm thử chức năng trên Supabase thật hoặc kiểm tra các giá trị Secrets.

Các file media công khai đã tải lên nhưng hủy bài/lưu bài lỗi hoặc xóa bài chưa được tự dọn khỏi Cloudinary.
Ảnh/video bị bỏ khỏi bài không bị xóa ngay để tránh làm hỏng URL còn được dùng. Cần thêm job dọn asset
không còn tham chiếu theo chính sách lưu trữ trước khi vận hành nhiều người dùng.
Tệp chat lỗi lưu sẽ được thử xóa; cũng nên có lịch dọn file mồ côi và bảng ICE/cuộc gọi cũ.

Xem `docs/TEST_THIET_BI.md` để thử các luồng chính và `docs/DOI_CHIEU_BACKEND.md` để xem kết quả đối chiếu.
Bước tiếp theo là chép `lib/widgets/media_gallery.dart` từ ZIP này vào dự án đang dùng,
chạy lại analyze và build APK mới. Cả 5 test đã đạt theo log bạn gửi.
Sau khi build và test đạt, thử các luồng trên thiết bị theo `docs/TEST_THIET_BI.md`.
