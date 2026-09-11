const {expect} = require('chai');
const {ethers, upgrades} = require('hardhat');

// Roda com: npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.js
//
// A rede local usa chainId 97 de propósito, para que o guarda `Testnet only` do initialize
// esteja ativo durante os testes em vez de contornado.

const ONE = 10n ** 18n;

// Espelha BHeroDetails.encode para os campos que importam aqui.
function encodeDetails({id, index = 1, rarity, level, stamina, bombPower}) {
  return (
    BigInt(id) |
    (BigInt(index) << 30n) |
    (BigInt(rarity) << 40n) |
    (BigInt(level) << 45n) |
    (BigInt(stamina) << 60n) |
    (BigInt(bombPower) << 80n)
  );
}

const decodeLevel = (d) => (BigInt(d) >> 45n) & 31n;
const decodeStamina = (d) => (BigInt(d) >> 60n) & 31n;
const decodePower = (d) => (BigInt(d) >> 80n) & 31n;

describe('BHeroUpgradeV2', function () {
  const RARITIES = 10;
  const LEVELS = 9; // níveis 1->2 até 9->10
  const NATIVE_RATE = 136860000000000n; // 0.00013686 nativo por BCOIN, igual à razão de produção

  let owner, player, other;
  let hero, design, bcoin, sen, upgrade;

  // Três matrizes independentes: a base do nativo existe em todos os níveis; BCOIN e SEN só nos 6-10.
  function buildCosts() {
    const nativeCosts = [];
    const bcoinCosts = [];
    const senCosts = [];
    for (let r = 0; r < RARITIES; ++r) {
      const n = [];
      const b = [];
      const s = [];
      for (let l = 0; l < LEVELS; ++l) {
        n.push(BigInt(r + 1) * BigInt(l + 1) * ONE);
        b.push(l >= 4 ? BigInt(r + 1) * BigInt(l + 1) * 10n * ONE : 0n);
        s.push(l >= 4 ? BigInt(r + 1) * BigInt(l + 1) * 44n * ONE : 0n);
      }
      nativeCosts.push(n);
      bcoinCosts.push(b);
      senCosts.push(s);
    }
    return {nativeCosts, bcoinCosts, senCosts};
  }

  async function mint(to, params) {
    const details = encodeDetails(params);
    await hero.mintTo(to.address, params.id, details);
    return details;
  }

  beforeEach(async function () {
    [owner, player, other] = await ethers.getSigners();

    const Erc20 = await ethers.getContractFactory('MockERC20');
    bcoin = await Erc20.deploy('Bomber Coin', 'BCOIN');
    sen = await Erc20.deploy('Senspark', 'SEN');

    const Hero = await ethers.getContractFactory('MockBHeroToken');
    hero = await Hero.deploy();

    const Design = await ethers.getContractFactory('MockBHeroDesign');
    design = await Design.deploy(10);

    const Upgrade = await ethers.getContractFactory('BHeroUpgradeV2');
    upgrade = await upgrades.deployProxy(
      Upgrade,
      [await hero.getAddress(), await design.getAddress(), await bcoin.getAddress(), await sen.getAddress()],
      {initializer: 'initialize'},
    );

    const {nativeCosts, bcoinCosts, senCosts} = buildCosts();
    await upgrade.setUpgradeCosts(nativeCosts, bcoinCosts, senCosts);
    await upgrade.setNativeRate(NATIVE_RATE);

    await bcoin.mint(player.address, 100000n * ONE);
    await sen.mint(player.address, 100000n * ONE);
    await bcoin.connect(player).approve(await upgrade.getAddress(), ethers.MaxUint256);
    await sen.connect(player).approve(await upgrade.getAddress(), ethers.MaxUint256);
  });

  describe('regra de material', function () {
    it('exige mesmo nível abaixo do nível 5', async function () {
      expect(await upgrade.requiredMaterialLevel(1)).to.equal(1);
      expect(await upgrade.requiredMaterialLevel(4)).to.equal(4);
    });

    it('exige nível 5 do nível 5 em diante', async function () {
      for (const base of [5, 6, 7, 8, 9]) {
        expect(await upgrade.requiredMaterialLevel(base)).to.equal(5);
      }
    });

    it('recusa material de nível errado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 6, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 6, stamina: 30, bombPower: 30});
      const [b, s, n] = await upgrade.getUpgradePriceForHero(1);
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: n}))
        .to.be.revertedWith('Wrong material level');
      expect(b + s).to.be.greaterThan(0n);
    });
  });

  describe('preço', function () {
    it('níveis legados cobram só nativo', async function () {
      await mint(player, {id: 1, rarity: 3, level: 2, stamina: 10, bombPower: 10});
      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      expect(bcoinCost).to.equal(0n);
      expect(senCost).to.equal(0n);
      expect(nativeCost).to.be.greaterThan(0n);
    });

    it('níveis 6-10 cobram os três tokens', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      expect(bcoinCost).to.be.greaterThan(0n);
      expect(senCost).to.be.greaterThan(0n);
      expect(nativeCost).to.be.greaterThan(0n);
    });

    it('nativo vem da matriz propria, independente do BCOIN cobrado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      const [bcoinCost, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      const [nativeMatrix] = await upgrade.getUpgradeCosts();
      expect(nativeCost).to.equal((nativeMatrix[9][4] * NATIVE_RATE) / ONE);
      // O BCOIN cobrado e 10x a base do nativo nesta fixture: se o nativo fosse derivado dele,
      // este teste falharia. E a garantia de que subir BCOIN/SEN nao mexe no BNB.
      expect(nativeCost).to.not.equal((bcoinCost * NATIVE_RATE) / ONE);
    });

    it('subir BCOIN e SEN nao altera o preco nativo', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      const [, , nativeBefore] = await upgrade.getUpgradePriceForHero(1);
      const {nativeCosts, bcoinCosts, senCosts} = buildCosts();
      const dobrado = bcoinCosts.map((row) => row.map((v) => v * 2n));
      await upgrade.setUpgradeCosts(nativeCosts, dobrado, senCosts);
      const [bcoinAfter, , nativeAfter] = await upgrade.getUpgradePriceForHero(1);
      expect(nativeAfter).to.equal(nativeBefore);
      expect(bcoinAfter).to.be.greaterThan(0n);
    });

    it('reverte em nível não configurado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 10, stamina: 30, bombPower: 30});
      await expect(upgrade.getUpgradePriceForHero(1)).to.be.revertedWith('Level not configured');
    });
  });

  describe('upgrade', function () {
    it('sobe o nível, queima o material e cobra os três tokens', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 28, bombPower: 27});

      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      const bcoinBefore = await bcoin.balanceOf(player.address);
      const senBefore = await sen.balanceOf(player.address);

      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.emit(upgrade, 'HeroUpgraded')
        .withArgs(player.address, 1, 2, 5, 6, bcoinCost, senCost, nativeCost);

      expect(decodeLevel(await hero.tokenDetails(1))).to.equal(6n);
      expect(await hero.exists(2)).to.equal(false);
      expect(bcoinBefore - (await bcoin.balanceOf(player.address))).to.equal(bcoinCost);
      expect(senBefore - (await sen.balanceOf(player.address))).to.equal(senCost);
      expect(await ethers.provider.getBalance(await upgrade.getAddress())).to.equal(nativeCost);
    });

    it('NÃO altera stamina nem bombPower no details', async function () {
      // O ponto crítico: raridade 9 no nível 10 teria 33 de stamina e 38 de power somando os bônus,
      // e nenhum dos dois cabe em 5 bits. O bônus vive no servidor; o details guarda só a base.
      const stamina = 30;
      const bombPower = 30;
      await mint(player, {id: 1, rarity: 9, level: 5, stamina, bombPower});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});

      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost});

      const after = await hero.tokenDetails(1);
      expect(decodeStamina(after)).to.equal(BigInt(stamina));
      expect(decodePower(after)).to.equal(BigInt(bombPower));
      expect(decodeLevel(after)).to.equal(6n);
    });

    it('sobe do 5 até o 10 sempre com material nível 5', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      for (let step = 0; step < 5; ++step) {
        const materialId = 100 + step;
        await mint(player, {id: materialId, rarity: 9, level: 5, stamina: 27, bombPower: 27});
        const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
        await upgrade.connect(player).upgradeHero(1, materialId, {value: nativeCost});
      }
      expect(decodeLevel(await hero.tokenDetails(1))).to.equal(10n);
      expect(decodeStamina(await hero.tokenDetails(1))).to.equal(30n);
      expect(decodePower(await hero.tokenDetails(1))).to.equal(30n);
    });

    it('recusa acima do teto do design', async function () {
      await design.setMaxLevel(6);
      await mint(player, {id: 1, rarity: 9, level: 6, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.be.revertedWith('Max level');
    });

    it('exige valor nativo exato', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost - 1n}))
        .to.be.revertedWith('Wrong native amount');
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost + 1n}))
        .to.be.revertedWith('Wrong native amount');
    });

    it('recusa herói de outro dono', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(other, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.be.revertedWith('Material not owned');
    });

    it('recusa base igual ao material', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await expect(upgrade.connect(player).upgradeHero(1, 1, {value: 0}))
        .to.be.revertedWith('Same token');
    });

    it('recusa quando pausado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await upgrade.pause();
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.be.revertedWith('Pausable: paused');
    });
  });

  describe('configuração e permissão', function () {
    it('recusa matrizes de formatos diferentes', async function () {
      await expect(upgrade.setUpgradeCosts([[1n]], [[1n]], [[1n], [2n]]))
        .to.be.revertedWith('Length mismatch');
      await expect(upgrade.setUpgradeCosts([[1n, 2n]], [[1n]], [[1n]]))
        .to.be.revertedWith('Row length mismatch');
      await expect(upgrade.setUpgradeCosts([[1n, 2n]], [[1n, 2n]], [[1n]]))
        .to.be.revertedWith('Row length mismatch');
      await expect(upgrade.setUpgradeCosts([[1n, 2n]], [[1n]], [[1n]]))
        .to.be.revertedWith('Row length mismatch');
    });

    it('só DESIGNER_ROLE muda preços', async function () {
      await expect(upgrade.connect(player).setNativeRate(1n)).to.be.reverted;
    });

    it('só WITHDRAWER_ROLE retira', async function () {
      await expect(upgrade.connect(player).withdrawNative(player.address, 0n)).to.be.reverted;
    });

    it('retira o nativo acumulado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 27, bombPower: 27});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost});

      const before = await ethers.provider.getBalance(other.address);
      await upgrade.withdrawNative(other.address, nativeCost);
      expect((await ethers.provider.getBalance(other.address)) - before).to.equal(nativeCost);
      expect(await ethers.provider.getBalance(await upgrade.getAddress())).to.equal(0n);
    });
  });

  describe('queima de 25%', function () {

    it('queima 25% de BCOIN e SEN de verdade e guarda o resto', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 28, bombPower: 27});

      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      const bcoinSupplyBefore = await bcoin.totalSupply();
      const senSupplyBefore = await sen.totalSupply();
      const addr = await upgrade.getAddress();

      const bcoinBurn = (bcoinCost * 2500n) / 10000n;
      const senBurn = (senCost * 2500n) / 10000n;

      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.emit(upgrade, 'TokensBurned')
        .withArgs(player.address, 1, bcoinBurn, senBurn);

      // Queima real: o totalSupply cai exatamente o queimado.
      expect(bcoinSupplyBefore - (await bcoin.totalSupply())).to.equal(bcoinBurn);
      expect(senSupplyBefore - (await sen.totalSupply())).to.equal(senBurn);
      // O que sobra é exatamente o cobrado menos o queimado — nada some no caminho.
      expect(await bcoin.balanceOf(addr)).to.equal(bcoinCost - bcoinBurn);
      expect(await sen.balanceOf(addr)).to.equal(senCost - senBurn);
    });

    it('o jogador continua pagando o preço cheio', async function () {
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 28, bombPower: 27});

      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      const bcoinBefore = await bcoin.balanceOf(player.address);
      const senBefore = await sen.balanceOf(player.address);

      await upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost});

      expect(bcoinBefore - (await bcoin.balanceOf(player.address))).to.equal(bcoinCost);
      expect(senBefore - (await sen.balanceOf(player.address))).to.equal(senCost);
    });

    it('não queima nada nos níveis legados, onde só o nativo é cobrado', async function () {
      await mint(player, {id: 1, rarity: 9, level: 2, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 2, stamina: 28, bombPower: 27});

      const before = await bcoin.totalSupply();
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost}))
        .to.not.emit(upgrade, 'TokensBurned');
      expect(await bcoin.totalSupply()).to.equal(before);
    });

    it('a taxa é ajustável e limitada a 100%', async function () {
      expect(await upgrade.burnRateBps()).to.equal(2500n);

      await upgrade.setBurnRateBps(5000);
      expect(await upgrade.burnRateBps()).to.equal(5000n);

      await expect(upgrade.setBurnRateBps(10001)).to.be.revertedWith('Burn rate too high');
      await expect(upgrade.connect(player).setBurnRateBps(0)).to.be.reverted;
    });

    it('taxa zero devolve o comportamento antigo: tudo fica no contrato', async function () {
      await upgrade.setBurnRateBps(0);
      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 28, bombPower: 27});

      const [bcoinCost, senCost, nativeCost] = await upgrade.getUpgradePriceForHero(1);
      await upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost});

      expect(await bcoin.balanceOf(await upgrade.getAddress())).to.equal(bcoinCost);
      expect(await sen.balanceOf(await upgrade.getAddress())).to.equal(senCost);
    });
  });


  describe('limites de seguranca', function () {
    it('recusa passar do teto absoluto mesmo se o design permitir mais', async function () {
      // BHeroDetails.increaseLevel escreve (level+1) no bit 45 sem mascarar 5 bits: com level 31 o
      // valor 32 invade o campo color. O contrato nao pode depender so do design para isso.
      await design.setMaxLevel(31);
      expect(await upgrade.ABSOLUTE_MAX_LEVEL()).to.equal(10n);

      await mint(player, {id: 1, rarity: 9, level: 10, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 30, bombPower: 30});

      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: 0}))
        .to.be.revertedWith('Above hard cap');
    });

    it('token sem burnFrom exige burnSink configurado', async function () {
      const Plain = await ethers.getContractFactory('MockPlainERC20');
      const plain = await Plain.deploy('Plain', 'PLN');
      await plain.mint(player.address, ethers.parseEther('10000000'));
      await plain.connect(player).approve(await upgrade.getAddress(), ethers.MaxUint256);
      await upgrade.setTokens(await plain.getAddress(), await sen.getAddress());

      await mint(player, {id: 1, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      await mint(player, {id: 2, rarity: 9, level: 5, stamina: 30, bombPower: 30});
      const [, , nativeCost] = await upgrade.getUpgradePriceForHero(1);

      // Sem sink, burnFrom nao existe no token e a transacao inteira reverte.
      await expect(upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost})).to.be.reverted;

      const sink = await upgrade.FALLBACK_BURN_SINK();
      await upgrade.setBurnSink(sink);
      const antes = await plain.balanceOf(sink);
      await upgrade.connect(player).upgradeHero(1, 2, {value: nativeCost});
      expect(await plain.balanceOf(sink)).to.be.greaterThan(antes);
    });
  });

});
