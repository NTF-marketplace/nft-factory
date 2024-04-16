// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NewCollection.sol";

contract ScamFactory {
    address[] public collections;
    
    // event CollectionCreated(address collectionAddress, string name, string symbol);

    function createCollection(string memory name, string memory symbol, string[] memory tokenURIs) public {
        NewCollection newCollection = new NewCollection(name, symbol);
        collections.push(address(newCollection));
        // emit CollectionCreated(address(newCollection), name, symbol);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            newCollection.mintNFT(msg.sender, i, tokenURIs[i]);
        }
    }

    function getCollections() public view returns (address[] memory) {
        return collections;
    }
}