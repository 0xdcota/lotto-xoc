// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

contract Lottery is Ownable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    event PlayerEnter(address indexed player);
    event WinnerPicked(address winner, uint256 amount);
    event EntryFeeChange(uint256 newEntryFee);

    address public immutable tokenAddress;
    uint256 public entryFee;
    uint256 public lastWinnerBlock;
    address[] public players;

    uint256 private constant PRECISION = 1e18;

    ///@dev Percentage of the lottery pot that goes to `owner`. 0.50%
    uint256 public constant LOTTERY_FEE = 0.005e18;

    ///@dev Llottery pot percentage that stays for next lottery round. 2.50%
    uint256 public constant NEXT_ROUND_POT_FACTOR = 0.025e18;

    constructor(address tokenAddress_, uint256 entryFee_) {
        require(tokenAddress_ != address(0) && entryFee_ > 0, "Invalid constructor args!");
        tokenAddress = tokenAddress_;
        entryFee = entryFee_;
        lastWinnerBlock = block.number;
    }

    function getCurrentPlayers() public view returns (address[] memory) {
        return players;
    }

    function enter() public {
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= entryFee, "Insufficient allowance");
        _enter(msg.sender);
    }

    function enterOnBehalf(address player) public {
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= entryFee, "Insufficient allowance");
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), entryFee);
        _enter(player);
    }

    function enterPermit(uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        IERC20Permit(tokenAddress).permit(msg.sender, address(this), entryFee, deadline, v, r, s);
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), entryFee);
        _enter(msg.sender);
    }

    function enterOnBehalfPermit(address player, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        IERC20Permit(tokenAddress).permit(msg.sender, address(this), entryFee, deadline, v, r, s);
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), entryFee);
        _enter(player);
    }

    function pickWinner() external onlyOwner {
        require(players.length > 0, "No players in the lottery");
        require(block.number >= lastWinnerBlock + 40384, "Can only pick a winner every 7 days");

        uint256 index = _random() % players.length;
        address winner = players[index];
        uint256 contractBalance = IERC20(tokenAddress).balanceOf(address(this));

        IERC20(tokenAddress).safeTransfer(
            winner, contractBalance.mulDiv((PRECISION - LOTTERY_FEE - NEXT_ROUND_POT_FACTOR), PRECISION)
        );
        IERC20(tokenAddress).safeTransfer(owner(), contractBalance.mulDiv((LOTTERY_FEE), PRECISION));

        players = new address [](0);
        lastWinnerBlock = block.number;

        emit WinnerPicked(winner, contractBalance);
    }

    function updateEntryFee(uint256 newEntryFee) external onlyOwner {
        require(newEntryFee > 0, 'zero value input!');
        entryFee = newEntryFee;
        emit EntryFeeChange(newEntryFee);
    }

    function _enter(address player) private {
        players.push(player);
        emit PlayerEnter(player);
    }

    function _random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, players.length)));
    }
}
