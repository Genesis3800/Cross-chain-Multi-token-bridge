// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@layerzero-contracts/lzApp/NonblockingLzApp.sol";
import "@chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title LayerZeroSwap_ScrollSepolia
 * @dev This contract sends a cross-chain message from ScrollSepolia to Mumbai to transfer MATIC in return for deposited ETH.
 */
contract LayerZeroSwap_ScrollSepolia is NonblockingLzApp {

    // State variables for the contract
    address payable deployer;    
    uint16 public destChainId;
    bytes payload;    
    address payable contractAddress = payable(address(this));

    // Instance of the LayerZero endpoint
    ILayerZeroEndpoint public immutable endpoint;
 
    // Instance of the Chainlink price feed contract
    AggregatorV3Interface internal immutable ethUsdPriceFeed;

    /**
     * @dev Constructor that initializes the contract with the LayerZero endpoint.
     * @param _sourceLzEndpoint Address of the LayerZero endpoint on ScrollSepolia testnet:
     * 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3
     * @param _ethUsdPriceFeed Chainlink price feed address for ETH/USD feed ScrollSepolia testnet:
     * 0x59F1ec1f10bD7eD9B938431086bC1D9e233ECf41
     * @notice The destChainId is being hardcoded under an if condition. This is an innefficient approach.
     * Not fit for production. This is only for demo purposes.
     */
    constructor(address _sourceLzEndpoint, address _ethUsdPriceFeed) NonblockingLzApp(_sourceLzEndpoint) {
        deployer = payable(msg.sender);
        endpoint = ILayerZeroEndpoint(_sourceLzEndpoint);
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);

        // If Source == ScrollSepolia, then Destination Chain = Mumbai
        if (_sourceLzEndpoint == 0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3) destChainId = 10109;

        // If Source == Mumbai, then Destination Chain = ScrollSepolia
        if (_sourceLzEndpoint == 0xf69186dfBa60DdB133E91E9A4B5673624293d8F8) destChainId = 10214;
    }

    /**
     * @dev Allows users to swap to MATIC.
     * @param Receiver Address of the receiver.
     */
    function swapTo_MATIC(address Receiver) public payable {
        require(msg.value >= 1 ether, "Please send at least 1 ETH");

        bytes memory trustedRemote = trustedRemoteLookup[destChainId];
        require(trustedRemote.length != 0, "LzApp: destination chain is not a trusted source");
        _checkPayloadSize(destChainId, payload.length);

        //Getting the latest price of ETH/USD
        (,int ETH_USD,,,) =  ethUsdPriceFeed.latestRoundData();
        int value = (int256(msg.value)*ETH_USD)/(10**18);

        // The message is encoded as bytes and stored in the "payload" variable.
        payload = abi.encode(Receiver, value);

        endpoint.send{value: 15 ether}(destChainId, trustedRemote, payload, contractAddress, address(0x0), bytes(""));
    }

    /**
     * @dev Internal function to handle incoming LayerZero messages.
     */
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        (address Receiver , int Value) = abi.decode(_payload, (address, int));
        address payable recipient = payable(Receiver);        
        recipient.transfer(uint(Value));
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
