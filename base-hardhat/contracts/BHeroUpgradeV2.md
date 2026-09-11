# BHeroUpgradeV2 — contrato de teste para os níveis 6 a 10

Contrato de **teste**, escrito em 10/09/2026. Cobra **BCOIN + SEN + token nativo** nos níveis 6 a 10.

Existe porque a Senspark publicou a ABI do `BHeroS` mas **não o fonte Solidity**, e o `upgradeHero`
implantado cobra **somente token nativo**. Não dá para estender o que não se tem.

## Por que um contrato separado, e não um fork do BHeroS

O `BHeroToken` já expõe tudo que um contrato externo precisa:

| Função | Papel exigido | Uso aqui |
|---|---|---|
| `tokenDetails(id)` | — | ler nível e raridade |
| `ownerOf(id)` | — | validar posse |
| `setTokenDetails(id, details)` | `MINTER_ROLE` | gravar o nível novo |
| `burn(uint256[])` | `BURNER_ROLE` | queimar o material |
| `getHeroCostByDetails(details, cost)` | — | multiplicador 5x de HeroS |

Então o `BHeroUpgradeV2` opera **por fora**, sem tocar no `BHeroToken` nem no `BHeroS`. Testa a
mecânica inteira sem redeploy do token e sem depender do fonte que a Senspark mantém fechado.

## Regras implementadas

### Material

```
requiredMaterialLevel(baseLevel) = baseLevel < 5 ? baseLevel : 5
```

- **Níveis 2 a 5:** material do mesmo nível do base. Idêntico ao comportamento atual.
- **Níveis 6 a 10:** material sempre nível 5.

A regra "mesmo nível" dobra o custo em heróis a cada degrau: chegar ao nível 10 exigiria **512
heróis base**. Com material fixo no nível 5 são **96**, e o balanceamento migra para os três tokens,
que são ajustáveis por setter sem redeploy.

### Pagamento

| Níveis | BCOIN | SEN | Nativo |
|---|---|---|---|
| 2 a 5 | — | — | sim |
| 6 a 10 | sim | sim | sim |

Os níveis legados continuam cobrando só nativo, para não alterar o que já está em produção.

**Três matrizes independentes.** O preço nativo sai de uma matriz própria (`nativeBase`), não do
BCOIN cobrado:

```
nativo = nativeBase[raridade][nivel-1] * nativeRate / 1e18
```

A separação é deliberada. Os custos em BCOIN e SEN dos níveis 6-10 foram calibrados bem acima da
curva legada; se o nativo derivasse deles, a taxa em BNB subiria junto. Com matriz própria, as três
moedas se ajustam de forma independente — há teste cobrindo isso (`subir BCOIN e SEN nao altera o
preco nativo`).

A taxa padrão é `136860000000000`, reproduzindo a razão medida on-chain (0,00013686 nativo por
unidade de base). O design da Senspark usa `custo * 5 * getNativeRate() / 1e18`; aqui o fator 5 está
embutido na taxa, para não carregar constante mágica.

### Valor nativo exato

`require(msg.value == nativeCost)`, **sem devolução de troco** — mesma semântica do `BHeroS` em
produção. A UI precisa chamar `getUpgradePriceForHero(baseId)` **imediatamente antes de assinar**.
Preço em cache vira transação revertida se a configuração mudar no meio.

## O que este contrato deliberadamente NÃO faz

**Não grava atributos no `details`.** Só os bits 45–49 (nível) mudam, via
`BHeroDetails.increaseLevel`.

Isso não é detalhe de implementação — é obrigatório. `stamina` (bits 60–64) e `bombPower`
(bits 80–84) têm 5 bits, máximo 31. Um Super Mystic no nível 10 teria 33 de stamina e 38 de power
somando os bônus. Gravar isso truncaria: `33 & 31 = 1`, e o herói viraria 1 de stamina de forma
silenciosa e irreversível.

Os bônus por nível são calculados **em runtime pelo servidor**, a partir de
`config_hero_upgrade_power` e `config_hero_upgrade_stamina`. O `details` guarda só o valor base.
Há teste cobrindo essa invariante.

## Guardas de rede

Duas camadas, ambas restritas a BSC testnet (97) e Polygon Amoy (80002):

1. `initialize` reverte com `"Testnet only"` fora dessas redes — um deploy acidental em mainnet
   falha antes de criar qualquer estado.
2. O script de deploy recusa qualquer outro `chainId`.

## Pré-requisito que costuma passar despercebido

O contrato precisa de `MINTER_ROLE` e `BURNER_ROLE` **no BHeroToken alvo**. Conceder esses papéis
exige `DEFAULT_ADMIN_ROLE` no BHeroToken.

**Consequência prática:** não dá para usar isto contra o `BHeroToken` da Senspark na testnet
(`0xC1A4C06426B4Df799E455964A20FDe866E86fbd1`) sem que eles concedam os dois papéis — pedido bem
maior que o `DESIGNER_ROLE` já solicitado, porque `MINTER_ROLE` permite reescrever o `details` de
qualquer herói.

Os dois caminhos:

- **Deploy próprio de BHeroToken + BHeroDesign** a partir do fonte deste repositório, e mintar
  heróis de teste. Os 140 heróis atuais **não migram** — vivem no contrato da Senspark.
- **Pedir os papéis** na testnet. Mais simples de operar, mas é um pedido de confiança alta.

## Deploy

```bash
cd repos/bombcrypto-contract-v2/base-hardhat

HERO_TOKEN=0x...            # BHeroToken que VOCÊ controla
HERO_DESIGN=0x...           # BHeroDesign correspondente
BSC_TESTNET_RPC=https://bsc-testnet-dataseed.bnbchain.org \
npx hardhat --config hardhat.local.config.js --network bsctestnet \
  run scripts/deploy-bhero-upgrade-v2.js
```

O script faz o deploy do proxy, configura as matrizes de custo e a taxa nativa, imprime uma amostra
de preços para conferência e tenta conceder `MINTER_ROLE` e `BURNER_ROLE`. Se a concessão falhar,
ele imprime a chamada exata para fazer manualmente.

Depois: `BHeroDesign.setMaxLevel(10)`.

## Testes

```bash
npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.js
```

**23 testes**, em dois arquivos:

- `test/BHeroUpgradeV2.js` (20) — unitários sobre mocks: regra de material, as três faixas de preço,
  independência entre nativo e BCOIN/SEN, fluxo do 5 ao 10, invariante de não gravar atributos,
  valor nativo exato, posse, pausa, permissões e retirada.
- `test/BHeroUpgradeV2.integration.js` (3) — contra os contratos **reais** `BHeroDesign` e
  `BHeroToken`, reproduzindo o que o script de deploy faz. Cunha pelo fluxo real, sobe do 5 ao 10 e
  confere os totais exatos (25.000 BCOIN, 110.000 SEN, 1,6285 BNB), a queima real no ERC721 e que
  stamina e power ficam intocados.

```bash
npx hardhat --config hardhat.local.config.js test   test/BHeroUpgradeV2.js test/BHeroUpgradeV2.integration.js
```

A rede local usa `chainId: 97` de propósito, para que o guarda `Testnet only` esteja **ativo**
durante os testes em vez de contornado.

Os mocks em `contracts/mocks/BHeroUpgradeV2Mocks.sol` existem porque o `BHeroToken` real tem
cunhagem assíncrona (request/process por blocos), o que transformaria um teste de upgrade num teste
de cunhagem. Eles reproduzem exatamente a superfície consumida, incluindo a validação de
id/index do `updateToken` e o multiplicador 5x de HeroS.

## Balanceamento

Alvos definidos em 10/09/2026 para a **raridade 9 (Super Mystic)**, somando os cinco upgrades do
nível 5 ao 10:

| Moeda | Total |
|---|---|
| BCOIN | **25.000** |
| SEN | **110.000** |
| Nativo | **1,6285 BNB** (mantido como estava) |

Mais 5 heróis nível 5 como material.

A distribuição entre os níveis usa os pesos `[1.5, 2.2, 3.2, 4.6, 6.5]`, normalizados para bater o
total exato. As demais raridades escalam proporcionalmente ao último custo legado de cada uma
(raridade 9 = 661 é a âncora):

| Raridade | BCOIN | SEN | Nativo |
|---|---|---|---|
| 9 | 25.000 | 110.000 | 1,6285 |
| 5 | 7.526 | 33.116 | 0,4904 |
| 0 | 265 | 1.165 | 0,0172 |

Para a raridade 9, por nível: BCOIN `2083, 3056, 4444, 6389, 9028`; SEN `9167, 13444, 19556, 28111,
39722`.

Os totais são verificados de ponta a ponta no teste de integração, contra os contratos reais.

## Deploy do stack completo

O `BHeroUpgradeV2` precisa de `MINTER_ROLE` e `BURNER_ROLE` no BHeroToken, e conceder isso exige
`DEFAULT_ADMIN_ROLE` — que não temos no contrato da Senspark. Por isso existe
`scripts/deploy-testnet-stack.js`, que publica um stack próprio:

```bash
BSC_TESTNET_RPC=... DEPLOYER_KEY=0x... npx hardhat --config hardhat.local.config.js --network bsctestnet   run scripts/deploy-testnet-stack.js
```

Ele faz:

1. `BHeroDesign` + as raridades 6-9 (o `initialize` só semeia 0-5) + `setMaxLevel(10)`.
2. `BHeroToken` apontando para esse design, reaproveitando BCOIN e SEN de testnet da Senspark.
3. Heróis de teste pelo fluxo real de cunhagem (`createTokenRequest` + `processTokenRequests`).
4. Fixa raridade, stamina, power e nível 5 nesses heróis via `setTokenDetails`.
5. Imprime o comando pronto para o deploy do `BHeroUpgradeV2` apontando para o stack.

O passo 4 é **preparação de fixture, não fluxo de jogo**: a cunhagem é gacha e a raridade sai das
drop rates, então forçar os atributos é o que permite ter um Super Mystic com stamina e power
exatamente no teto de 30 — o caso que interessa validar. Subir do 1 ao 5 pela regra normal exigiria
16 heróis por herói.

Como o deployer tem `DEFAULT_ADMIN_ROLE` nesse BHeroToken, a concessão dos dois papéis ao
`BHeroUpgradeV2` passa automaticamente.

**Os 140 heróis da conta continuam no contrato da Senspark e não migram.**
