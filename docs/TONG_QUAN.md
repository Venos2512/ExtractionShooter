# ExtractShooter: tóm tắt dự án

Cập nhật ngày 02/11/2026. Chi tiết luật chơi, thông số và lệnh test nằm trong `README.md`. File này chỉ tóm tắt dự án là gì, đang ở đâu và code nằm chỗ nào.

## Dự án là gì

Prototype game bắn súng thu hồi (extraction shooter) màn hình dọc 886 × 1920, góc nhìn ngang, làm bằng Godot 4.7. Người chơi là lính thu hồi băng qua thành phố bị bầy bọ ngoài hành tinh chiếm, từ trái sang phải, gom đồ rồi thoát ở bãi đáp. Súng tự ngắm, điều khiển một tay bằng joystick nổi và nút lướt.

Hình bản đồ, nhân vật và âm thanh được tạo bằng code lúc chạy. Riêng bọ ngoài hành tinh (bản sample) là hình vector vẽ trong Figma, xuất ra atlas và gắn lên bộ xương chuyển động bằng thủ tục, không có khung hình nào.

## Hai bản đang có

Bản nào chạy là do `sample_build` trong `data/tuning.tres` quyết định. Bật là bản sample, tắt hoặc chạy với `-- --oldmap` là bản cũ.

| | Bản sample (đang làm chính) | Bản cũ |
| --- | --- | --- |
| Bản đồ | Phòng thử cố định: 3 phòng lab liền nhau, mỗi phòng rộng 546, cao 560, ngăn bằng vách treo có cửa | Bản đồ ngẫu nhiên mỗi lượt, lưới 12 cột × 3 tầng, phòng 546 × 230 |
| Kẻ địch | Bọ sample gắn xương: Thợ, Nổ, Nhảy, Tàng hình, Boss húc | Bầy tới 150 con bọ pixel |
| Luật chơi | 4 đợt bọ, hạ hết là thắng | Thùng đồ, tiền, thẻ nâng cấp, đợt bọ theo thời gian, 2 đường thoát |
| Màn chơi | `scripts/sample_level.gd` | `scripts/level.gd`, `scripts/game.gd` |

Cả hai bản dùng chung người chơi, súng, HUD và cách vẽ phòng 3D giả.

## Hình ảnh và chiều sâu

- Gameplay là mặt cắt phẳng, không có trục độ sâu.
- Chiều sâu chỉ có trên hình:
  - **Hậu cảnh:** các lớp `Parallax2D` vẽ thành phố, khói, sao băng.
  - **Phòng:** mỗi phòng là một hộp 3D giả bị cắt mất mặt trước (`scripts/depth.gd`). Tường sau nằm sâu và nhỏ lại về giữa màn hình. Hai tường bên, sàn và trần nối vào tường sau và xoay theo camera.
  - **Tiền cảnh:** các mảng tối trượt qua nhanh hơn mặt phẳng chơi.
- Độ sâu của phòng chỉnh bằng `scroll_walls` trong tuning (0,78; 1 là phẳng).
- Phong cách hình:
  - Bản cũ là pixel art.
  - Bọ sample là vector phẳng kiểu casual: chân dài như nhện, mỗi chi tối đa 3 đốt, mỗi con đúng 6 chi (4 chân và 2 chi trước), vũ khí màu đỏ.
  - Nền có độ tương phản thấp nhất, chỉ người chơi, tường và bọ được nổi bật.

## Bọ sample và bàn thử

- **Xương và dáng đi** (`scripts/alien_rig.gd`):
  - Bọ bò vòng sát trong đường viền phòng thử: sàn, tường, trần, vách.
  - Chân đặt và bước theo thủ tục.
  - Chuyển động lố có chủ ý: lao vọt, khựng, run, quật vũ khí.
  - Độ mạnh của chuyển động chỉnh bằng một núm "độ điên" từ 0 đến 2.
  - Luật bắt buộc: ống chân không bao giờ gập ngược.
- **Hành vi và chiêu đánh từng loài:** `scripts/horde.gd`.
- **Bàn thử** `scenes/rig_lab.tscn`:
  - Kéo bọ quanh phòng để xem nó bám bề mặt ra sao.
  - Chỉnh vị trí chi, độ dài chân, cảm giác chuyển động và bước chân.
  - Bấm Lưu để ghi vào `assets/<loài>/stance.json`, game đọc file này khi chạy.
- **Xuất hình từ Figma:** chạy `python tools/export_alien.py` khi Figma đang mở cùng plugin bridge. Lệnh này ghi `atlas.png`, `atlas_flash.png` và `rig.json` vào `assets/`.

## Cấu trúc thư mục

| Đường dẫn | Nội dung |
| --- | --- |
| `project.godot` | Cấu hình, scene chính là `scenes/main.tscn` |
| `scenes/main.tscn` | Game: hậu cảnh, tường, nền, phòng thử, nhân vật, hiệu ứng, tiền cảnh, camera, HUD |
| `scenes/rig_lab.tscn` | Bàn thử bọ |
| `data/tuning.tres` | Mọi thông số cân bằng và cảm giác, sửa được trong Inspector |
| `assets/alien_*` | Atlas, xương và tư thế của từng loài bọ |
| `tools/export_alien.py` | Xuất bọ từ Figma |
| `docs/` | Tài liệu |

Các script trong `scripts/`:

| Nhóm | Script |
| --- | --- |
| Luồng game | `game.gd` (lượt chơi, đợt bọ, đồ, thoát, tính điểm), `sample_level.gd`, `tuning.gd` |
| Bản đồ | `level.gd` (bản đồ ngẫu nhiên), `arena.gd` (phòng thử), `view.gd` (đổi tọa độ chơi sang thế giới) |
| Nhân vật | `player.gd`, `weapons.gd` (súng, lựu đạn, drone, laser), `cards.gd` (thẻ nâng cấp) |
| Bọ | `bug.gd` (dữ liệu), `horde.gd` (hành vi cả bầy), `alien_rig.gd`, `alien_art.gd`, `second_order.gd` (quán tính cho chuyển động) |
| Vẽ | `depth.gd` (phòng 3D giả), `wall_layer.gd`, `floor_layer.gd`, `arena_view.gd`, `backdrop.gd`, `sky_fx.gd`, `foreground_layer.gd`, `world_view.gd`, `alien_view.gd`, `fx_view.gd`, `sprites.gd`, `paint.gd` |
| Giao diện, âm thanh | `hud.gd`, `effects.gd`, `sfx.gd` |
| Công cụ dev | `rig_lab.gd`, `rig_lab_test.gd`, `debug_bot.gd` (bot chơi thử và các bài test) |

## Chạy và kiểm thử

Mở `project.godot` trong Godot 4.7 rồi nhấn F5. Sau khi clone, phải mở editor một lần hoặc chạy `--path . --headless --import` để Godot tạo thư mục `.godot/`.

Các bài test chạy bằng tham số dòng lệnh trên bản `_console.exe`, danh sách đầy đủ nằm trong `README.md`. Các bài chính:

| Lệnh | Kiểm tra | Cần bản nào |
| --- | --- | --- |
| `--alientest` | Người chơi và mọi hành vi của bọ sample | sample |
| `--leveltest` | Bot chơi hết màn sample | sample |
| `res://scenes/rig_lab.tscn --resolution 886x1920 -- --labtest` | Bàn thử qua thao tác chuột thật | không phụ thuộc |
| `--oldmap --parallaxtest` | Từng lớp parallax và tường phòng di chuyển đúng tỉ lệ | cũ |
| `--oldmap --bot` | Bot chơi cả một lượt | cũ |
| `--maptest` | Sinh 500 bản đồ và kiểm tra từng cái | cũ |

Lưu ý:
- Bài test bàn thử phải có `--resolution 886x1920`, cửa sổ nhỏ làm lệch tọa độ chuột.
- Trong `--alientest`, hai bước kiểm tra chân bọ bắt chéo nhau khi chạy thẳng lúc qua lúc hỏng, trên cả phòng cũ lẫn phòng mới.

## Chưa làm

- Phần meta: Shelter, Armory, nâng trang bị.
- Lưu và khôi phục lượt chơi.
- Quảng cáo và mua trong ứng dụng.
- Nhiều chương, nhiều hero, bọ phun axit.
- Đưa bọ sample vào bản đồ ngẫu nhiên: hiện nó chỉ biết bò trong phòng thử.
