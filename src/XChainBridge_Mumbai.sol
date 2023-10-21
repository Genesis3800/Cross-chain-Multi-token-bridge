// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@layerzero-contracts/lzApp/NonblockingLzApp.sol";
import "@chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title LayerZeroSwap_Mumbai
 * @dev This contract sends a cross-chain message from Mumbai to Sepolia to transfer ETH in return for deposited MATIC.
 */
contract LayerZeroSwap_Mumbai is NonblockingLzApp {

    // State variables for the contract    
    uint16 public destChainId;
    bytes payload;
    address payable deployer;
    address payable contractAddress = payable(address(this));

    // Instance of the LayerZero endpoint
    ILayerZeroEndpoint public immutable endpoint;

    // Instance of the Chainlink price feed contract
    AggregatorV3Interface internal immutable priceFeed;

    /**
     * @dev Constructor that initializes the contract with the LayerZero endpoint.
     * @param _sourceLzEndpoint Address of the LayerZero endpoint on Mumbai testnet:
     * 0xf69186dfBa60DdB133E91E9A4B5673624293d8F8
     * @param _priceFeed Chainlink price feed address for MATIC/USD feed on Mumbai testnet:
     * 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada
     * @notice The destChainId is being hardcoded under an if condition. This is an innefficient approach.
     * Not fit for production. This is only for demo purposes.
     */
    constructor(address _sourceLzEndpoint, address _priceFeed) NonblockingLzApp(_sourceLzEndpoint) {
        deployer = payable(msg.sender);
        endpoint = ILayerZeroEndpoint(_sourceLzEndpoint);
        priceFeed = AggregatorV3Interface(_priceFeed);

        // If Source == Sepolia, then Destination Chain = Mumbai
        if (_sourceLzEndpoint == 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3) destChainId = 10109;

        // If Source == Mumbai, then Destination Chain = Sepolia
        if (_sourceLzEndpoint == 0xf69186dfBa60DdB133E91E9A4B5673624293d8F8) destChainId = 10214;
    }

    /**
     * @dev Allows users to swap to ETH.
     * @param Receiver Address of the receiver.
     */
    function swapTo_ETH(address Receiver) public payable {
        require(msg.value >= 1 ether, "Please send at least 1 MATIC");
        uint value = msg.value;

        bytes memory trustedRemote = trustedRemoteLookup[destChainId];
        require(trustedRemote.length != 0, "LzApp: destination chain is not a trusted source");
        _checkPayloadSize(destChainId, payload.length);

        int price;
        (, price,,,) = priceFeed.latestRoundData();

        // The message is encoded as bytes and stored in the "payload" variable.
        payload = abi.encode(Receiver, value);

        endpoint.send{value: 15 ether}(destChainId, trustedRemote, payload, contractAddress, address(0x0), bytes(""));
    }

    /**
     * @dev Internal function to handle incoming LayerZero messages.
     */
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {

        (address Receiver , uint Value) = abi.decode(_payload, (address, uint));
        address payable recipient = payable(Receiver);        
        recipient.transfer(Value);
    }

    // Fallback function to receive ether
    receive() external payable {}

    /**
     * @dev Allows the owner to withdraw all funds from the contract.
     */
    function withdrawAll() external onlyOwner {
        deployer.transfer(address(this).balance);
    }
}
