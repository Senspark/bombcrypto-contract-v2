// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./BHeroDetails.sol";
import "./IBHeroDesign.sol";

/// Subconjunto do BHeroToken que este contrato precisa. `setTokenDetails` exige MINTER_ROLE e
/// `burn` exige BURNER_ROLE no BHeroToken — os dois papéis precisam ser concedidos a este contrato.
interface IERC20Burnable {
  /// Queima de verdade: reduz o totalSupply e emite Transfer(account, 0x0, amount). Consome a
  /// allowance de quem chama, igual a transferFrom.
  function burnFrom(address account, uint256 amount) external;
}

interface IBHeroTokenUpgradable {
  function tokenDetails(uint256 id) external view returns (uint256);

  function ownerOf(uint256 id) external view returns (address);

  function setTokenDetails(uint256 id, uint256 details) external;

  function burn(uint256[] calldata ids) external;

  function getHeroCostByDetails(uint256 details, uint256 cost) external pure returns (uint256);
}

/**
 * @title BHeroUpgradeV2
 * @notice Contrato de TESTE para os níveis 6 a 10 de upgrade de herói, cobrando BCOIN + SEN +
 *         token nativo. Escrito porque a Senspark não publicou o fonte do BHeroS, que hoje faz o
 *         upgrade cobrando somente nativo.
 *
 * @dev SOMENTE TESTNET. Ver os guardas em `initialize` e no script de deploy.
 *
 * Arquitetura: este contrato NÃO modifica o BHeroToken. Ele opera por fora, usando
 * `setTokenDetails` (MINTER_ROLE) e `burn` (BURNER_ROLE). Isso permite testar a mecânica inteira
 * sem redeploy do token e sem tocar no fonte que a Senspark mantém.
 *
 * Compatibilidade com o comportamento em produção:
 *
 *  - Níveis 2 a 5: material do MESMO nível do herói base, pagamento SÓ em nativo. Idêntico ao que
 *    o BHeroS implantado faz hoje.
 *  - Níveis 6 a 10: material de nível 5, pagamento em BCOIN + SEN + nativo. É o comportamento novo.
 *
 * A regra de material relaxada nos níveis altos existe porque a regra "mesmo nível" dobra o custo
 * em heróis a cada nível: chegar ao 10 exigiria 512 heróis base. Com material fixo no nível 5, são
 * 96, e o balanceamento passa a ser feito pelos três tokens, que são ajustáveis por setter.
 *
 * O teto de 5 bits do `details` NÃO é problema: este contrato só altera os bits 45-49 (nível), via
 * `BHeroDetails.increaseLevel`. Os atributos stamina (bits 60-64) e bombPower (bits 80-84)
 * permanecem intocados, e os bônus por nível continuam sendo calculados em runtime pelo servidor.
 * Gravar totais aqui truncaria: 33 & 31 = 1.
 */
contract BHeroUpgradeV2 is
  AccessControlUpgradeable,
  UUPSUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  /// Último nível sob a regra antiga. Até ele, material do mesmo nível e pagamento só em nativo.
  uint256 public constant LEGACY_MAX_LEVEL = 5;

  /// Teto que NAO depende do design. BHeroDetails.increaseLevel escreve (level+1) no bit 45
  /// sem mascarar para 5 bits: com level 31 o valor 32 invade o bit 50, que e o campo color, e
  /// zera o nivel. Um design trocado ou mal configurado corromperia o hero sem reverter, entao o
  /// limite fica gravado aqui tambem.
  uint256 public constant ABSOLUTE_MAX_LEVEL = 10;

  /// Denominador de `nativeRate`. Ver `getUpgradePrice`.
  uint256 private constant RATE_DENOMINATOR = 1e18;

  /// Denominador dos basis points: 10000 = 100%.
  uint256 private constant BPS_DENOMINATOR = 10000;

  /// Sugestao de burnSink para tokens SEM burnFrom. Nao e usado por padrao  com burnSink zerado
  /// a queima e real, via burnFrom. Fica exposto para quem precisar configurar o fallback.
  address public constant FALLBACK_BURN_SINK = 0x000000000000000000000000000000000000dEaD;

  /// 25% de BCOIN e SEN queimados por upgrade.
  uint256 public constant DEFAULT_BURN_RATE_BPS = 2500;

  IBHeroTokenUpgradable public heroToken;
  IBHeroDesign public design;
  IERC20Upgradeable public bcoinToken;
  IERC20Upgradeable public senToken;

  /// Base do preço NATIVO por [raridade][nível-1]. Não é cobrada como token: só alimenta o cálculo
  /// `nativo = base * nativeRate / 1e18`. Nos níveis legados reproduz a matriz de produção.
  /// Precisa de 9 entradas por raridade para cobrir os níveis 1->2 até 9->10.
  uint256[][] private nativeBase;

  /// BCOIN cobrado por [raridade][nível-1], em wei. Zero nos níveis legados.
  uint256[][] private upgradeCostBcoin;

  /// SEN cobrado por [raridade][nível-1], em wei. Zero nos níveis legados.
  uint256[][] private upgradeCostSen;

  /// Preço nativo = nativeBase * nativeRate / 1e18.
  /// O design em produção usa `custo * 5 * getNativeRate() / 1e18`; aqui o fator 5 está embutido na
  /// taxa para não carregar constante mágica. Para espelhar produção, use 5x o `getNativeRate()` de lá.
  ///
  /// O nativo tem matriz própria de propósito: BCOIN e SEN nos níveis 6-10 foram calibrados bem
  /// acima da curva legada, e derivar o nativo deles multiplicaria a taxa em BNB junto. Separar
  /// deixa as três moedas ajustáveis de forma independente.
  uint256 public nativeRate;

  /// Fracao de BCOIN e SEN queimada a cada upgrade, em basis points. O restante fica no contrato
  /// para o WITHDRAWER_ROLE. Nao se aplica ao token nativo.
  uint256 public burnRateBps;

  /// Destino da parcela queimada. address(0)  o padrao  faz queima REAL via burnFrom: o
  /// totalSupply cai e o log registra Transfer para 0x0. Um endereco nao-zero faz transferencia
  /// simples, para tokens que nao expoem burnFrom.
  address public burnSink;

  event HeroUpgraded(
    address indexed to,
    uint256 indexed baseId,
    uint256 materialId,
    uint256 fromLevel,
    uint256 toLevel,
    uint256 bcoinPaid,
    uint256 senPaid,
    uint256 nativePaid
  );

  event PricesUpdated(uint256 rarities, uint256 levels);
  event NativeRateUpdated(uint256 value);
  event BurnRateUpdated(uint256 bps);
  event BurnSinkUpdated(address sink);
  event TokensBurned(address indexed user, uint256 indexed baseId, uint256 bcoinBurned, uint256 senBurned);
  event Withdrawn(address indexed token, address indexed to, uint256 amount);

  /// @param heroToken_ BHeroToken que este contrato vai modificar. Precisa conceder MINTER_ROLE e
  ///        BURNER_ROLE a este endereço depois do deploy.
  /// @param design_ BHeroDesign de onde vem `getMaxLevel()`.
  function initialize(
    address heroToken_,
    address design_,
    address bcoinToken_,
    address senToken_
  ) public initializer {
    // Guarda de rede. Só BSC testnet (97) e Polygon Amoy (80002). Um deploy acidental em mainnet
    // reverte aqui, antes de qualquer estado ser criado.
    require(block.chainid == 97 || block.chainid == 80002, "Testnet only");
    require(heroToken_ != address(0) && design_ != address(0), "Zero address");
    require(bcoinToken_ != address(0) && senToken_ != address(0), "Zero address");

    __AccessControl_init();
    __UUPSUpgradeable_init();
    __Pausable_init();
    __ReentrancyGuard_init();

    heroToken = IBHeroTokenUpgradable(heroToken_);
    design = IBHeroDesign(design_);
    bcoinToken = IERC20Upgradeable(bcoinToken_);
    senToken = IERC20Upgradeable(senToken_);
    burnRateBps = DEFAULT_BURN_RATE_BPS;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(UPGRADER_ROLE, msg.sender);
    _setupRole(DESIGNER_ROLE, msg.sender);
    _setupRole(WITHDRAWER_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  // ---------------------------------------------------------------------------------------------
  // Upgrade
  // ---------------------------------------------------------------------------------------------

  /**
   * @notice Sobe o herói `baseId` em um nível, queimando `materialId`.
   *
   * @dev O valor nativo precisa ser EXATO. Não há devolução de troco, igual ao BHeroS em produção.
   *      Leia `getUpgradePriceForHero(baseId)` imediatamente antes de assinar: um preço em cache
   *      vira transação revertida se a configuração mudar no meio.
   */
  function upgradeHero(uint256 baseId, uint256 materialId) external payable nonReentrant whenNotPaused {
    require(baseId != materialId, "Same token");

    address to = msg.sender;
    require(heroToken.ownerOf(baseId) == to, "Base not owned");
    require(heroToken.ownerOf(materialId) == to, "Material not owned");

    uint256 baseDetails = heroToken.tokenDetails(baseId);
    uint256 baseLevel = BHeroDetails.decodeLevel(baseDetails);
    require(baseLevel >= 1, "Invalid base level");
    require(baseLevel + 1 <= design.getMaxLevel(), "Max level");
    require(baseLevel + 1 <= ABSOLUTE_MAX_LEVEL, "Above hard cap");

    uint256 materialLevel = BHeroDetails.decodeLevel(heroToken.tokenDetails(materialId));
    require(materialLevel == requiredMaterialLevel(baseLevel), "Wrong material level");

    (uint256 bcoinCost, uint256 senCost, uint256 nativeCost) = getUpgradePrice(
      BHeroDetails.decodeRarity(baseDetails),
      baseLevel,
      baseDetails
    );
    require(msg.value == nativeCost, "Wrong native amount");

    // A parcela queimada sai da carteira do jogador direto para o dead address, sem passar pelo
    // contrato: assim o saldo retir�vel pelo WITHDRAWER_ROLE nunca inclui o que foi queimado.
    uint256 bcoinBurned = _collect(bcoinToken, to, bcoinCost);
    uint256 senBurned = _collect(senToken, to, senCost);
    if (bcoinBurned > 0 || senBurned > 0) {
      emit TokensBurned(to, baseId, bcoinBurned, senBurned);
    }

    // Queima o material antes de subir o nível: se o burn falhar, nada mudou no herói base.
    uint256[] memory burning = new uint256[](1);
    burning[0] = materialId;
    heroToken.burn(burning);

    // Só os bits 45-49 mudam. Atributos ficam intocados de propósito — ver o comentário do topo.
    heroToken.setTokenDetails(baseId, BHeroDetails.increaseLevel(baseDetails));

    emit HeroUpgraded(to, baseId, materialId, baseLevel, baseLevel + 1, bcoinCost, senCost, nativeCost);
  }

  // ---------------------------------------------------------------------------------------------
  // Preço e regras
  // ---------------------------------------------------------------------------------------------

  /// Nível exigido do herói material para subir a partir de `baseLevel`.
  /// Até o nível legado, mesmo nível do base. Acima dele, sempre nível 5.
  function requiredMaterialLevel(uint256 baseLevel) public pure returns (uint256) {
    return baseLevel < LEGACY_MAX_LEVEL ? baseLevel : LEGACY_MAX_LEVEL;
  }

  /**
   * @notice Preço para subir a partir de `baseLevel`, já com o multiplicador de HeroS aplicado.
   * @return bcoinCost wei de BCOIN. Zero nos níveis legados.
   * @return senCost   wei de SEN. Zero nos níveis legados.
   * @return nativeCost wei do token nativo. Sempre cobrado.
   */
  function getUpgradePrice(
    uint256 rarity,
    uint256 baseLevel,
    uint256 details
  ) public view returns (uint256 bcoinCost, uint256 senCost, uint256 nativeCost) {
    uint256 index = baseLevel - 1;
    require(rarity < nativeBase.length, "Rarity not configured");
    require(index < nativeBase[rarity].length, "Level not configured");

    // O nativo é cobrado em todos os níveis, inclusive nos legados.
    nativeCost =
      (heroToken.getHeroCostByDetails(details, nativeBase[rarity][index]) * nativeRate) /
      RATE_DENOMINATOR;

    if (baseLevel < LEGACY_MAX_LEVEL) {
      return (0, 0, nativeCost);
    }

    bcoinCost = heroToken.getHeroCostByDetails(details, upgradeCostBcoin[rarity][index]);
    senCost = heroToken.getHeroCostByDetails(details, upgradeCostSen[rarity][index]);
  }

  /// Preço para um herói concreto. É o que a UI deve chamar imediatamente antes de assinar.
  function getUpgradePriceForHero(
    uint256 baseId
  ) external view returns (uint256 bcoinCost, uint256 senCost, uint256 nativeCost) {
    uint256 details = heroToken.tokenDetails(baseId);
    return getUpgradePrice(BHeroDetails.decodeRarity(details), BHeroDetails.decodeLevel(details), details);
  }

  function getUpgradeCosts()
    external
    view
    returns (uint256[][] memory native, uint256[][] memory bcoin, uint256[][] memory sen)
  {
    return (nativeBase, upgradeCostBcoin, upgradeCostSen);
  }

  function getMaxLevel() external view returns (uint256) {
    return design.getMaxLevel();
  }

  // ---------------------------------------------------------------------------------------------
  // Configuração
  // ---------------------------------------------------------------------------------------------

  /// As três matrizes precisam ter o mesmo formato para que um índice válido em uma seja válido nas
  /// outras — evita que um upgrade cobre BCOIN e silenciosamente não cobre SEN, ou vice-versa.
  function setUpgradeCosts(
    uint256[][] memory native,
    uint256[][] memory bcoin,
    uint256[][] memory sen
  ) external onlyRole(DESIGNER_ROLE) {
    require(native.length == bcoin.length && bcoin.length == sen.length, "Length mismatch");
    for (uint256 i = 0; i < native.length; ++i) {
      require(native[i].length == bcoin[i].length && bcoin[i].length == sen[i].length, "Row length mismatch");
    }
    nativeBase = native;
    upgradeCostBcoin = bcoin;
    upgradeCostSen = sen;
    emit PricesUpdated(native.length, native.length > 0 ? native[0].length : 0);
  }

  /// Cobra amount do jogador: burnRateBps vira queima e o resto fica no contrato. Devolve quanto
  /// foi queimado.
  ///
  /// Com burnSink zerado (o padrao) a queima usa burnFrom no proprio token, entao o valor some do
  /// totalSupply e o log registra Transfer para 0x0. Nao existe transferencia direta para o
  /// endereco zero: o _transfer da OpenZeppelin reverte nesse caso. Token sem burnFrom precisa de
  /// um burnSink configurado, senao o upgrade inteiro reverte.
  function _collect(IERC20Upgradeable token, address from, uint256 amount) private returns (uint256) {
    if (amount == 0) {
      return 0;
    }
    uint256 burned = (amount * burnRateBps) / BPS_DENOMINATOR;
    if (burned > 0) {
      address sink = burnSink;
      if (sink == address(0)) {
        IERC20Burnable(address(token)).burnFrom(from, burned);
      } else {
        token.safeTransferFrom(from, sink, burned);
      }
    }
    uint256 kept = amount - burned;
    if (kept > 0) {
      token.safeTransferFrom(from, address(this), kept);
    }
    return burned;
  }

  /// address(0) = queima real via burnFrom. Qualquer outro endereco recebe por transferencia,
  /// para tokens que nao expoem burnFrom.
  function setBurnSink(address value) external onlyRole(DESIGNER_ROLE) {
    burnSink = value;
    emit BurnSinkUpdated(value);
  }

  function setBurnRateBps(uint256 bps) external onlyRole(DESIGNER_ROLE) {
    require(bps <= BPS_DENOMINATOR, "Burn rate too high");
    burnRateBps = bps;
    emit BurnRateUpdated(bps);
  }

  function setNativeRate(uint256 value) external onlyRole(DESIGNER_ROLE) {
    nativeRate = value;
    emit NativeRateUpdated(value);
  }

  function setDesign(address value) external onlyRole(DESIGNER_ROLE) {
    require(value != address(0), "Zero address");
    design = IBHeroDesign(value);
  }

  function setTokens(address bcoin, address sen) external onlyRole(DESIGNER_ROLE) {
    require(bcoin != address(0) && sen != address(0), "Zero address");
    bcoinToken = IERC20Upgradeable(bcoin);
    senToken = IERC20Upgradeable(sen);
  }

  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  // ---------------------------------------------------------------------------------------------
  // Retirada
  // ---------------------------------------------------------------------------------------------

  function withdrawNative(address payable to, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(to != address(0), "Zero address");
    (bool ok, ) = to.call{value: amount}("");
    require(ok, "Native transfer failed");
    emit Withdrawn(address(0), to, amount);
  }

  function withdrawToken(address token, address to, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
    require(to != address(0), "Zero address");
    IERC20Upgradeable(token).safeTransfer(to, amount);
    emit Withdrawn(token, to, amount);
  }

  /// Espaço reservado para variáveis futuras sem quebrar o layout de storage do proxy.
  // Reduzido de 40 para 39 quando burnRateBps foi adicionado: a soma (variaveis + gap) tem que
  // ficar constante para nao deslocar o storage de quem ja esta implantado.
  uint256[38] private __gap;
}
