pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";

/// @title Whitelist for adding/removing users from a whitelist
/// @author Anton Shtylman - @InfiniteStyles
contract Whitelist is Ownable {
    event UsersAddedToWhitelist(address[] users);
    event UsersRemovedFromWhitelist(address[] users);

    mapping(address => bool) public isWhitelisted;

    function addToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            isWhitelisted[users[i]] = true;
        }
        emit UsersAddedToWhitelist(users);
    }

    function removeFromWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            isWhitelisted[users[i]] = false;
        }
        emit UsersRemovedFromWhitelist(users);
    }
}
