// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";

contract MoneyMarketForTest {
  address internal immutable owner;
  address internal immutable bank;
  uint256 internal constant INTEREST_RATE_PER_SEC = 2536783358; // 1e18 = 100% at 8% per year

  mapping(address => mapping(address => uint256)) public getNonCollatAccountDebt;
  mapping(address => uint256) public lastAccrualOf;

  modifier onlyBank() {
    require(msg.sender == bank, "NB");
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "NO");
    _;
  }

  constructor(address _bank) {
    owner = msg.sender;
    bank = _bank;
  }

  function accrueInterest(address token) public {
    uint256 timePassed = block.timestamp - lastAccrualOf[token];
    if (timePassed == 0) return;
    getNonCollatAccountDebt[bank][token] +=
      getNonCollatAccountDebt[bank][token] * timePassed * INTEREST_RATE_PER_SEC / 1e18;
    lastAccrualOf[token] = block.timestamp;
  }

  function nonCollatBorrow(address token, uint256 amount) external onlyBank {
    accrueInterest(token);
    getNonCollatAccountDebt[bank][token] += amount;
    IERC20(token).transfer(msg.sender, amount);
  }

  function nonCollatRepay(address, address token, uint256 amount) external {
    accrueInterest(token);
    IERC20(token).transferFrom(msg.sender, address(this), amount);
    getNonCollatAccountDebt[bank][token] -= amount;
  }

  function withdrawTokens(address[] calldata tokens) external onlyOwner {
    uint256 len = tokens.length;
    IERC20 token;
    for (uint256 i; i < len;) {
      token = IERC20(tokens[i]);
      token.transfer(owner, token.balanceOf(address(this)));
      unchecked {
        ++i;
      }
    }
  }
}
