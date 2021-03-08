// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import {OracleInterface} from "../interfaces/OracleInterface.sol";
import {OpynPricerInterface} from "../interfaces/OpynPricerInterface.sol";
import {SafeMath} from "../packages/oz/SafeMath.sol";
import {UniswapAdapterInterface} from "../external/adapter/UniswapAdapterInterface.sol";

/**
 * @notice A Pricer contract for one asset as reported by Uniswap
 */
contract UniswapPricer is OpynPricerInterface {
    using SafeMath for uint256;

    /// @notice the opyn oracle address
    OracleInterface public oracle;
    /// @notice the uniswap adapter for an asset
    UniswapAdapterInterface public adapter;
    /// @notice asset that this pricer will a get price for
    address public asset;
    /// @notice bot address that is allowed to call setExpiryPriceInOracle
    address public bot;

    IUniswapV2Pair public uniswapV2Pair;
    address public denominationToken;
    uint8 public minBlocksBack;
    uint8 public maxBlocksBack;
    UniswapOracle.ProofData public proofData;

    uint public constant ONE_E_8 = 100000000;
    /**
     * @param _bot priveleged address that can call setExpiryPriceInOracle
     * @param _asset asset that this pricer will get a price for
     * @param _oracle Opyn Oracle address
     * @param _uniswapV2Pair Uniswap v2 pair involving the asset
     * @param _minBlocksBack minimal number of blocks before the current block
     * @param _maxBlocksBack maximal number of blocks before the current block
     * @param _proofData storage proof data
     * @param _adapter UniswapOracle based contract for the asset
     */
    constructor(
        address _bot,
        address _asset,
        address _oracle,
        IUniswapV2Pair _uniswapV2Pair,
        uint8 _minBlocksBack,
        uint8 _maxBlocksBack,
        UniswapOracle.ProofData _proofData, 
        UniswapAdapterInterface _adapter
    ) public {
        require(_bot != address(0), "UniswapPricer: Cannot set 0 address as bot");
        require((_uniswapV2Pair.token0() == _asset || _uniswapV2Pair.token1() == _asset), "UniswapPricer: Uniswap V2 pair does not include inquired asset");
          
        bot = _bot;
        asset = _asset;
        oracle = OracleInterface(_oracle);
        uniswapV2Pair = _uniswapV2Pair;
        denominationToken = (_uniswapV2Pair.token0() == _asset) ? _uniswapV2Pair.token1() : _uniswapV2Pair.token0();
        minBlocksBack = _minBlocksBack;
        maxBlocksBack = _maxBlocksBack;
        proofData = _proofData;
        adapter = _adapter;
    }

    function setProofData(UniswapOracle.ProofData _proofData) external{
        proofData = _proofData;
    }

    
    function setUniswapV2Pair(IUniswapV2Pair _uniswapV2Pair) external{
        uniswapV2Pair = _uniswapV2Pair;
    }

    /**
     * @notice modifier to check if sender address is equal to bot address
     */
    modifier onlyBot() {
        require(msg.sender == bot, "UniswapPricer: unauthorized sender");

        _;
    }

    /**
     * @notice get the live price for the asset
     * @dev overides the getPrice function in OpynPricerInterface
     * @return price of the asset in USD, scaled by 1e8
     */
    function getPrice() external override view returns (uint256) {
        uint256 price = adapter.getPrice(uniswapV2Pair, denominationToken, minBlocksBack, maxBlocksBack, proofData);
        return uint256(price)*ONE_E_8;
    }

    /**
     * @notice set the expiry price in the oracle, can only be called by Bot address     
     * @param _expiryTimestamp expiry to set a price for   
     */
    function setExpiryPriceInOracle(uint256 _expiryTimestamp, uint256 _blockNumber) external onlyBot {         
        bytes32 storageRootHash; 
        uint256 blockNumber; 
        uint256 blockTimestamp;
        (storageRootHash, blockNumber, blockTimestamp) = getAccountStorageRoot(uniswapV2Pair, proofData);
        require (blockNumber <= _blockNumber - minBlocksBack, "Proof does not span enough blocks");
		require (blockNumber >= _blockNumber - maxBlocksBack, "Proof spans too many blocks");
        require(_expiryTimestamp > blockTimestamp, "UniswapPricer: invalid proof data");

        uint256 price = adapter.getPriceForSpecificTimePoint(uniswapV2Pair, denominationToken, minBlocksBack, maxBlocksBack, proofData, _expiryTimestamp) * ONE_E_8;
        oracle.setExpiryPrice(asset, _expiryTimestamp, price);
    }
}
