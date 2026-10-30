# ExtractShooter prototype

Prototype gameplay 2.5D cho GDD, làm bằng Godot 4.7. Toàn bộ hình và âm thanh được tạo bằng code, không cần asset ngoài.

## Chạy game

Mở `project.godot` trong Godot rồi nhấn F5, hoặc:

```
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path D:\ExtractShooter
```

Sau khi clone, thư mục `.godot/` chưa có nên game báo lỗi `Could not find type`. Mở project trong editor một lần, hoặc chạy lệnh này một lần bằng bản `_console.exe`:

```
--path . --headless --import
```

| Thao tác | Bàn phím | Chuột hoặc cảm ứng |
| --- | --- | --- |
| Di chuyển | WASD hoặc phím mũi tên | Kéo ở phần dưới màn hình |
| Đi vào sâu trong phòng | W / S | Kéo lên / xuống |
| Leo thang lên | Đứng sát thang, giữ W | Đứng sát thang, kéo lên |
| Xuống thang | Đứng trên nắp hầm vàng, giữ S | Đứng trên nắp hầm vàng, kéo xuống |
| Lướt | Space | Nút LƯỚT |

Súng tự ngắm, cửa tự mở, đứng gần thùng để mở, đồ tự được hút vào.

## Fake 3D nằm ở đâu

- `scripts/view.gd`: phép chiếu từ (x, độ cao, độ sâu) sang 2D. Camera di chuyển thì góc nhìn đổi theo.
- `scripts/world_view.gd`: vẽ theo thứ tự từ xa đến gần, gồm phòng, khối đồ đạc, bóng đổ và các lớp nền, tiền cảnh.
- Nhân vật và zombie thật sự đi vào sâu trong phòng, nên độ sâu ảnh hưởng đến việc né và ngắm.

Chỉnh độ sâu trong `data/tuning.tres`: `focal`, `eye_h`, `depth`.

## Lệnh kiểm thử

Dùng bản `_console.exe`, thêm vào sau `--path .`:

```
--headless --fixed-fps 60 -- --bot          # bot chơi cả lượt
--headless --fixed-fps 60 -- --bot --god    # bot không chết
--headless --fixed-fps 60 -- --bot --exit   # bot đi đường hầm
--disable-vsync -- --stress                 # đo hiệu năng với 150 zombie
--fixed-fps 60 -- --joytest                 # test joystick và nút lướt
--fixed-fps 60 --disable-vsync -- --bot --god --shots=THU_MUC   # chụp màn hình
```

## Khác GDD

- Cứu hộ mở từ phút thứ 3; GDD ghi bất cứ lúc nào. Nếu không, bot thoát được sau khoảng 1 phút.
- Thùng mở lâu hơn theo độ hiếm (1 / 2,5 / 5 giây), và mỗi đợt zombie thêm 1 thùng mới, để ở lại lâu có lợi.
- Ba lô đầy tự đổi món có giá trị theo ô thấp nhất, chưa có màn hỏi người chơi.
- Hồi sinh và đổi thẻ đang miễn phí, chưa nối quảng cáo.

## Chưa làm

Meta (Shelter, Armory, nâng trang bị), lưu và khôi phục lượt, quảng cáo và IAP, ghép bố cục từ module phòng, nhiều chương, nhiều hero, zombie acid.
