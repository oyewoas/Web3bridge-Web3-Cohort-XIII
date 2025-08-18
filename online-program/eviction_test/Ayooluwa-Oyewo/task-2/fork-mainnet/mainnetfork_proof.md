## npx hardhat run scripts/addLiquidity.ts --network hardhat
Pair Address: 0xB20bd5D04BE54f870D5C0d3cA85d82b34B836405
Whale's ETH balance before: 554999.056740208991931219
Whale's ETH balance after: 555009.056740208991931219
USDT balance before adding liquidity: 6784997789.440132
DAI balance before adding liquidity: 40999972.0
USDT in pool before: 17167.940298
DAI in pool before: 17166.857853003706108293
Adding 10.0 DAI and 10.0 USDT
Minimum amounts: 9.5 DAI and 9.5 USDT
USDT in pool after: 17177.940298
DAI in pool after: 17176.857222500001234626
USDT balance after adding liquidity: 6784997779.440132
DAI balance after adding liquidity: 40999962.000630503704873667
Actual DAI taken: 9.999369496295126333
Actual USDT taken: 10.0



## npx hardhat run scripts/createAndFundPair.ts --network hardhat
Chainlink balance before: 9000000.0000009999
Shiba Inu balance before: 9040000000000.0
Pair created successfully:  0xba5B532D8C06ba11a37B8071c1081D2Db4B2A642
Shiba Inu in pool before: 0.0
Chainlink in pool before: 0.0
Shiba Inu in pool after: 1.0
Chainlink in pool after: 5800000.0
Chainlink balance after: 3200000.0000009999
Shiba Inu balance after: 9039999999999.0
Actual Shiba taken: 1.0
Actual Chainlink taken: 5800000.0

## npx hardhat run scripts/removeLiquidity.ts --network hardhat
========== ADDING LIQUIDITY ==========
Pair Address: 0xB20bd5D04BE54f870D5C0d3cA85d82b34B836405
Whale's ETH balance before: 554999.056740208991931219
Whale's ETH balance after: 555009.056740208991931219
USDT balance before adding liquidity: 6784997789.440132
DAI balance before adding liquidity: 40999972.0
USDT in pool before: 17167.940298
DAI in pool before: 17166.857853003706108293
Adding 10.0 DAI and 10.0 USDT
Minimum amounts: 9.5 DAI and 9.5 USDT
USDT in pool after: 17177.940298
DAI in pool after: 17176.857222500001234626
USDT balance after adding liquidity: 6784997779.440132
DAI balance after adding liquidity: 40999962.000630503704873667
Actual DAI taken: 9.999369496295126333
Actual USDT taken: 10.0

========== REMOVING LIQUIDITY ==========
Pair Address: 0xB20bd5D04BE54f870D5C0d3cA85d82b34B836405
Whale's ETH balance before: 555009.056650622563811464
Whale's ETH balance after: 555019.056650622563811464
USDT balance before removing liquidity: 6784997779.440132
DAI balance before removing liquidity: 40999962.000630503704873667
USDT in pool before: 17177.940298
DAI in pool before: 17176.857222500001234626
LP token balance: 0.000008176442442527
Removing 0.000004088221221263 LP tokens
Minimum amounts: 4.75 DAI and 4.75 USDT
USDT in pool after: 17172.940299
DAI in pool after: 17171.857537751854782629
USDT balance after removing liquidity: 6784997784.440131
DAI balance after removing liquidity: 40999967.000315251851325664
Actual DAI received: 4.999684748146451997
Actual USDT received: 4.999999
Remaining LP token balance: 0.000004088221221264



## npx hardhat run scripts/swapExactTokenForToken.ts --network hardhat
Balance of Dai before swap 40999972.0
Balance of Usdt before swap 6784997789.440132
Expected DAI out: 942.219297099981858138
Minimum DAI out (with slippage): 895.108332244982765231
Balance of Dai after swap 41000914.219297099981858138
Balance of Usdt after swap 6784996789.440132
Dai difference: 942.219297099981858138
Usdt difference: 1000.0

## npx hardhat run scripts/swapTokensForExactToken.ts --network hardhat

Balance of Dai before swap 40999972.0
Balance of Usdt before swap 6784997789.440132
USDT needed for swap: 1065.117245
Max USDT to spend (with slippage): 1278.140694
Balance of Dai after swap 41000972.0
Balance of Usdt after swap 6784996724.322887
Dai difference: 1000.0
Usdt difference: 1065.117245