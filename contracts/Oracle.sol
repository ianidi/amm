pragma solidity >=0.5.1;

interface IConditionalTokens {
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts)
        external;
}

interface IOracle {
    function getContentHash(bytes32 questionId) external view returns (bytes32);

    function getOpeningTS(bytes32 questionId) external view returns (uint32);

    function resultFor(bytes32 questionId) external view returns (bytes32);
}

contract OracleProxy {
    IConditionalTokens public conditionalTokens;
    IOracle public oracle;
    uint256 public nuancedBinaryTemplateId;

    constructor(
        IConditionalTokens _conditionalTokens,
        IOracle _oracle,
        uint256 _nuancedBinaryTemplateId
    ) public {
        conditionalTokens = _conditionalTokens;
        oracle = _oracle;
        nuancedBinaryTemplateId = _nuancedBinaryTemplateId;
    }

    function resolve(
        bytes32 questionId,
        uint256 templateId,
        string calldata question,
        uint256 numOutcomes
    ) external {
        // check that the given templateId and question match the questionId
        bytes32 contentHash =
            keccak256(
                abi.encodePacked(
                    templateId,
                    oracle.getOpeningTS(questionId),
                    question
                )
            );
        require(
            contentHash == oracle.getContentHash(questionId),
            "Content hash mismatch"
        );

        uint256[] memory payouts;

        if (templateId == 0 || templateId == 2) {
            // binary or single-select
            payouts = getSingleSelectPayouts(questionId, numOutcomes);
        } else if (templateId == nuancedBinaryTemplateId) {
            payouts = getNuancedBinaryPayouts(questionId, numOutcomes);
        } else {
            revert("Unknown templateId");
        }

        conditionalTokens.reportPayouts(questionId, payouts);
    }

    function getSingleSelectPayouts(bytes32 questionId, uint256 numOutcomes)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[] memory payouts = new uint256[](numOutcomes);

        uint256 answer = uint256(oracle.resultFor(questionId));

        if (answer == uint256(-1)) {
            for (uint256 i = 0; i < numOutcomes; i++) {
                payouts[i] = 1;
            }
        } else {
            require(
                answer < numOutcomes,
                "Answer must be between 0 and numOutcomes"
            );
            payouts[answer] = 1;
        }

        return payouts;
    }

    function getNuancedBinaryPayouts(bytes32 questionId, uint256 numOutcomes)
        internal
        view
        returns (uint256[] memory)
    {
        require(numOutcomes == 2, "Number of outcomes expected to be 2");
        uint256[] memory payouts = new uint256[](2);

        uint256 answer = uint256(oracle.resultFor(questionId));

        if (answer == uint256(-1)) {
            payouts[0] = 1;
            payouts[1] = 1;
        } else {
            require(answer < 5, "Answer must be between 0 and 4");
            payouts[0] = 4 - answer;
            payouts[1] = answer;
        }

        return payouts;
    }
}
