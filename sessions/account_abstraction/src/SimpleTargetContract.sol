// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SimpleTargetContract
 * @author Ethereum Córdoba 
 * @notice A minimal contract for testing AA wallet interactions.
 * Allows a caller (like your WalletContract) to set a value.
 */
contract SimpleTargetContract {

    uint256 public storedValue; // the value set by the last caller
    address public lastSetter;  // the address that last called setValue

    // event emitted when the value is successfully set
    event ValueSet(address indexed setter, uint256 indexed newValue);

    /**
     * @notice Sets a new value in the contract's storage.
     * Can be called by any address, including your smart wallet proxy.
     * @param _newValue The value to store.
     */
    function setValue(uint256 _newValue) external {
        // Store the passed value
        storedValue = _newValue;
        // Record the immediate caller's address. When called via your AA wallet's
        // execute function, msg.sender here will be the address of your
        // WalletContract proxy instance.
        lastSetter = msg.sender;
        // Emit an event to log the change
        emit ValueSet(msg.sender, _newValue);
    }

    /**
     * @notice Allows the contract to receive Ether.
     */
    receive() external payable {}
}
