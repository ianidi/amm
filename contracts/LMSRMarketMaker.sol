pragma solidity ^0.5.0;
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Fixed192x64Math} from "./Fixed192x64Math.sol";
import {MarketMaker} from "./MarketMaker.sol";

/// @title LMSR market maker contract - Calculates share prices based on share distribution and initial funding
/// @author Alan Lu - <alan.lu@gnosis.pm>
contract LMSRMarketMaker is MarketMaker {
    using SafeMath for uint256;

    /*
     *  Constants
     */
    uint256 constant ONE = 0x10000000000000000;
    int256 constant EXP_LIMIT = 3394200909562557497344;

    /// @dev Calculates the net cost for executing a given trade.
    /// @param outcomeTokenAmounts Amounts of outcome tokens to buy from the market. If an amount is negative, represents an amount to sell to the market.
    /// @return Net cost of trade. If positive, represents amount of collateral which would be paid to the market for the trade. If negative, represents amount of collateral which would be received from the market for the trade.
    function calcNetCost(int256[] memory outcomeTokenAmounts)
        public
        view
        returns (int256 netCost)
    {
        require(outcomeTokenAmounts.length == atomicOutcomeSlotCount);

        int256[] memory otExpNums = new int256[](atomicOutcomeSlotCount);
        for (uint256 i = 0; i < atomicOutcomeSlotCount; i++) {
            int256 balance =
                int256(
                    pmSystem.balanceOf(
                        address(this),
                        generateAtomicPositionId(i)
                    )
                );
            require(balance >= 0);
            otExpNums[i] = outcomeTokenAmounts[i].sub(balance);
        }

        int256 log2N =
            Fixed192x64Math.binaryLog(
                atomicOutcomeSlotCount * ONE,
                Fixed192x64Math.EstimationMode.UpperBound
            );

        (uint256 sum, int256 offset, ) =
            sumExpOffset(
                log2N,
                otExpNums,
                0,
                Fixed192x64Math.EstimationMode.UpperBound
            );
        netCost = Fixed192x64Math.binaryLog(
            sum,
            Fixed192x64Math.EstimationMode.UpperBound
        );
        netCost = netCost.add(offset);
        netCost = (netCost.mul(int256(ONE)) / log2N).mul(int256(funding));

        // Integer division for negative numbers already uses ceiling,
        // so only check boundary condition for positive numbers
        if (netCost <= 0 || (netCost / int256(ONE)) * int256(ONE) == netCost) {
            netCost /= int256(ONE);
        } else {
            netCost = netCost / int256(ONE) + 1;
        }
    }

    /// @dev Returns marginal price of an outcome
    /// @param outcomeTokenIndex Index of outcome to determine marginal price of
    /// @return Marginal price of an outcome as a fixed point number
    function calcMarginalPrice(uint8 outcomeTokenIndex)
        public
        view
        returns (uint256 price)
    {
        int256[] memory negOutcomeTokenBalances =
            new int256[](atomicOutcomeSlotCount);
        for (uint256 i = 0; i < atomicOutcomeSlotCount; i++) {
            int256 negBalance =
                -int256(
                    pmSystem.balanceOf(
                        address(this),
                        generateAtomicPositionId(i)
                    )
                );
            require(negBalance <= 0);
            negOutcomeTokenBalances[i] = negBalance;
        }

        int256 log2N =
            Fixed192x64Math.binaryLog(
                negOutcomeTokenBalances.length * ONE,
                Fixed192x64Math.EstimationMode.Midpoint
            );
        // The price function is exp(quantities[i]/b) / sum(exp(q/b) for q in quantities)
        // To avoid overflow, calculate with
        // exp(quantities[i]/b - offset) / sum(exp(q/b - offset) for q in quantities)
        (uint256 sum, , uint256 outcomeExpTerm) =
            sumExpOffset(
                log2N,
                negOutcomeTokenBalances,
                outcomeTokenIndex,
                Fixed192x64Math.EstimationMode.Midpoint
            );
        return outcomeExpTerm / (sum / ONE);
    }

    /*
     *  Private functions
     */
    /// @dev Calculates sum(exp(q/b - offset) for q in quantities), where offset is set
    ///      so that the sum fits in 248-256 bits
    /// @param log2N Binary logarithm of the number of outcomes
    /// @param otExpNums Numerators of the exponents, denoted as q in the aforementioned formula
    /// @param outcomeIndex Index of exponential term to extract (for use by marginal price function)
    /// @return A result structure composed of the sum, the offset used, and the summand associated with the supplied index
    function sumExpOffset(
        int256 log2N,
        int256[] memory otExpNums,
        uint8 outcomeIndex,
        Fixed192x64Math.EstimationMode estimationMode
    )
        private
        view
        returns (
            uint256 sum,
            int256 offset,
            uint256 outcomeExpTerm
        )
    {
        // Naive calculation of this causes an overflow
        // since anything above a bit over 133*ONE supplied to exp will explode
        // as exp(133) just about fits into 192 bits of whole number data.

        // The choice of this offset is subject to another limit:
        // computing the inner sum successfully.
        // Since the index is 8 bits, there has to be 8 bits of headroom for
        // each summand, meaning q/b - offset <= exponential_limit,
        // where that limit can be found with `mp.floor(mp.log((2**248 - 1) / ONE) * ONE)`
        // That is what EXP_LIMIT is set to: it is about 127.5

        // finally, if the distribution looks like [BIG, tiny, tiny...], using a
        // BIG offset will cause the tiny quantities to go really negative
        // causing the associated exponentials to vanish.

        require(log2N >= 0 && int256(funding) >= 0);
        offset = Fixed192x64Math.max(otExpNums);
        offset = offset.mul(log2N) / int256(funding);
        offset = offset.sub(EXP_LIMIT);
        uint256 term;
        for (uint8 i = 0; i < otExpNums.length; i++) {
            term = Fixed192x64Math.pow2(
                (otExpNums[i].mul(log2N) / int256(funding)).sub(offset),
                estimationMode
            );
            if (i == outcomeIndex) outcomeExpTerm = term;
            sum = sum.add(term);
        }
    }
}
