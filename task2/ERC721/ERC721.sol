// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage {
    uint256 private _nextTokenId = 1;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    // 允许任何用户铸造到指定地址，并设置元数据链接（tokenURI）
    function mintNFT(address recipient, string memory tokenURI_) external returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        _nextTokenId += 1;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        return tokenId;
    }
}