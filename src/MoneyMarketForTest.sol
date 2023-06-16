// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

contract MoneyMarketForTest {
  using SafeTransferLib for ERC20;

  address internal immutable owner;
  address internal immutable bank;
  uint256 internal interestRatePerSec;

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
      getNonCollatAccountDebt[bank][token] * timePassed * interestRatePerSec / 1e18;
    lastAccrualOf[token] = block.timestamp;
  }

  function nonCollatBorrow(address token, uint256 amount) external onlyBank {
    accrueInterest(token);
    getNonCollatAccountDebt[bank][token] += amount;
    ERC20(token).safeTransfer(msg.sender, amount);
  }

  function nonCollatRepay(address, address token, uint256 amount) external {
    accrueInterest(token);
    ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    getNonCollatAccountDebt[bank][token] -= amount;
  }

  function withdrawTokens(address[] calldata tokens) external onlyOwner {
    uint256 len = tokens.length;
    ERC20 token;
    for (uint256 i; i < len;) {
      token = ERC20(tokens[i]);
      token.safeTransfer(owner, token.balanceOf(address(this)));
      unchecked {
        ++i;
      }
    }
  }

  function withdrawETH() external onlyOwner {
    SafeTransferLib.safeTransferETH(owner, address(this).balance);
  }

  function injectFund(address _token, uint256 _amount) external {
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
  }

  function setInterestRatePerSec(uint256 newRate) external onlyOwner {
    interestRatePerSec = newRate;
  }
}
