# ExtractShooter prototype

Prototype gameplay 2D cho GDD, làm bằng Godot 4.7. Tóm tắt dự án: [`docs/TONG_QUAN.md`](docs/TONG_QUAN.md). Màn hình dọc 886 × 1920. Hình và âm thanh được tạo bằng code, riêng con sample dùng sprite xuất từ Figma trong `assets/alien_base`.

## Câu chuyện

Một viên thiên thạch rơi xuống Trái Đất, trong lõi đá là trứng của một loài bọ ngoài hành tinh. Vài tuần sau, bầy bọ đã phủ kín các thành phố. Bạn là lính thu hồi: băng qua khu đổ nát từ trái sang phải, gom mẫu vật rồi thoát ở bãi đáp.

Bọ được thiết kế riêng, lấy cảm hứng từ dáng bọ trong Helldivers: thân giáp thấp, bụng chia đốt, túi mật phát sáng màu cam.

| Loài | Cách đánh |
| --- | --- |
| Bọ thợ | Bầy nhỏ, đông, bò thẳng tới |
| Bọ vồ | Khom người rồi nhảy vồ theo đường cong, có thể bắn hạ trên không |
| Bọ chiến | To, trâu, phá cửa nhanh |
| Bọ mật | Túi mật phát sáng, nổ khi chạm vào bạn hoặc khi chết |
| Bọ húc (boss) | Lấy đà rồi húc dọc sàn, nhảy qua hoặc lướt xuyên để né |

## Bản test hiện tại

Bản này chỉ để thử người chơi và con sample, nên bản đồ ngẫu nhiên, bầy bọ, thùng, tiền, thẻ, đợt bọ và bãi đáp đều đang tắt. Code cũ vẫn còn: đặt `sample_build` trong `data/tuning.tres` thành tắt, hoặc chạy với `-- --oldmap`, để về bản cũ. Bản cũ hiện không có con sample, vì con này chỉ biết bò trong phòng thử.

**Người chơi:** bỏ nhảy, vừa đi vừa bắn được, bắn 3 phát mỗi giây, mỗi phát 20 sát thương. Súng tự ngắm và người luôn quay về phía mục tiêu, đi theo hướng nào cũng vậy. Lướt vẫn giữ. Dốc tự đi lên được, đạn và tầm ngắm bị địa hình chặn.

**Các loài** (đều là bọ, nên đúng 6 chi, mỗi chi tối đa 3 đốt: 4 chân và 2 chi trước, vẽ trong Figma ở board `variants_vector`, thông số ở đầu `scripts/bug.gd` và `scripts/horde.gd`):

| Loài | Chi trước | Máu | Cách đánh |
| --- | --- | --- | --- |
| Thợ | càng | 300 (150 trong màn) | Bò, leo tường, đánh gần, vồ từ trên cao |
| Nổ | càng nhỏ | 60 | Túi cam to, chỉ đi dưới sàn. Tới sát thì châm ngòi 0,7 giây, túi phồng và nháy rồi nổ, chạy kịp thì thoát. Bị bắn chết trước thì vẫn nổ nhưng chỉ làm đau đồng bọn xung quanh |
| Nhảy | lưỡi hái | 90 | Bật nhảy từ mọi bề mặt, cách 1,2 đến 2,2 giây một lần, đáp xuống là chém luôn |
| Tàng hình | lưỡi hái | 110 | Gần như vô hình, súng không tự ngắm được trừ khi ở sát. Hiện ra khi đánh và khi trúng đạn. Chém xong lùi đi rồi ẩn lại, thích đi đường trên cao |
| Boss húc | khiên | 900 | Chỉ đi dưới sàn. Ở gần thì đập khiên. Thỉnh thoảng thu 2 khiên khép kín phía trước, gồng 0,9 giây rồi lao thẳng qua chỗ người chơi, lúc này đạn bắn vào mặt trước bị bật ra, nhưng bắn từ sau vẫn trúng. Lao xong đứng hở 1,5 giây, đâm tường thì 2,4 giây. Lướt để né cú lao |

**Màn chơi sample** (`scripts/sample_level.gd`): 4 đợt, đợt cuối là boss, tổng 15 con. Mỗi con có độ điên riêng từ 0 đến 1, hiện trên đầu nó từ xanh (bình tĩnh) sang cam (điên). Trong một đợt, mỗi con rơi vào một khoảng khác nhau của 0 đến 1, nên đợt nào cũng có đủ cả hiền lẫn điên. Chúng xuất hiện ở sàn hoặc trần, cách người chơi ít nhất 380, và luôn đi săn dù người chơi ở xa. Trong màn này mỗi con 150 máu. Sang đợt mới hồi 40% máu. Hạ hết là thắng, hết máu là thua, cả hai đều có nút Chơi lại. Sửa thành phần từng đợt ở đầu file. Thanh Độ điên trong bàn thử không ảnh hưởng đến màn này.

**Phòng thử** (`scripts/arena.gd`): 3 phòng lab liền nhau, mỗi phòng rộng 546 như một phòng của bản đồ game, tổng rộng 1.638, cao 560. Giữa các phòng là vách dày 40 treo từ trần xuống tới đầu cửa, cửa cao 260 nên người chơi đi qua được, bọ thì bò vòng qua vách. Phòng 1 sàn phẳng và có gờ tường bên trái, phòng 2 và phòng 3 mỗi phòng một dốc, phòng 3 có gờ tường bên phải. Đổi địa hình bằng cách sửa danh sách điểm `OUTLINE`. Phòng vẽ kiểu 3D giả như bản đồ game (xem phần Các lớp parallax), bàn thử cũng dùng đúng phòng này.

**Con sample:** hình Bọ thợ (`vec_bug_worker` trong Figma) gắn lên xương, không có khung hình nào. 6 chi, mỗi chi 3 đốt: 4 chân đi và 2 vũ khí đỏ. 300 máu.

| Trạng thái | Việc nó làm |
| --- | --- |
| Đứng yên | Thân thở, bụng phập phồng, đầu ngó, vũ khí đung đưa, thỉnh thoảng nhấc một chân. Nhận ra người chơi trong tầm 340 thì nghỉ thêm 1 giây rồi mới đi, bị bắn thì đi ngay. Người chơi đi quá xa thì quay lại nghỉ |
| Bò | Tự chọn đi dưới sàn hay leo tường và trần, tính theo quãng đường cộng chút ngẫu nhiên, chọn lại sau 5 đến 8 giây. Quay đầu tại chỗ: bàn chân giữ nguyên chỗ đứng và được giao cho chân đối diện, rồi từng cặp bước tại chỗ. Không đi đều mà lao vọt, khựng lại run bần bật, đôi khi giật lùi rồi lại lao, chân vung cao và cắm xuống, thân nảy và chúi, vũ khí quật loạn, tóe lửa và bụi ở chân, để lại bóng mờ |
| Đánh | Trong tầm với thì khom, giơ vũ khí rồi vung, đánh được từ bất kỳ mặt nào nó đang bám |
| Vồ | Từ tường hoặc trần, nếu người chơi ở dưới và không bị che, nó bật ra theo đường cong, nhào lộn trên không, chân cào loạn, rồi đáp xuống |
| Chết | Buông tay, rơi xuống, co giật, gập chân và vũ khí lại rồi mờ dần |

**Bàn thử `scenes/rig_lab.tscn`** (mở scene rồi F6, hoặc `--path . res://scenes/rig_lab.tscn`):

- **Chọn loài:** hàng nút Thợ, Nổ, Nhảy, Tàng hình, Boss ở chế độ kéo bọ. Mỗi loài có file tư thế riêng trong thư mục của nó. **Thử chiêu** bật tắt dáng đặc biệt: khép khiên, phồng túi, tàng hình, hoặc giơ vũ khí.
- **Kéo bọ:** bấm giữ con bọ kéo đi, thân và chân tự chỉnh theo bề mặt gần nhất. Ra giữa không trung thì chân buông ra và cào loạn. Thả gần bề mặt thì bám lại, thả xa thì rơi. Phím A / D để chạy, nút **Tự chạy** để nó tự chạy quanh phòng trong lúc bạn kéo thanh trượt.
- **Độ điên:** một thanh từ 0 đến 2 cho toàn bộ độ điên của chuyển động. 0 là đi đều như trước, 1 là mặc định, 2 là hết cỡ. Trung bình nó nhanh hơn khoảng 1,3 lần so với đi đều, lúc lao tới 3,4 lần, lúc khựng thì đứng yên, đó là lúc dễ bắn nhất.
- **Dài chân:** thanh **Cả 4 chân** cho mọi chân, và 6 thanh đùi, cẳng, ống cho cặp trước và cặp sau. Chân gần và xa cùng phía luôn dài bằng nhau. Chân dài thì đứng cao hơn, chân bè rộng hơn, bước dài và chậm hơn, chân ngắn thì chạy chậm lại. Sprite kéo dọc theo xương nên vẫn giữ nguyên độ dày. Có ở cả chế độ kéo và chế độ chỉnh chi.
- **Chỉnh chi:** kéo chấm vàng (hông), trắng (vị trí gối lúc đứng, từ đó ra độ nghiêng của đốt cuối), cam (bàn chân), đỏ (khớp vũ khí). Bấm chấm xanh để đảo chiều gập. Khi chạy, đùi và đốt giữa làm phần lớn chuyển động, đốt cuối giữ độ nghiêng và chỉ xoay khi cần. Đốt cuối không bao giờ được gập ngược: cổ chân luôn gập cùng chiều với gối như trong hình vẽ, nếu không còn cách nào thì nó duỗi thẳng theo đốt giữa.
- **Cảm giác chuyển động:** ở chế độ kéo có thanh trượt cho thân, hướng xoay, đầu, bụng và vũ khí, độ điên sẽ nhân thêm lên các số này. `f` là độ nhanh, `zeta` dưới 1 thì nảy qua rồi về, từ 1 trở lên thì không nảy, `r` âm thì lùi lấy đà, dương thì phản ứng ngay, trên 1 thì vọt quá. Vị trí thật dùng để tính trúng đòn và chỗ bám vẫn không đổi, chỉ phần vẽ có quán tính (`scripts/second_order.gd`).
- **Bước chân:** thanh Khoảng cách bước, từ 0,4 đến 2,5 lần. Tốc độ di chuyển không đổi: bước dài thì thưa và cao hơn, bước ngắn thì dày và thấp hơn. Chân chỉ bước được trong tầm với, nên kéo quá thì chân ngắn sẽ không xa thêm nữa, muốn bước xa hơn thì tăng Dài chân.
- **Khung nhìn:** con lăn hoặc thanh Zoom để zoom, từ 0,5 (thấy cả phòng) đến 6, mỗi chế độ nhớ mức zoom riêng. Nút **Đi theo** bật tắt việc khung nhìn bám theo con bọ. Tắt đi rồi thì zoom quanh con trỏ, và kéo chỗ trống để di chuyển khung nhìn. Đổi chế độ hoặc bấm Đặt lại vị trí thì khung nhìn về lại con bọ.
- **Lưu:** ghi tư thế, cảm giác, độ dài chân và độ điên vào `assets/alien_base/stance.json`, game đọc file này khi chạy. Xóa file là về mặc định. Chân xa luôn dài bằng chân gần cùng phía, sprite tự kéo dọc xương cho khớp.

Sửa hình trong Figma xong, mở bridge rồi chạy `python tools/export_alien.py` (xuất tất cả) hoặc thêm tên component, ví dụ `python tools/export_alien.py vec_bug_leaper`. Nhịp bước và dáng chết sửa ở đầu `scripts/alien_rig.gd`, tầm đánh và thời gian đòn sửa ở đầu `scripts/horde.gd`.

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
| Di chuyển | A / D hoặc mũi tên trái, phải | Kéo ở phần dưới màn hình |
| Leo thang lên | Đứng sát thang, giữ W | Đứng sát thang, kéo lên |
| Xuống thang | Đứng ở nắp hầm vàng, giữ S | Đứng ở nắp hầm vàng, kéo xuống |
| Lướt | Space | Nút LƯỚT |

Súng tự ngắm khi đứng yên. Trong bản cũ, cửa tự mở, đứng gần thùng để mở, đồ tự được hút vào.

## Bản đồ

Mỗi lượt là một bản đồ ngẫu nhiên, sinh trong `scripts/level.gd` trên lưới 12 cột, 3 tầng. Phòng rộng 546 (trước là 420, tăng 30%).

1. **Đường chính:** đi từ cột đầu tới bãi đáp ở cột cuối, chỉ sang phải hoặc leo thẳng lên xuống, không bao giờ phải quay lại.
2. **Phòng phụ:** mọc ra từ các ô đã mở. Phần lớn là ngõ cụt đáng để rẽ vào, một số mở cửa về phía trước thành lối thứ hai.
3. **Sảnh dài:** hai phòng liền nhau đôi khi gộp làm một.
4. **Ô trống:** để trống cho thấy thành phố phía sau. Phòng không có gì bên dưới đứng trên cột trần.

| Loại phòng | Đặc điểm |
| --- | --- |
| Thường | 0 đến 1 thùng, 2 đến 3 con bọ |
| Kho | 2 đến 3 thùng, chỉ nằm ngoài đường chính |
| Tổ | 4 đến 6 con bọ, tường phủ tổ, thùng hiếm hơn |
| Bãi đáp | Ngoài trời, rộng 2 cột, có hầm thoát và cột gọi cứu hộ |

Càng về bên phải, thùng càng hiếm và bọ càng mạnh. Đợt bọ phần lớn tràn tới từ phía sau. Quay lại vẫn được nhưng không bắt buộc. Chỉnh lưới và tỉ lệ trong `data/tuning.tres`, nhóm `Map`.

## Các lớp parallax

Gameplay vẫn là mặt cắt ngang phẳng, không có trục độ sâu. Cảm giác xa gần đến từ bốn nhóm lớp tách riêng, mỗi nhóm là một node trong `scenes/main.tscn`. Lớp dựng từ texture vẽ ở độ phân giải thấp, nên sau này có thể thay bằng PNG mà không phải sửa phần khác.

| Nhóm | Node, script | Lớp, từ xa đến gần | `scroll` |
| --- | --- | --- | --- |
| Hậu cảnh | `Background`, `backdrop.gd` | Sky | 0 |
| | | Meteor, SkyFx | 0,03 |
| | | Far | 0,1 |
| | | Smog | 0,16 |
| | | Mid | 0,22 |
| | | Near | 0,42 |
| | | EmbersBack | 0,55 |
| | | Street | 0,68 |
| Tường | `Walls`, `wall_layer.gd` | Từng phòng dựng thành hộp 3D: tường sau, 2 tường bên, sàn, trần | 0,78 ở tường sau |
| Nền | `Floors`, `floor_layer.gd` | Ground, sàn, trụ, thang, đồ đạc, nhân vật | 1 |
| Tiền cảnh | `Foreground`, `foreground_layer.gd` | EmbersFront | 1,25 |
| | | Cột gãy, dầm, dây treo, đống gạch | 1,3 |
| | | Rubble ở mép dưới màn hình | 1,7 |

Mỗi phòng là một cái hộp bị cắt mất mặt trước (`scripts/depth.gd`). Mặt trước là mặt phẳng chơi, tường sau nằm sâu hơn nên nhỏ lại và co về giữa màn hình, giữa hai mặt là 2 tường bên, sàn và trần. Camera đi tới đâu thì các mặt này xoay theo tới đó: đứng trong phòng thì thấy cả 2 tường bên và sàn, đi gần vách nào thì vách đó hẹp lại, mặt nào quay lưng về camera thì ẩn. Tường bên có lớp gạch chạy vào sâu, chân tường và ô cửa tối nếu bên đó có cửa. Sàn kẻ ô, trần có dầm ở chỗ vách cũ bị phá, thang có lỗ xuyên sàn và trần. Mọi thứ cắt gọn trong khung phòng nên không lấn sang phòng bên. Độ sâu chỉnh bằng `scroll_walls`: là tỉ lệ tường sau so với mặt trước, càng nhỏ càng sâu, 1 là phẳng. Phòng thử dùng chung số này. Tiền cảnh dùng cách tương tự: mỗi mảnh là một `Parallax2D` ghim vào một điểm trong phòng.

Chỉnh tốc độ từng lớp trong `data/tuning.tres`, nhóm `Parallax`.

## Lệnh kiểm thử

Dùng bản `_console.exe`, thêm vào sau `--path .`. Các lệnh có chạm phải thêm `--resolution 886x1920`, vì cửa sổ nhỏ làm lệch tọa độ chạm.

```
--headless --fixed-fps 60 -- --alientest                # kiểm tra người chơi và mọi hành vi của con sample
--headless --fixed-fps 60 -- --leveltest                # chơi hết màn sample bằng bot, thêm --mortal để bot có thể chết
--resolution 886x1920 --fixed-fps 60 -- --samplerun --shots=THU_MUC   # đứng trong phòng thử, chụp màn hình
res://scenes/rig_lab.tscn --resolution 886x1920 --fixed-fps 60 -- --labtest --shots=THU_MUC   # kiểm tra bàn thử, cần cửa sổ thật, không chạy --headless
--disable-vsync -- --stress --aliens=8      # đo hiệu năng trong phòng thử
--headless --fixed-fps 60 -- --oldmap --bot          # bản cũ: bot chơi cả lượt
--headless --fixed-fps 60 -- --oldmap --bot --god    # bản cũ: bot không chết
--headless --fixed-fps 60 -- --oldmap --bot --exit   # bản cũ: bot đi đường hầm
--disable-vsync -- --oldmap --stress        # bản cũ: đo hiệu năng với 150 con bọ
--resolution 886x1920 --fixed-fps 60 -- --joytest      # test joystick, lướt và nhảy
--headless --fixed-fps 60 -- --maptest                 # sinh 500 bản đồ, kiểm tra từng cái
--headless --fixed-fps 60 -- --oldmap --parallaxtest   # bản cũ: kiểm tra từng lớp di chuyển đúng tỉ lệ
--resolution 886x1920 --fixed-fps 60 -- --oldmap --introtest    # bản cũ: kiểm tra đoạn mở đầu
```

Thêm `-- --no-intro` để bỏ qua đoạn mở đầu khi chơi thử, `-- --seed=N` để chơi lại đúng một bản đồ.

## Khác GDD

- Hầm thoát và cứu hộ đều nằm ở bãi đáp cuối bản đồ và không khóa theo thời gian: quãng đường đã là cái giá phải trả.
- Thùng mở lâu hơn theo độ hiếm (1 / 2,5 / 5 giây), và mỗi đợt bọ thêm 1 thùng mới, để ở lại lâu có lợi.
- Ba lô đầy tự đổi món có giá trị theo ô thấp nhất, chưa có màn hỏi người chơi.
- Hồi sinh và đổi thẻ đang miễn phí, chưa nối quảng cáo.
- Lướt hồi nhanh hơn (4 giây), vì góc nhìn phẳng không còn né được theo chiều sâu.

## Chưa làm

Meta (Shelter, Armory, nâng trang bị), lưu và khôi phục lượt, quảng cáo và IAP, nhiều chương, nhiều hero, bọ phun axit.
