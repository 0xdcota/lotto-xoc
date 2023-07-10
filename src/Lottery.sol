// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IERC20 {
    function allowance(address owner, address recipent) external returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}

contract Lottery {
    address public manager;
    address public tokenAddress;
    uint256 public entryFee;
    address payable[] public players;
    uint256 public lastWinnerBlock;

    event WinnerPicked(address winner, uint256 amount);

    constructor(address _tokenAddress, uint256 _entryFee) {
        manager = msg.sender;
        tokenAddress = _tokenAddress;
        entryFee = _entryFee;
        lastWinnerBlock = block.number;
    }

    function enter() public {
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= entryFee, "Insufficient allowance");

        bool transferSuccess = token.transferFrom(msg.sender, address(this), entryFee);
        require(transferSuccess, "Token transfer failed");

        players.push(payable(msg.sender));
    }

    function enterPermit(uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        IERC20 token = IERC20(tokenAddress);

        token.permit(msg.sender, address(this), entryFee, deadline, v, r, s);

        bool transferSuccess = token.transferFrom(msg.sender, address(this), entryFee);
        require(transferSuccess, "Token transfer failed");

        players.push(payable(msg.sender));
    }

    function enterWithApproval(uint256 _entryFee) public {
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= _entryFee, "Insufficient allowance");

        bool transferSuccess = token.transferFrom(msg.sender, address(this), _entryFee);
        require(transferSuccess, "Token transfer failed");

        players.push(payable(msg.sender));
    }

    function random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players.length)));
    }

    function pickWinner() public restricted {
        require(players.length > 0, "No players in the lottery");
        require(block.number >= lastWinnerBlock + 40384, "Can only pick a winner every 7 days");

        uint256 index = random() % players.length;
        address payable winner = players[index];
        uint256 contractBalance = IERC20(tokenAddress).balanceOf(address(this));

        IERC20 token = IERC20(tokenAddress);
        bool transferSuccess = token.transfer(winner, contractBalance);
        require(transferSuccess, "Token transfer failed");

        players = new address payable[](0);
        lastWinnerBlock = block.number;

        emit WinnerPicked(winner, contractBalance);
    }

    modifier restricted() {
        require(msg.sender == manager, "Only the manager can call this function");
        _;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }
}
