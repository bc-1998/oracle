pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { UniswapOracle } from  "@Keydonix/UniswapOracle.sol";
import { IUniswapV2Pair } from "@Keydonix/IUniswapV2Pair.sol";

/**
 * @notice A UniswapOracle contract for price lookup
 */
contract UniswapAdapter is UniswapOracle{
	event Price(uint256 price);

    /**
     * @notice get the live price for the asset
     * @dev invokes UniswapOracle.getPrice()
     * @param _uniswapV2Pair Uniswap v2 pair involving the asset corresponding to _expiryTimestamp
     * @param _denominationToken denomination token for the asset in the pair
     * @param _minBlocksBack minimal number of blocks before the current block
     * @param _maxBlocksBack maximal number of blocks before the current block
     * @param _proofData storage proof data
     * @return price of the asset in USD, scaled by 1e8
     */
	function getPrice(IUniswapV2Pair _uniswapV2Pair, address _denominationToken, uint8 _minBlocksBack, uint8 _maxBlocksBack, UniswapOracle.ProofData memory _proofData) public returns (uint256 price) {
		(price) = getPrice(_uniswapV2Pair, _denominationToken, _minBlocksBack, _maxBlocksBack, _proofData);
		emit Price(price);
	}

    /**
     * @notice get the price for the asset 
     * @dev invokes UniswapOracle.getPrice()
     * @param _uniswapV2Pair Uniswap v2 pair involving the asset corresponding to _expiryTimestamp
     * @param _denominationToken denomination token for the asset in the pair
     * @param _minBlocksBack minimal number of blocks before the current block
     * @param _maxBlocksBack maximal number of blocks before the current block
     * @param _proofData storage proof data
     * @param _expiryTimestamp expiry to set a price for
     * @return price of the asset in USD, scaled by 1e8
     */
    function getPriceForSpecificTimePoint(IUniswapV2Pair _uniswapV2Pair, address _denominationToken, uint8 _minBlocksBack, uint8 _maxBlocksBack, ProofData memory _proofData, uint256 _expiryTimestamp) public view returns (uint256 price) {
		// exchange = the ExchangeV2Pair. check denomination token (USE create2 check?!) check gas cost
		require((_uniswapV2Pair.token0() == _denominationToken) || (_uniswapV2Pair.token1() == _denominationToken), "UniswapAdapter: denominationToken invalid");
        bool _denominationTokenIs0 =  (_uniswapV2Pair.token0() == _denominationToken) ? true : false;			
		return getPriceRaw(_uniswapV2Pair, _denominationTokenIs0, _minBlocksBack, _maxBlocksBack, _proofData, _expiryTimestamp);
	}


     /**
     * @notice get the price for the asset 
     * @dev invokes UniswapOracle.getPrice()
     * @param _uniswapV2Pair Uniswap v2 pair involving the asset corresponding to _expiryTimestamp
     * @param _denominationTokenIs0 if token0 is the asset's denomination in the pair
     * @param _minBlocksBack minimal number of blocks before the current block
     * @param _maxBlocksBack maximal number of blocks before the current block
     * @param _proofData storage proof data
     * @param _expiryTimestamp expiry to set a price for
     * @return price of the asset in USD, scaled by 1e8
     */
    function getPriceRaw(IUniswapV2Pair _uniswapV2Pair, bool _denominationTokenIs0, uint8 _minBlocksBack, uint8 _maxBlocksBack, ProofData memory _proofData, uint256 _expiryTimestamp) public view returns (uint256 price) {
		uint256 historicBlockTimestamp;
		uint256 historicPriceCumulativeLast;
		{
			uint112 reserve0;
			uint112 reserve1;
			uint256 reserveTimestamp;
			(historicBlockTimestamp, blockNumber, historicPriceCumulativeLast, reserve0, reserve1, reserveTimestamp) 
            = verifyBlockAndExtractReserveData(_uniswapV2Pair, _minBlocksBack, _maxBlocksBack,
             _denominationTokenIs0 ? token1Slot : token0Slot, _proofData);

			uint256 secondsBetweenReserveUpdateAndHistoricBlock = historicBlockTimestamp - reserveTimestamp;
			// bring old record up-to-date, in case there was no cumulative update in provided historic block itself
			if (secondsBetweenReserveUpdateAndHistoricBlock > 0) {
				historicPriceCumulativeLast += secondsBetweenReserveUpdateAndHistoricBlock * uint(UQ112x112
					.encode(_denominationTokenIs0 ? reserve0 : reserve1)
					.uqdiv(_denominationTokenIs0 ? reserve1 : reserve0)
				);
			}
		}
		uint256 secondsBetweenProvidedBlockAndExpiry = _expiryTimestamp - historicBlockTimestamp;
		price = (getSpecificTimePriceCumulativeLast(_uniswapV2Pair, _denominationTokenIs0, _expiryTimestamp) - historicPriceCumulativeLast) / secondsBetweenProvidedBlockAndExpiry;
		return price;
	}

    /**
     * @notice get the price for the asset 
     * @dev invokes UniswapOracle.getPrice()
     * @param _uniswapV2Pair Uniswap v2 pair involving the asset corresponding to _expiryTimestamp
     * @param _denomination token for the asset in the pair
     * @param _minBlocksBack minimal number of blocks before the current block
     * @param _maxBlocksBack maximal number of blocks before the current block
     * @param _proofData storage proof data
     * @return price of the asset in USD, scaled by 1e8
     */
    function getSpecificTimePriceCumulativeLast(IUniswapV2Pair _uniswapV2Pair, bool _denominationTokenIs0, uint256 _expiryTimestamp) public view returns (uint256 priceCumulativeLast) {
		(uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = _uniswapV2Pair.getReserves();
		priceCumulativeLast = _denominationTokenIs0 ? _uniswapV2Pair.price1CumulativeLast() : _uniswapV2Pair.price0CumulativeLast();
		uint256 timeElapsed = _expiryTimestamp - blockTimestampLast;
		priceCumulativeLast += timeElapsed * uint(UQ112x112
			.encode(_denominationTokenIs0 ? reserve0 : reserve1)
			.uqdiv(_denominationTokenIs0 ? reserve1 : reserve0)
		);
	}

}
