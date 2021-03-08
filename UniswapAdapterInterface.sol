/**
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.6.10;

//pragma solidity 0.6.8;

interface UniswapAdapterInterface {
    function getPrice(IUniswapV2Pair _exchange, address _denominationToken, uint8 _minBlocksBack, uint8 _maxBlocksBack, UniswapOracle.ProofData memory _proofData) public returns (uint256 price) ;
		
    function getPriceForSpecificTimePoint(IUniswapV2Pair _uniswapV2Pair, address _denominationToken, uint8 _minBlocksBack, uint8 _maxBlocksBack, ProofData memory _proofData, uint256 _expiryTimestamp) public view returns (uint256 price) ;
		

    function getPriceRaw(IUniswapV2Pair _uniswapV2Pair, bool _denominationTokenIs0, uint8 _minBlocksBack, uint8 _maxBlocksBack, ProofData memory _proofData, uint256 _expiryTimestamp) public view returns (uint256 price) ;
    
    function getSpecificTimePriceCumulativeLast(IUniswapV2Pair _uniswapV2Pair, bool _denominationTokenIs0, uint256 _expiryTimestamp) public view returns (uint256 priceCumulativeLast) ;

}
