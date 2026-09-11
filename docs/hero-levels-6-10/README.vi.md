# Nâng cấp hero cấp 6-10

[English](README.en.md) · [Português](README.pt.md)

Nâng trần cấp hero từ 5 lên 10. Các cấp 6-10 xen kẽ giữa năng lượng và sức mạnh, và thu
BCOIN + SEN + đồng native của chain, thay vì chỉ thu native.

> **Chỉ dùng trên testnet.** Mọi contract ở đây đều từ chối chain không phải BSC testnet (97) hoặc
> Polygon Amoy (80002). Token faucet có hàm `mint` công khai, không cần quyền.

## Các cấp mới hoạt động thế nào

Mỗi lần nâng cấp sẽ đốt một hero nguyên liệu và tăng hero gốc lên một cấp.

| Cấp | Nhận được | Tổng power | Tổng stamina |
|----:|-----------|-----------:|-------------:|
| 1-5 | (giữ nguyên như hiện tại) | 0 1 2 3 5 | 0 0 0 0 0 |
| 6   | +1 năng lượng | 5 | 1 |
| 7   | +1 sức mạnh   | 6 | 1 |
| 8   | +1 năng lượng | 6 | 2 |
| 9   | +1 sức mạnh   | 7 | 2 |
| 10  | +1 sức mạnh và +1 năng lượng | 8 | 3 |

Cả hai bảng đều lưu **tổng tích luỹ tại cấp đó**, không phải phần tăng thêm của từng lần nâng cấp.
Power lặp lại ở cấp 6 và 8 (5,5 và 6,6) vì những cấp đó tăng stamina.

Một điểm stamina tương đương 50 năng lượng (`HeroHelper.ENERGY_PER_STAMINA`), nên hero rarity 9 đi
từ 30 stamina / 1500 năng lượng ở cấp 5 lên 33 / 1650 ở cấp 10.

### Quy tắc nguyên liệu

Dưới cấp 5, hero nguyên liệu phải **cùng cấp** với hero gốc — không thay đổi. Từ cấp 5 trở đi,
nguyên liệu luôn là hero **cấp 5**, để lên tới cấp 10 không cần một chuỗi nâng cấp dài theo cấp số
nhân.

### Vì sao phần thưởng không bao giờ được ghi on-chain

`BHeroDetails` đóng gói stamina và bombPower, mỗi chỉ số **5 bit**, nên trần là 31. Hero rarity 9 đã
có sẵn 30 mỗi loại, và phần thưởng theo cấp sẽ đẩy power lên 38 và stamina lên 33.

Đây **không phải** rủi ro mới do các cấp 6-10 tạo ra — trần này đã bị vượt qua từ bây giờ, vì hero
rarity 9 ở cấp 5 đọc ra 35 power. Nó hoạt động được vì phần thưởng được **server tính lúc chạy** và
không bao giờ lưu lại. Contract chỉ thay đổi bit 45-49 (cấp); nó không bao giờ chạm vào các trường
chỉ số. Hãy giữ nguyên như vậy.

### Đốt token

25% lượng BCOIN và SEN thu được sẽ bị đốt; 75% còn lại nằm trong contract cho `WITHDRAWER_ROLE`.
Đồng native không bị đốt, và các cấp cũ (1-4) không đốt gì vì chúng không thu token.

Đích đến của phần bị đốt phụ thuộc vào `burnSink`:

- `burnSink == address(0)` (mặc định): **đốt thật** qua `burnFrom` — `totalSupply` giảm và log ghi
  nhận `Transfer` tới `0x0`.
- `burnSink != address(0)`: chuyển khoản thường tới địa chỉ đó. Cần thiết cho những token không có
  `burnFrom`, vì hàm `_transfer` của OpenZeppelin sẽ **revert** khi đích đến là địa chỉ zero — không
  có cách nào "chuyển tới 0x0".

`scripts/upgrade-bhero-upgrade-v2.js` phát hiện `burnFrom` bằng cách tìm selector `79cc6790` trong
bytecode đã deploy rồi đặt `burnSink` tương ứng. Làm sai chỗ này sẽ khiến **mọi** giao dịch nâng cấp
có thu token đều revert.

### Đồng native không bị hard-code

Contract thu `msg.value`, nên "native" là BNB trên BSC và POL trên Polygon mà không cần rẽ nhánh nào
trong code. Giá trị duy nhất phụ thuộc vào đồng tiền là `nativeRate`, đặt riêng cho từng chain trong
`NATIVE_RATE_BY_CHAIN`, được hiệu chỉnh sao cho chi phí nâng cấp quy ra USD là như nhau trên cả hai.

## Cách áp dụng

> Các lệnh bên dưới dùng `hardhat.local.config.js`, `deploy-testnet-stack.js`,
> `upgrade-tokens-to-burnable.js`, `build-server.sh` hoặc `deploy-amoy.sh` thuộc về **stack testnet
> cục bộ**, không thuộc về tính năng. Chúng nằm trong các commit `chore(testnet)` riêng. Khi triển
> khai chính thức, hãy dùng cấu hình Hardhat, contract token thật và quy trình deploy của chính dự
> án đó; chỉ các migration cơ sở dữ liệu, việc build lại extension và bước deploy/upgrade contract
> mới là một phần của tính năng.

### 1. Cơ sở dữ liệu

```bash
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120100_extend_hero_upgrade_power_to_level_10.sql
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120000_add_hero_upgrade_stamina.sql
```

Kiểm tra — cả hai phải trả về 10 dòng:

```sql
SELECT rare, datas FROM config_hero_upgrade_power   ORDER BY rare;  -- [0,1,2,3,5,5,6,6,7,8]
SELECT rare, datas FROM config_hero_upgrade_stamina ORDER BY rare;  -- [0,0,0,0,0,1,1,2,2,3]
```

Cấu hình được đọc vào bộ nhớ lúc khởi động, nên hãy **khởi động lại server sau khi** chạy migration,
không phải trước.

### 2. Extension của server

```bash
./build-server.sh
```

Hãy đặt file JAR vào đúng thư mục mà container thực sự mount. File `server/run.sh` của upstream chép
vào `server/deploy/extensions_volume` — đó là thư mục compose của upstream mount; còn stack local
mount `server/deploy/SmartFoxServer_2X`. Đặt nhầm chỗ sẽ khiến container tiếp tục chạy JAR cũ có sẵn
trong image, và triệu chứng là `Request handler not found: 'GET_HERO_UPGRADE_STAMINA_V2'`, client
treo ở bước sync tương ứng.

`build-server.sh` so sánh kích thước JAR bên trong container với bản build local và báo lỗi rõ ràng
nếu khác nhau.

### 3. Contract

```bash
cd repos/bombcrypto-contract-v2/base-hardhat
npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.js

# Deploy mới
DEPLOYER_KEY=0x... npx hardhat --config hardhat.local.config.js --network <mạng> run scripts/deploy-testnet-stack.js
DEPLOYER_KEY=0x... HERO_TOKEN=0x... HERO_DESIGN=0x... BCOIN_TOKEN=0x... SEN_TOKEN=0x... \
  npx hardhat --config hardhat.local.config.js --network <mạng> run scripts/deploy-bhero-upgrade-v2.js

# Nâng cấp một proxy đã có
DEPLOYER_KEY=0x... PROXY=0x... npx hardhat --config hardhat.local.config.js --network <mạng> run scripts/upgrade-bhero-upgrade-v2.js
```

`initialize` không chạy lại khi nâng cấp proxy, nên mọi trường mới có giá trị mặc định đều phải được
đặt thủ công — đó chính là việc script làm với `burnRateBps` và `burnSink`.

Để deploy toàn bộ stack trên Polygon Amoy: `./deploy-amoy.sh` (cần POL để trả gas).

### Đổi token test sang loại đốt được

Chỉ cần làm ở nơi token đã deploy có trước tính năng đốt:

```bash
DEPLOYER_KEY=0x... PROXY=0x... HOLDERS=0xa,0xb \
  npx hardhat --config hardhat.local.config.js --network <mạng> run scripts/upgrade-tokens-to-burnable.js
```

Script này deploy token mới, mint lại số dư cho từng ví, trỏ lại proxy và bật chế độ đốt thật.
**Địa chỉ token sẽ thay đổi**, nên sau đó cần cập nhật `addresses.ts`, `BscAddress.ts`, danh sách
token trong ví và các allowance ERC20.

### 4. Client

Trần cấp nằm ở `UpgradeHeroLevelPolygon.MaxLevel` và phải khớp với `BHeroDesign.getMaxLevel()`. Mọi
cấp đều đi qua `BHeroUpgradeV2`, kể cả 1-4 — contract tính giá các cấp đó chỉ bằng native. Đường đi
cũ đọc từ `BHeroS` bản production, thứ không tồn tại trong stack test.

## Bố cục storage

`BHeroUpgradeV2` là proxy UUPS. Hai trường được thêm vào sau `nativeRate` (`burnRateBps`,
`burnSink`) và `__gap` giảm từ 40 xuống 38 để tổng dung lượng chiếm chỗ không đổi. Hãy giữ bất biến
này trong mọi lần nâng cấp về sau.

## Danh sách file

| Phần | Đường dẫn |
|---|---|
| Contract | `base-hardhat/contracts/BHeroUpgradeV2.sol` |
| Token test | `base-hardhat/contracts/TestnetFaucetToken.sol` |
| Test | `base-hardhat/test/BHeroUpgradeV2.js` |
| Cấu hình stamina | `.../data/manager/hero/HeroUpgradeStaminaManager.kt` |
| Tổng chỉ số | `.../data/manager/hero/HeroHelper.kt` |
| Migration | `server/db/migrations/20260910_*.sql` |
| Dialog nâng cấp | `Assets/Scripts/Game/Dialog/UpgradeHeroLevelPolygon.cs` |
