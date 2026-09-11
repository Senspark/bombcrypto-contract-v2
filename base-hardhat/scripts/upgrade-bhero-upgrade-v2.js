// Sobe uma nova implementacao do BHeroUpgradeV2 no proxy que ja existe. SOMENTE TESTNET.
//
// `initialize` nao roda de novo num upgrade de proxy, entao qualquer campo novo com valor padrao
// precisa ser ajustado aqui. Hoje isso e o burnRateBps.
//
// Uso:
//   DEPLOYER_KEY=0x... PROXY=0x... \
//   npx hardhat --config hardhat.local.config.js --network bsctestnet run scripts/upgrade-bhero-upgrade-v2.js

const {ethers, upgrades} = require('hardhat');

const BURN_RATE_BPS = Number(process.env.BURN_RATE_BPS || 2500);

async function main() {
  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  if (chainId !== 97 && chainId !== 80002) throw new Error(`Rede ${chainId} nao permitida.`);

  const proxy = process.env.PROXY;
  if (!proxy || !ethers.isAddress(proxy)) throw new Error('Defina PROXY com o endereco do proxy.');

  const [signer] = await ethers.getSigners();
  console.log(`Carteira: ${signer.address}`);
  console.log(`Proxy   : ${proxy}`);

  const antes = await upgrades.erc1967.getImplementationAddress(proxy);
  console.log(`Impl antiga: ${antes}`);

  const Factory = await ethers.getContractFactory('BHeroUpgradeV2');
  const contract = await upgrades.upgradeProxy(proxy, Factory);
  await contract.waitForDeployment();
  // waitForDeployment cobre o deploy da implementacao, nao a tx de upgradeTo no proxy. Sem esperar
  // o slot EIP-1967 mudar, a leitura abaixo devolve a implementacao antiga.
  for (let i = 0; i < 30 && (await upgrades.erc1967.getImplementationAddress(proxy)) === antes; ++i) {
    await new Promise((r) => setTimeout(r, 2000));
  }

  const depois = await upgrades.erc1967.getImplementationAddress(proxy);
  console.log(`Impl nova  : ${depois}`);

  // burnRateBps nasce zerado num proxy que ja existia, porque initialize nao roda de novo.
  const atual = await contract.burnRateBps();
  if (atual !== BigInt(BURN_RATE_BPS)) {
    await (await contract.setBurnRateBps(BURN_RATE_BPS)).wait();
    console.log(`burnRateBps: ${atual} -> ${await contract.burnRateBps()}`);
  } else {
    console.log(`burnRateBps ja em ${atual}`);
  }

  // burnSink zerado significa queima real via burnFrom. Token sem burnFrom faria TODO upgrade com
  // custo em token reverter, entao o sink so pode ficar zerado se os dois tokens suportarem.
  //
  // A deteccao le o SELECTOR no bytecode em vez de tentar uma chamada: um staticCall em funcao
  // inexistente reverte com mensagem que varia por RPC, e tratar isso por texto ja deu falso
  // positivo — o script chegou a declarar burnFrom presente em ERC20 puro.
  const BURN_FROM_SELECTOR = '79cc6790'; // burnFrom(address,uint256)
  const burnable = [];
  for (const [nome, addr] of [['BCOIN', await contract.bcoinToken()], ['SEN', await contract.senToken()]]) {
    const code = await ethers.provider.getCode(addr);
    const ok = code.includes(BURN_FROM_SELECTOR);
    console.log(`  ${nome} (${addr}): burnFrom ${ok ? 'presente' : 'AUSENTE'}`);
    burnable.push(ok);
  }

  const querido = burnable.every(Boolean) ? ethers.ZeroAddress : await contract.FALLBACK_BURN_SINK();
  if ((await contract.burnSink()).toLowerCase() !== querido.toLowerCase()) {
    await (await contract.setBurnSink(querido)).wait();
  }
  // O RPC publico da testnet serve leitura de um no que pode estar atras do que acabou de ser
  // minerado, entao a releitura logo apos o wait() ja devolveu o valor ANTIGO mais de uma vez.
  let sink = await contract.burnSink();
  for (let i = 0; i < 15 && sink.toLowerCase() !== querido.toLowerCase(); ++i) {
    await new Promise((r) => setTimeout(r, 2000));
    sink = await contract.burnSink();
  }
  if (sink.toLowerCase() !== querido.toLowerCase()) {
    throw new Error(`burnSink ficou ${sink}, esperado ${querido}`);
  }
  console.log(`burnSink: ${sink}${sink === ethers.ZeroAddress ? '  (queima real via burnFrom)' : '  (fallback por transferencia)'}`);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
