# Níveis 6-10 de upgrade de herói

[English](README.en.md) · [Tiếng Việt](README.vi.md)

Sobe o teto de nível do herói de 5 para 10. Os níveis 6-10 alternam entre energia e poder, e cobram
BCOIN + SEN + a moeda nativa da rede, em vez de só a nativa.

> **Somente testnet.** Todo contrato aqui recusa qualquer rede que não seja BSC testnet (97) ou
> Polygon Amoy (80002). O token de faucet tem `mint` público e sem permissão.

## Como os níveis novos funcionam

Cada upgrade queima um herói material e sobe o herói base em um nível.

| Nível | Ganha | Poder total | Stamina total |
|------:|-------|------------:|--------------:|
| 1-5   | (comportamento atual) | 0 1 2 3 5 | 0 0 0 0 0 |
| 6     | +1 energia | 5 | 1 |
| 7     | +1 poder   | 6 | 1 |
| 8     | +1 energia | 6 | 2 |
| 9     | +1 poder   | 7 | 2 |
| 10    | +1 poder e +1 energia | 8 | 3 |

As duas tabelas guardam o **total acumulado naquele nível**, não o incremento por upgrade. O poder
repete nos níveis 6 e 8 (5,5 e 6,6) porque esses níveis dão stamina.

Um ponto de stamina vale 50 de energia (`HeroHelper.ENERGY_PER_STAMINA`), então um herói raridade 9
sai de 30 stamina / 1500 energia no nível 5 para 33 / 1650 no nível 10.

### Regra do material

Abaixo do nível 5 o material precisa ser do **mesmo nível** do base — inalterado. Do nível 5 em
diante o material é sempre um herói **nível 5**, para que chegar ao 10 não exija uma cadeia de
upgrades exponencialmente maior.

### Por que o bônus nunca é gravado on-chain

O `BHeroDetails` empacota stamina e bombPower em **5 bits cada**, então 31 é o teto. Um herói
raridade 9 já tem 30 de cada, e o bônus de nível levaria o poder a 38 e a stamina a 33.

Isso **não** é um risco novo trazido pelos níveis 6-10 — o teto já é ultrapassado hoje, porque um
raridade 9 no nível 5 lê 35 de poder. Funciona porque o bônus é **calculado em tempo de execução
pelo servidor** e nunca armazenado. O contrato só mexe nos bits 45-49 (nível); nunca toca nos campos
de atributo. Mantenha assim.

### Queima de token

25% do BCOIN e do SEN cobrados são queimados; os 75% restantes ficam no contrato para o
`WITHDRAWER_ROLE`. A moeda nativa não é queimada, e os níveis legados (1-4) não queimam nada porque
não cobram token.

O destino da queima depende do `burnSink`:

- `burnSink == address(0)` (padrão): **queima real** via `burnFrom` — o `totalSupply` cai e o log
  registra `Transfer` para `0x0`.
- `burnSink != address(0)`: transferência simples para esse endereço. Necessário para tokens que não
  expõem `burnFrom`, porque o `_transfer` da OpenZeppelin **reverte** quando o destino é o endereço
  zero — não existe "transferir para 0x0".

O `scripts/upgrade-bhero-upgrade-v2.js` detecta `burnFrom` procurando o seletor `79cc6790` no
bytecode publicado e configura o `burnSink` de acordo. Errar isso faz **todo** upgrade com cobrança
em token reverter.

### A moeda nativa não é fixa no código

O contrato cobra `msg.value`, então "nativo" é BNB na BSC e POL na Polygon sem nenhum `if` no
código. O único valor específico de moeda é a `nativeRate`, definida por rede em
`NATIVE_RATE_BY_CHAIN`, calibrada para o upgrade custar o mesmo em dólar nas duas redes.

## Como aplicar

> Os comandos abaixo que usam `hardhat.local.config.js`, `deploy-testnet-stack.js`,
> `upgrade-tokens-to-burnable.js`, `build-server.sh` ou `deploy-amoy.sh` pertencem ao **stack local
> de testnet**, não à feature. Eles vivem em commits `chore(testnet)` separados. Numa implantação
> oficial, use a config do Hardhat daquele projeto, os contratos de token reais e o pipeline de
> deploy de lá; só as migrações de banco, o rebuild da extensão e o deploy/upgrade do contrato
> fazem parte da feature.

### 1. Banco de dados

```bash
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120100_extend_hero_upgrade_power_to_level_10.sql
psql -U postgres -d bombcrypto -f server/db/migrations/20260910_120000_add_hero_upgrade_stamina.sql
```

Verificar — as duas devem devolver 10 linhas:

```sql
SELECT rare, datas FROM config_hero_upgrade_power   ORDER BY rare;  -- [0,1,2,3,5,5,6,6,7,8]
SELECT rare, datas FROM config_hero_upgrade_stamina ORDER BY rare;  -- [0,0,0,0,0,1,1,2,2,3]
```

A configuração é lida para a memória na inicialização, então **reinicie o servidor depois** de
rodar, não antes.

### 2. Extensão do servidor

```bash
./build-server.sh
```

Publique o JAR no diretório que o container realmente monta. O `server/run.sh` do upstream copia
para `server/deploy/extensions_volume`, que é o que o compose do upstream monta; o stack local monta
`server/deploy/SmartFoxServer_2X`. Publicar no lugar errado deixa o container rodando o JAR antigo da
imagem, e o sintoma é `Request handler not found: 'GET_HERO_UPGRADE_STAMINA_V2'` com o cliente
travando no passo de sync correspondente.

O `build-server.sh` compara o tamanho do JAR dentro do container com o do build local e falha alto se
forem diferentes.

### 3. Contratos

```bash
cd repos/bombcrypto-contract-v2/base-hardhat
npx hardhat --config hardhat.local.config.js test test/BHeroUpgradeV2.js

# Publicação nova
DEPLOYER_KEY=0x... npx hardhat --config hardhat.local.config.js --network <rede> run scripts/deploy-testnet-stack.js
DEPLOYER_KEY=0x... HERO_TOKEN=0x... HERO_DESIGN=0x... BCOIN_TOKEN=0x... SEN_TOKEN=0x... \
  npx hardhat --config hardhat.local.config.js --network <rede> run scripts/deploy-bhero-upgrade-v2.js

# Atualizar um proxy existente
DEPLOYER_KEY=0x... PROXY=0x... npx hardhat --config hardhat.local.config.js --network <rede> run scripts/upgrade-bhero-upgrade-v2.js
```

O `initialize` não roda de novo num upgrade de proxy, então qualquer campo novo com valor padrão
precisa ser configurado explicitamente — é o que o script faz com `burnRateBps` e `burnSink`.

Para o stack completo na Polygon Amoy: `./deploy-amoy.sh` (precisa de POL para gas).

### Trocar os tokens de teste por queimáveis

Só é necessário onde os tokens publicados são anteriores à funcionalidade de queima:

```bash
DEPLOYER_KEY=0x... PROXY=0x... HOLDERS=0xa,0xb \
  npx hardhat --config hardhat.local.config.js --network <rede> run scripts/upgrade-tokens-to-burnable.js
```

Publica tokens novos, re-minta o saldo de cada carteira, reaponta o proxy e liga a queima real.
**Os endereços mudam**, então é preciso atualizar depois `addresses.ts`, `BscAddress.ts`, a lista de
tokens das carteiras e as allowances de ERC20.

### 4. Cliente

O teto de nível fica em `UpgradeHeroLevelPolygon.MaxLevel` e precisa espelhar o
`BHeroDesign.getMaxLevel()`. Todos os níveis passam pelo `BHeroUpgradeV2`, inclusive 1-4, que o
contrato cobra só em nativo — o caminho antigo lia do `BHeroS` de produção, que não existe no stack
de teste.

## Layout de storage

O `BHeroUpgradeV2` é um proxy UUPS. Dois campos foram acrescentados depois do `nativeRate`
(`burnRateBps`, `burnSink`) e o `__gap` caiu de 40 para 38, mantendo o footprint total constante.
Preserve essa invariante em qualquer upgrade futuro.

## Arquivos

| Área | Caminho |
|---|---|
| Contrato | `base-hardhat/contracts/BHeroUpgradeV2.sol` |
| Token de teste | `base-hardhat/contracts/TestnetFaucetToken.sol` |
| Testes | `base-hardhat/test/BHeroUpgradeV2.js` |
| Config de stamina | `.../data/manager/hero/HeroUpgradeStaminaManager.kt` |
| Totais de atributo | `.../data/manager/hero/HeroHelper.kt` |
| Migrações | `server/db/migrations/20260910_*.sql` |
| Diálogo de upgrade | `Assets/Scripts/Game/Dialog/UpgradeHeroLevelPolygon.cs` |
