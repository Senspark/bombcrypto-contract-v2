const {expect} = require('chai');
const {ethers, upgrades} = require('hardhat');
const {withLevel, withStats, EXTRA_RARITIES} = require('../scripts/deploy-testnet-stack');

// Integração com os contratos REAIS (BHeroDesign + BHeroToken), não com mocks. Reproduz o que o
// scripts/deploy-testnet-stack.js faz na testnet, então valida o script além do contrato.
//
//   npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.integration.js

const ONE = 10n ** 18n;
const NATIVE_RATE = 136860000000000n;
const decodeLevel = (d) => (BigInt(d) >> 45n) & 31n;
const decodeStamina = (d) => (BigInt(d) >> 60n) & 31n;
const decodePower = (d) => (BigInt(d) >> 80n) & 31n;
const decodeRarity = (d) => (BigInt(d) >> 40n) & 31n;
const decodeId = (d) => BigInt(d) & ((1n << 30n) - 1n);

describe('BHeroUpgradeV2 — integração com BHeroToken e BHeroDesign reais', function () {
  this.timeout(180000);

  let owner, design, token, bcoin, sen, upgrade;

  before(async function () {
    [owner] = await ethers.getSigners();

    const Erc20 = await ethers.getContractFactory('MockERC20');
    bcoin = await Erc20.deploy('Bomber Coin', 'BCOIN');
    sen = await Erc20.deploy('Senspark', 'SEN');

    const Design = await ethers.getContractFactory('BHeroDesign');
    design = await upgrades.deployProxy(Design, [], {initializer: 'initialize'});
    for (const [rarity, s] of Object.entries(EXTRA_RARITIES)) {
      await design.setRarityStats(rarity, {
        stamina: {min: s[0], max: s[1]},
        speed: {min: s[2], max: s[3]},
        bombCount: s[4],
        bombPower: {min: s[5], max: s[6]},
        bombRange: s[7],
        ability: s[8],
      });
    }
    await design.setMaxLevel(10);

    const Token = await ethers.getContractFactory('BHeroToken');
    token = await upgrades.deployProxy(Token, [await bcoin.getAddress()], {initializer: 'initialize'});
    await token.setDesign(await design.getAddress());
    await token.setSenToken(await sen.getAddress());

    const Upgrade = await ethers.getContractFactory('BHeroUpgradeV2');
    upgrade = await upgrades.deployProxy(
      Upgrade,
      [await token.getAddress(), await design.getAddress(), await bcoin.getAddress(), await sen.getAddress()],
      {initializer: 'initialize'},
    );

    // Os dois papéis que o BHeroUpgradeV2 precisa no BHeroToken.
    await token.grantRole(await token.MINTER_ROLE(), await upgrade.getAddress());
    await token.grantRole(await token.BURNER_ROLE(), await upgrade.getAddress());

    // Preços: base do nativo em todos os níveis; BCOIN e SEN só nos 6-10, com os alvos do usuário
    // para a raridade 9 (25000 BCOIN e 110000 SEN somando o 5 -> 10).
    const weights = [1.5, 2.2, 3.2, 4.6, 6.5];
    const sum = weights.reduce((a, b) => a + b, 0);
    const distribute = (total) => {
      const parts = weights.map((w) => BigInt(Math.round((total * w) / sum)));
      parts[parts.length - 1] += BigInt(Math.round(total)) - parts.reduce((a, b) => a + b, 0n);
      return parts;
    };
    const legacy = [30, 84, 186, 661];
    const nativeRow = [...legacy.map((v) => BigInt(v) * ONE), ...weights.map((w) => BigInt(Math.round(661 * w)) * ONE)];
    const bcoinRow = [...legacy.map(() => 0n), ...distribute(25000).map((v) => v * ONE)];
    const senRow = [...legacy.map(() => 0n), ...distribute(110000).map((v) => v * ONE)];

    const nativeBase = [];
    const bcoinCosts = [];
    const senCosts = [];
    for (let r = 0; r < 10; ++r) {
      nativeBase.push(nativeRow);
      bcoinCosts.push(bcoinRow);
      senCosts.push(senRow);
    }
    await upgrade.setUpgradeCosts(nativeBase, bcoinCosts, senCosts);
    await upgrade.setNativeRate(NATIVE_RATE);

    await bcoin.mint(owner.address, 1000000n * ONE);
    await sen.mint(owner.address, 5000000n * ONE);
    await bcoin.approve(await upgrade.getAddress(), ethers.MaxUint256);
    await sen.approve(await upgrade.getAddress(), ethers.MaxUint256);

    // Cunhagem pelo fluxo real do BHeroToken: request + process.
    const target = (await ethers.provider.getBlockNumber()) + 1;
    await token.createTokenRequest(owner.address, 8, 9, target, 0);
    await token.processTokenRequests();
  });

  it('cunha pelo fluxo real do BHeroToken e prepara a fixture', async function () {
    const details = await token.getTokenDetailsByOwner(owner.address);
    expect(details.length).to.equal(8);
    for (const d of details) {
      expect(decodeLevel(d)).to.equal(1n);
    }

    // A cunhagem e gacha: a raridade sai das drop rates, nao de um parametro. Para a fixture,
    // fixamos raridade 9 com stamina e power no teto de 30 — o caso que interessa validar.
    for (const d of details) {
      const id = decodeId(d);
      const fixed = withStats(d, {rarity: 9, stamina: 30, bombPower: 30});
      await token.setTokenDetails(id, fixed);
    }
    for (const d of await token.getTokenDetailsByOwner(owner.address)) {
      expect(decodeRarity(d)).to.equal(9n);
      expect(decodeStamina(d)).to.equal(30n);
      expect(decodePower(d)).to.equal(30n);
    }
  });

  it('sobe do nível 5 ao 10 cobrando os três tokens, sem tocar nos atributos', async function () {
    const all = await token.getTokenDetailsByOwner(owner.address);
    const ids = all.map((d) => decodeId(d));

    // Preparação de teste: força nível 5 via setTokenDetails, igual ao script de deploy.
    for (const id of ids) {
      await token.setTokenDetails(id, withLevel(await token.tokenDetails(id), 5));
    }

    const baseId = ids[0];
    const before = await token.tokenDetails(baseId);
    const staminaBefore = decodeStamina(before);
    const powerBefore = decodePower(before);

    let totalBcoin = 0n;
    let totalSen = 0n;
    let totalNative = 0n;

    for (let step = 0; step < 5; ++step) {
      const materialId = ids[1 + step];
      const [b, s, n] = await upgrade.getUpgradePriceForHero(baseId);
      const bcoinBefore = await bcoin.balanceOf(owner.address);
      const senBefore = await sen.balanceOf(owner.address);

      await upgrade.upgradeHero(baseId, materialId, {value: n});

      expect(bcoinBefore - (await bcoin.balanceOf(owner.address))).to.equal(b);
      expect(senBefore - (await sen.balanceOf(owner.address))).to.equal(s);
      totalBcoin += b;
      totalSen += s;
      totalNative += n;

      // O material foi realmente queimado no ERC721 real.
      await expect(token.ownerOf(materialId)).to.be.reverted;
    }

    const after = await token.tokenDetails(baseId);
    expect(decodeLevel(after)).to.equal(10n);
    expect(decodeStamina(after)).to.equal(staminaBefore);
    expect(decodePower(after)).to.equal(powerBefore);

    // Os alvos definidos pelo usuário, verificados de ponta a ponta.
    expect(totalBcoin).to.equal(25000n * ONE);
    expect(totalSen).to.equal(110000n * ONE);
    expect(Number(ethers.formatEther(totalNative))).to.be.closeTo(1.6285, 0.001);

    expect(await ethers.provider.getBalance(await upgrade.getAddress())).to.equal(totalNative);
  });

  it('recusa passar do teto configurado no design', async function () {
    const all = await token.getTokenDetailsByOwner(owner.address);
    const baseId = decodeId(all[0]);
    expect(decodeLevel(await token.tokenDetails(baseId))).to.equal(10n);

    const materialId = decodeId(all[1]);
    await token.setTokenDetails(materialId, withLevel(await token.tokenDetails(materialId), 5));
    await expect(upgrade.upgradeHero(baseId, materialId, {value: 0})).to.be.reverted;
  });
});
