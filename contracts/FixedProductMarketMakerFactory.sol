pragma solidity ^0.5.0;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {CTHelpers} from "./CTHelpers.sol";
import {ConstructedCloneFactory} from "./ConstructedCloneFactory.sol";
import {
    FixedProductMarketMaker,
    FixedProductMarketMakerData
} from "./FixedProductMarketMaker.sol";
import {ERC1155TokenReceiver} from "./ERC1155/ERC1155TokenReceiver.sol";

contract FixedProductMarketMakerFactory is
    ConstructedCloneFactory,
    FixedProductMarketMakerData
{
    event FixedProductMarketMakerCreation(
        address indexed creator,
        FixedProductMarketMaker fixedProductMarketMaker,
        ConditionalTokens indexed conditionalTokens,
        IERC20 indexed collateralToken,
        bytes32[] conditionIds,
        uint256 fee,
        int256 initialPrice,
        uint256 created,
        uint256 duration,
        int256 baseCurrency
    );

    FixedProductMarketMaker public implementationMaster;
    AggregatorV3Interface internal priceFeed;

    constructor() public {
        implementationMaster = new FixedProductMarketMaker();
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice(AggregatorV3Interface feed) public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = feed.latestRoundData();
        return price;
    }

    function cloneConstructor(bytes calldata consData) external {
        (
            ConditionalTokens _conditionalTokens,
            IERC20 _collateralToken,
            bytes32[] memory _conditionIds,
            uint256 _fee,
            int256 _initialPrice,
            uint256 _created,
            uint256 _duration,
            int256 _baseCurrency
        ) =
            abi.decode(
                consData,
                (ConditionalTokens, IERC20, bytes32[], uint256, int256, uint256, uint256, int256)
            );

        _supportedInterfaces[_INTERFACE_ID_ERC165] = true;
        _supportedInterfaces[
            ERC1155TokenReceiver(0).onERC1155Received.selector ^
                ERC1155TokenReceiver(0).onERC1155BatchReceived.selector
        ] = true;

        conditionalTokens = _conditionalTokens;
        collateralToken = _collateralToken;
        conditionIds = _conditionIds;
        fee = _fee;
        initialPrice = _initialPrice;
        created = _created;
        duration = _duration;
        baseCurrency = _baseCurrency;

        uint256 atomicOutcomeSlotCount = 1;
        outcomeSlotCounts = new uint256[](conditionIds.length);
        for (uint256 i = 0; i < conditionIds.length; i++) {
            uint256 outcomeSlotCount =
                conditionalTokens.getOutcomeSlotCount(conditionIds[i]);
            atomicOutcomeSlotCount *= outcomeSlotCount;
            outcomeSlotCounts[i] = outcomeSlotCount;
        }
        require(atomicOutcomeSlotCount > 1, "conditions must be valid");

        collectionIds = new bytes32[][](conditionIds.length);
        _recordCollectionIDsForAllConditions(conditionIds.length, bytes32(0));
        require(
            positionIds.length == atomicOutcomeSlotCount,
            "position IDs construction failed!?"
        );
    }

    function _recordCollectionIDsForAllConditions(
        uint256 conditionsLeft,
        bytes32 parentCollectionId
    ) private {
        if (conditionsLeft == 0) {
            positionIds.push(
                CTHelpers.getPositionId(collateralToken, parentCollectionId)
            );
            return;
        }

        conditionsLeft--;

        uint256 outcomeSlotCount = outcomeSlotCounts[conditionsLeft];

        collectionIds[conditionsLeft].push(parentCollectionId);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            _recordCollectionIDsForAllConditions(
                conditionsLeft,
                CTHelpers.getCollectionId(
                    parentCollectionId,
                    conditionIds[conditionsLeft],
                    1 << i
                )
            );
        }
    }

    function createFixedProductMarketMaker(
        ConditionalTokens conditionalTokens,
        IERC20 collateralToken,
        bytes32[] calldata conditionIds,
        uint256 fee,
        uint256 duration,
        int256 baseCurrency
    ) external returns (FixedProductMarketMaker) {

        uint256 created;
        int256 initialPrice;
        //////////////////////////////////////////////////// 
        initialPrice = getLatestPrice(AggregatorV3Interface(
            0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
        ));

        created = now;

        FixedProductMarketMaker fixedProductMarketMaker =
            FixedProductMarketMaker(
                createClone(
                    address(implementationMaster),
                    abi.encode(
                        conditionalTokens,
                        collateralToken,
                        conditionIds,
                        fee,
                        initialPrice,
                        created,
                        duration,
                        baseCurrency
                    )
                )
            );
        emit FixedProductMarketMakerCreation(
            msg.sender,
            fixedProductMarketMaker,
            conditionalTokens,
            collateralToken,
            conditionIds,
            fee,
            initialPrice,
            created,
            duration,
            baseCurrency
        );
        return fixedProductMarketMaker;
    }
}