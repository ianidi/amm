pragma solidity >=0.5.1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {CTHelpers} from "./CTHelpers.sol";
import {ConstructedCloneFactory} from "./ConstructedCloneFactory.sol";
import {LMSRMarketMaker} from "./LMSRMarketMaker.sol";
import {Whitelist} from "./Whitelist.sol";
import {ERC1155TokenReceiver} from "./ERC1155/ERC1155TokenReceiver.sol";

contract LMSRMarketMakerData {
    address internal _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    bytes4 internal constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) internal _supportedInterfaces;

    uint64 constant FEE_RANGE = 10**18;
    event AMMCreated(uint256 initialFunding);
    ConditionalTokens internal pmSystem;
    IERC20 internal collateralToken;
    bytes32[] internal conditionIds;
    uint256 internal atomicOutcomeSlotCount;
    uint64 internal fee;
    uint256 internal funding;
    Stage internal stage;
    Whitelist internal whitelist;

    uint256[] internal outcomeSlotCounts;
    bytes32[][] internal collectionIds;
    uint256[] internal positionIds;

    enum Stage {Running, Paused, Closed}
}

contract LMSRMarketMakerFactory is
    ConstructedCloneFactory,
    LMSRMarketMakerData
{
    event LMSRMarketMakerCreation(
        address indexed creator,
        LMSRMarketMaker lmsrMarketMaker,
        ConditionalTokens pmSystem,
        IERC20 collateralToken,
        bytes32[] conditionIds,
        uint64 fee,
        uint256 funding
    );

    LMSRMarketMaker public implementationMaster;

    constructor() public {
        implementationMaster = new LMSRMarketMaker();
    }

    function cloneConstructor(bytes calldata consData) external {
        (
            ConditionalTokens _pmSystem,
            IERC20 _collateralToken,
            bytes32[] memory _conditionIds,
            uint64 _fee,
            Whitelist _whitelist
        ) =
            abi.decode(
                consData,
                (ConditionalTokens, IERC20, bytes32[], uint64, Whitelist)
            );

        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);

        _supportedInterfaces[_INTERFACE_ID_ERC165] = true;
        _supportedInterfaces[
            ERC1155TokenReceiver(0).onERC1155Received.selector ^
                ERC1155TokenReceiver(0).onERC1155BatchReceived.selector
        ] = true;

        // Validate inputs
        require(address(_pmSystem) != address(0) && _fee < FEE_RANGE);
        pmSystem = _pmSystem;
        collateralToken = _collateralToken;
        conditionIds = _conditionIds;
        fee = _fee;
        whitelist = _whitelist;

        atomicOutcomeSlotCount = 1;
        outcomeSlotCounts = new uint256[](conditionIds.length);
        for (uint256 i = 0; i < conditionIds.length; i++) {
            uint256 outcomeSlotCount =
                pmSystem.getOutcomeSlotCount(conditionIds[i]);
            atomicOutcomeSlotCount *= outcomeSlotCount;
            outcomeSlotCounts[i] = outcomeSlotCount;
        }
        require(atomicOutcomeSlotCount > 1, "conditions must be valid");

        collectionIds = new bytes32[][](conditionIds.length);
        _recordCollectionIDsForAllConditions(conditionIds.length, bytes32(0));

        stage = Stage.Paused;
        emit AMMCreated(funding);
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

    function createLMSRMarketMaker(
        ConditionalTokens pmSystem,
        IERC20 collateralToken,
        bytes32[] calldata conditionIds,
        uint64 fee,
        Whitelist whitelist,
        uint256 funding
    ) external returns (LMSRMarketMaker lmsrMarketMaker) {
        lmsrMarketMaker = LMSRMarketMaker(
            createClone(
                address(implementationMaster),
                abi.encode(
                    pmSystem,
                    collateralToken,
                    conditionIds,
                    fee,
                    whitelist
                )
            )
        );
        collateralToken.transferFrom(msg.sender, address(this), funding);
        collateralToken.approve(address(lmsrMarketMaker), funding);
        lmsrMarketMaker.changeFunding(int256(funding));
        lmsrMarketMaker.resume();
        lmsrMarketMaker.transferOwnership(msg.sender);
        emit LMSRMarketMakerCreation(
            msg.sender,
            lmsrMarketMaker,
            pmSystem,
            collateralToken,
            conditionIds,
            fee,
            funding
        );
    }
}
