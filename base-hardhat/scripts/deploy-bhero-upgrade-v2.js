// Deploy do BHeroUpgradeV2 — contrato de TESTE para os níveis 6-10 cobrando BCOIN + SEN + nativo.
//
// SOMENTE TESTNET. O script recusa qualquer chainId fora de 97 (BSC testnet) e 80002 (Amoy), e o
// `initialize` do contrato repete o guarda on-chain. Nunca aponte para mainnet.
//
// Uso:
//   BSC_TESTNET_RPC=... DEPLOYER_KEY=0x... \
//   npx hardhat --config hardhat.local.config.js --network bsctestnet run scripts/deploy-bhero-upgrade-v2.js
//
// A chave precisa ser DESCARTÁVEL, de testnet, e ter DEFAULT_ADMIN_ROLE no BHeroToken alvo — sem
// isso o passo 4 (conceder MINTER_ROLE e BURNER_ROLE) não passa.

const {ethers, upgrades, network} = require('hardhat');

// Endereços por rede. HERO_TOKEN e DESIGN precisam ser um deployment que VOCÊ controla:
// conceder MINTER_ROLE e BURNER_ROLE exige DEFAULT_ADMIN_ROLE no BHeroToken.
const ADDRESSES = {
  97: {
    label: 'BSC Testnet',
    heroToken: process.env.HERO_TOKEN || '',
    design: process.env.HERO_DESIGN || '',
    bcoin: process.env.BCOIN_TOKEN || '0x648a9cf8e95c73110d28e7e2329b2d0910bd36b8',
    sen: process.env.SEN_TOKEN || '0x4B5828F31550aFe15C61D7a765D9597ad4282325',
  },
  80002: {
    label: 'Polygon Amoy',
    heroToken: process.env.HERO_TOKEN || '',
    design: process.env.HERO_DESIGN || '',
    bcoin: process.env.BCOIN_TOKEN || '0xcF693b54F86c49bbBa54Ff887488Bbf84C5D05BF',
    sen: process.env.SEN_TOKEN || '0x93567522610828695F36178b180989996082404A',
  },
};

const RARITIES = 10;
const ONE = 10n ** 18n;

// Taxa nativa: 0.00013686 nativo por unidade de BCOIN. É a razão medida em produção
// (getUpgradeCost * 5 * getNativeRate / 1e18), com o fator 5 já embutido.
// Por REDE: o contrato cobra msg.value, entao o "nativo" e BNB na BSC e POL na Polygon sem
// nenhum if no codigo. A unica coisa especifica de moeda e esta taxa.
//
// A razao entre as duas sai do coins_price que o proprio servidor consome:
//   BSC     bcoin/bnb = 0.01364288 / 706.64   = 1.9307e-5
//   POLYGON bcoin/pol = 0.01302655 / 0.092685 = 0.140546
// ou seja, POL precisa de ~7279.6x mais unidades para o MESMO custo em dolar.
const NATIVE_RATE_BY_CHAIN = {
  97: 136860000000000n,        // BSC testnet  - BNB
  80002: 996275000000000000n,  // Polygon Amoy - POL (136860000000000 * 7279.6)
};

// Custos em BCOIN por [raridade][nível-1], 9 níveis (1->2 até 9->10).
// Os 4 primeiros por raridade são os valores que o design em produção já usa; os 5 novos são
// decisão de balanceamento e devem ser revisados antes de qualquer uso sério.
const BCOIN_BASE = [
  [1, 2, 4, 7],
  [2, 4, 5, 9],
  [2, 4, 5, 10],
  [3, 7, 11, 22],
  [7, 18, 40, 146],
  [9, 25, 56, 199],
  [12, 33, 74, 263],
  [16, 44, 98, 348],
  [22, 60, 133, 470],
  [30, 84, 186, 661],
];

// Distribuição do custo entre os níveis 6, 7, 8, 9 e 10. Só o formato da curva importa: os totais
// são normalizados para os alvos abaixo.
const HIGH_LEVEL_WEIGHTS = [1.5, 2.2, 3.2, 4.6, 6.5];

// ALVOS definidos pelo usuário em 10/09/2026, para a raridade 9 (Super Mystic), somando os cinco
// upgrades do nível 5 ao 10. As demais raridades escalam proporcionalmente ao último custo legado.
const TARGET_BCOIN_RARITY_9 = 25000;
const TARGET_SEN_RARITY_9 = 110000;

// Base do preço NATIVO por [raridade][nível-1]. Os 4 primeiros são os valores de produção; os 5
// novos vêm do último custo legado x HIGH_LEVEL_WEIGHTS. Matriz SEPARADA da de BCOIN de propósito:
// o usuário pediu para manter o BNB como estava, então subir BCOIN/SEN não pode arrastar o nativo.
function buildNativeBase() {
  return BCOIN_BASE.map((legacy) => {
    const last = legacy[legacy.length - 1];
    const row = legacy.map((v) => BigInt(v) * ONE);
    for (const w of HIGH_LEVEL_WEIGHTS) {
      row.push(BigInt(Math.round(last * w)) * ONE);
    }
    return row;
  });
}

// Distribui `total` entre os cinco níveis altos segundo os pesos, ajustando a última entrada para
// que a soma bata exata — arredondamento por nível derrubaria o total em algumas unidades.
function distribute(total) {
  const sum = HIGH_LEVEL_WEIGHTS.reduce((a, b) => a + b, 0);
  const parts = HIGH_LEVEL_WEIGHTS.map((w) => BigInt(Math.round((total * w) / sum)));
  const drift = BigInt(Math.round(total)) - parts.reduce((a, b) => a + b, 0n);
  parts[parts.length - 1] += drift;
  return parts;
}

// BCOIN e SEN cobrados. Zero nos níveis legados; nos altos, o alvo escalado por raridade.
function buildTokenCosts() {
  const anchor = BCOIN_BASE[9][BCOIN_BASE[9].length - 1]; // 661, raridade 9
  const bcoin = [];
  const sen = [];
  for (let r = 0; r < RARITIES; ++r) {
    const scale = BCOIN_BASE[r][BCOIN_BASE[r].length - 1] / anchor;
    const legacyZeros = BCOIN_BASE[r].map(() => 0n);
    bcoin.push([...legacyZeros, ...distribute(TARGET_BCOIN_RARITY_9 * scale).map((v) => v * ONE)]);
    sen.push([...legacyZeros, ...distribute(TARGET_SEN_RARITY_9 * scale).map((v) => v * ONE)]);
  }
  return {bcoin, sen};
}

async function main() {
  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  const config = ADDRESSES[chainId];
  if (!config) {
    throw new Error(`Rede ${chainId} (${network.name}) nao permitida. Somente 97 e 80002.`);
  }
  if (!config.heroToken || !config.design) {
    throw new Error(
      'Defina HERO_TOKEN e HERO_DESIGN. Precisam ser um deployment que voce controla: ' +
        'conceder MINTER_ROLE e BURNER_ROLE exige DEFAULT_ADMIN_ROLE no BHeroToken.',
    );
  }

  const [deployer] = await ethers.getSigners();
  console.log(`Rede      : ${config.label} (chainId ${chainId})`);
  console.log(`Deployer  : ${deployer.address}`);
  console.log(`Saldo     : ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))}`);
  console.log(`BHeroToken: ${config.heroToken}`);
  console.log(`BHeroDesign: ${config.design}`);
  console.log(`BCOIN     : ${config.bcoin}`);
  console.log(`SEN       : ${config.sen}`);

  // 1. Deploy do proxy.
  const Factory = await ethers.getContractFactory('BHeroUpgradeV2');
  const contract = await upgrades.deployProxy(
    Factory,
    [config.heroToken, config.design, config.bcoin, config.sen],
    {initializer: 'initialize'},
  );
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`\nBHeroUpgradeV2 (proxy): ${address}`);
  console.log(`Implementacao        : ${await upgrades.erc1967.getImplementationAddress(address)}`);

  // 2. Preços.
  const nativeBase = buildNativeBase();
  const {bcoin, sen} = buildTokenCosts();
  await (await contract.setUpgradeCosts(nativeBase, bcoin, sen)).wait();
  const nativeRate = NATIVE_RATE_BY_CHAIN[chainId];
  if (nativeRate === undefined) throw new Error(`Sem taxa nativa definida para a rede ${chainId}.`);
  await (await contract.setNativeRate(nativeRate)).wait();
  console.log(`\nPrecos configurados: ${bcoin.length} raridades x ${bcoin[0].length} niveis`);
  console.log(`Taxa nativa        : ${nativeRate}  (rede ${chainId})`);
  console.log(`Alvo raridade 9    : ${TARGET_BCOIN_RARITY_9} BCOIN + ${TARGET_SEN_RARITY_9} SEN (nivel 5 ao 10)`);

  // 3. Amostra, para conferência antes de usar.
  console.log('\nAmostra de precos (raridade 9):');
  console.log('  nivel  BCOIN      SEN        nativo');
  const heroS = 0n; // details sem flag de HeroS
  for (let level = 1; level <= 9; ++level) {
    const [b, s, n] = await contract.getUpgradePrice(9, level, heroS);
    console.log(
      `  ${String(level).padEnd(2)}->${String(level + 1).padEnd(3)}` +
        `${ethers.formatEther(b).padEnd(11)}${ethers.formatEther(s).padEnd(11)}${ethers.formatEther(n)}`,
    );
  }

  // 4. Papéis necessários no BHeroToken. Sem eles o upgrade reverte na hora de queimar/gravar.
  const hero = await ethers.getContractAt(
    [
      'function grantRole(bytes32,address)',
      'function hasRole(bytes32,address) view returns (bool)',
      'function MINTER_ROLE() view returns (bytes32)',
      'function BURNER_ROLE() view returns (bytes32)',
    ],
    config.heroToken,
  );
  for (const name of ['MINTER_ROLE', 'BURNER_ROLE']) {
    const role = await hero[name]();
    if (await hero.hasRole(role, address)) {
      console.log(`\n${name}: ja concedido`);
      continue;
    }
    try {
      await (await hero.grantRole(role, address)).wait();
      console.log(`\n${name}: concedido`);
    } catch (e) {
      console.log(`\n${name}: FALHOU — ${e.shortMessage || e.message}`);
      console.log(`  Conceda manualmente: BHeroToken.grantRole(${role}, ${address})`);
    }
  }

  console.log('\nProximos passos:');
  console.log(`  1. BHeroDesign.setMaxLevel(10) em ${config.design}`);
  console.log('  2. Revisar a matriz de custos antes de qualquer teste com valor');
  console.log('  3. A UI deve chamar getUpgradePriceForHero(baseId) IMEDIATAMENTE antes de assinar');
  console.log('     — o valor nativo precisa ser exato e nao ha devolucao de troco.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
