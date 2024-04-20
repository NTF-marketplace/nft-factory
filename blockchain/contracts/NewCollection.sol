// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NewCollection is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol, address initialOwner) ERC721(name, symbol) Ownable(initialOwner) {
        _tokenIdCounter = 0;
    }

    function mintNFT(address recipient, string memory tokenURI) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _tokenIdCounter++;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
}