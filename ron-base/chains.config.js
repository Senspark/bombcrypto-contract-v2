const chains = {
  'ronin-mainnet': {
    chainId: 2020,
    chainIdHex: '0x7e4',
    chainName: 'Ronin Mainnet',
    rpcUrl: 'https://api.roninchain.com/rpc',
    currencySymbol: 'RON',
    decimals: 18,
    blockExplorerUrl: 'https://app.roninchain.com/'
  },
  'ronin-testnet': {
    chainId: 2021,
    chainIdHex: '0x7e5',
    chainName: 'Ronin Saigon Testnet',
    rpcUrl: 'https://saigon-testnet.roninchain.com/rpc',
    currencySymbol: 'RON',
    decimals: 18,
    blockExplorerUrl: 'https://saigon-app.roninchain.com/'
  },
  'base-mainnet': {
    chainId: 8453,
    chainIdHex: '0x2105',
    chainName: 'Base Mainnet',
    rpcUrl: 'https://mainnet.base.org/',
    currencySymbol: 'ETH',
    decimals: 18,
    blockExplorerUrl: 'https://basescan.org/'
  },
  'base-testnet': {
    chainId: 84532,
    chainIdHex: '0x14a34',
    chainName: 'Base Sepolia',
    rpcUrl: 'https://sepolia.base.org/',
    currencySymbol: 'ETH',
    decimals: 18,
    blockExplorerUrl: 'https://sepolia.basescan.org/'
  },
  'viction-mainnet': {
    chainId: 88,
    chainIdHex: '0x58',
    chainName: 'Viction',
    rpcUrl: 'https://rpc.viction.xyz',
    currencySymbol: 'VIC',
    decimals: 18,
    blockExplorerUrl: 'https://vicscan.xyz/'
  },
  'viction-testnet': {
    chainId: 89,
    chainIdHex: '0x59',
    chainName: 'Viction Testnet',
    rpcUrl: 'https://rpc-testnet.viction.xyz/',
    currencySymbol: 'VIC',
    decimals: 18,
    blockExplorerUrl: 'https://testnet.vicscan.xyz/'
  }
};

module.exports = { chains };