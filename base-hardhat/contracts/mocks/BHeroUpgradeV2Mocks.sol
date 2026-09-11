// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../BHeroDetails.sol";

/// Mocks só para os testes do BHeroUpgradeV2. Não fazem parte de nenhum deploy.
///
/// O BHeroToken real é um proxy UUPS com fluxo de cunhagem assíncrono (request/process com
/// blocos), o que tornaria o teste sobre o upgrade um teste sobre a cunhagem. Estes mocks expõem
/// exatamente a superfície que o BHeroUpgradeV2 consome — `tokenDetails`, `ownerOf`,
/// `setTokenDetails`, `burn` e `getHeroCostByDetails` — com a mesma semântica.

/// Queimavel de proposito: o BHeroUpgradeV2 chama burnFrom para a parcela queimada do upgrade.
contract MockERC20 is ERC20, ERC20Burnable {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

/// ERC20 sem burnFrom, para cobrir o caminho do burnSink configurado.
contract MockPlainERC20 is ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}

contract MockBHeroToken {
  mapping(uint256 => uint256) public tokenDetails;
  mapping(uint256 => address) private owners;

  function mintTo(address to, uint256 id, uint256 details) external {
    owners[id] = to;
    tokenDetails[id] = details;
  }

  function ownerOf(uint256 id) external view returns (address) {
    address owner = owners[id];
    require(owner != address(0), "ERC721: invalid token ID");
    return owner;
  }

  function exists(uint256 id) external view returns (bool) {
    return owners[id] != address(0);
  }

  /// Reproduz o `updateToken` do BHeroToken: id e index precisam ser preservados.
  function setTokenDetails(uint256 id, uint256 details) external {
    require(
      BHeroDetails.decodeId(details) == id &&
        BHeroDetails.decodeIndex(details) == BHeroDetails.decodeIndex(tokenDetails[id]),
      "Invalid details"
    );
    tokenDetails[id] = details;
  }

  function burn(uint256[] calldata ids) external {
    for (uint256 i = 0; i < ids.length; ++i) {
      delete owners[ids[i]];
      delete tokenDetails[ids[i]];
    }
  }

  /// Igual ao BHeroToken: HeroS custa 5x.
  function getHeroCostByDetails(uint256 details, uint256 cost) external pure returns (uint256) {
    if (BHeroDetails.isHeroS(details)) {
      return cost * 5;
    }
    return cost;
  }
}

contract MockBHeroDesign {
  uint256 private maxLevel;

  constructor(uint256 maxLevel_) {
    maxLevel = maxLevel_;
  }

  function setMaxLevel(uint256 value) external {
    maxLevel = value;
  }

  function getMaxLevel() external view returns (uint256) {
    return maxLevel;
  }
}
