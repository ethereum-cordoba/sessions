// SPDX-License-Identifier: MIT
// https://github.com/JuliaGastellu/simple-defi-farm/commit/afae9848d66c51d0ea9c36cedd163fa8420eb0ce
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    constructor(
        address initialOwner
    )
        ERC20("LP Token", "LPT") 
        Ownable(initialOwner) 
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
