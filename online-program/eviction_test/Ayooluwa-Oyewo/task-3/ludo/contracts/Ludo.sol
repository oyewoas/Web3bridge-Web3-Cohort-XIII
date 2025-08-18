// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LudoToken - Token for staking in the Ludo game
contract LudoToken is ERC20 {
    constructor() ERC20("LudoToken", "LUDO") {
        _mint(msg.sender, 1_000_000 ether); // mint initial supply
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title LudoGame - A simple blockchain-based Ludo game
contract LudoGame is Ownable {
    enum Color { RED, GREEN, BLUE, YELLOW }

    struct Player {
        string name;
        Color color;
        uint256 score;
        bool registered;
        address addr;
    }

    /// ----------------------
    /// Custom Errors
    /// ----------------------
    error GameAlreadyStarted();
    error GameNotStarted();
    error AlreadyRegistered();
    error MaxPlayersReached();
    error ColorAlreadyTaken();
    error NotAPlayer();
    error NotEnoughPlayers();

    /// ----------------------
    /// Events
    /// ----------------------
    event PlayerRegistered(address indexed player, string name, Color color);
    event GameStarted(uint256 stakeAmount, uint256 totalPlayers);
    event DiceRolled(address indexed player, uint256 diceValue, uint256 newScore);
    event WinnerDeclared(address indexed winner, uint256 score, uint256 prizePool);

    LudoToken public token;
    uint256 public stakeAmount;
    uint8 public playerCount;
    bool public gameStarted;
    mapping(address => Player) public players;
    address[] public playerList;

    constructor(address _token, uint256 _stakeAmount) Ownable(msg.sender) {
        token = LudoToken(_token);
        stakeAmount = _stakeAmount;
    }

    modifier onlyBeforeStart() {
        if (gameStarted) revert GameAlreadyStarted();
        _;
    }

    modifier onlyPlayer() {
        if (!players[msg.sender].registered) revert NotAPlayer();
        _;
    }

    function register(string calldata _name, Color _color) external onlyBeforeStart {
        if (players[msg.sender].registered) revert AlreadyRegistered();
        if (playerCount >= 4) revert MaxPlayersReached();

        // Ensure unique color
        for (uint i = 0; i < playerList.length; i++) {
            if (players[playerList[i]].color == _color) revert ColorAlreadyTaken();
        }

        players[msg.sender] = Player({
            name: _name,
            color: _color,
            score: 0, 
            registered: true,
            addr: msg.sender
        });

        playerList.push(msg.sender);
        playerCount++;

        emit PlayerRegistered(msg.sender, _name, _color);
    }

    function startGame() external onlyBeforeStart {
        if (playerCount < 4) revert NotEnoughPlayers();

        // collect stakes
        for (uint i = 0; i < playerList.length; i++) {
            token.transferFrom(playerList[i], address(this), stakeAmount);
        }

        gameStarted = true;
        emit GameStarted(stakeAmount, playerCount);
    }

    function rollDice() public onlyPlayer returns (uint256) {
        if (!gameStarted) revert GameNotStarted();

        // pseudo-random (use Chainlink VRF in production)
        uint256 dice = (uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao))
        ) % 6) + 1;

        players[msg.sender].score += dice;

        emit DiceRolled(msg.sender, dice, players[msg.sender].score);

        return dice;
    }

    function declareWinner() external onlyOwner {
        if (!gameStarted) revert GameNotStarted();

        address winner;
        uint256 highScore = 0;

        for (uint i = 0; i < playerList.length; i++) {
            if (players[playerList[i]].score > highScore) {
                highScore = players[playerList[i]].score;
                winner = playerList[i];
            }
        }

        // transfer pool to winner
        uint256 pool = stakeAmount * playerCount;
        token.transfer(winner, pool);

        emit WinnerDeclared(winner, highScore, pool);

        // reset game
        _resetGame();
    }

    function _resetGame() internal {
        for (uint i = 0; i < playerList.length; i++) {
            delete players[playerList[i]];
        }
        delete playerList;
        playerCount = 0;
        gameStarted = false;
    }

    function getPlayer(address _addr) external view returns (
    string memory name,
    Color color,
    uint256 score,
    bool registered,
    address playerAddr
) {
    Player storage p = players[_addr];
    return (p.name, p.color, p.score, p.registered, p.addr);
}

function getScore(address _addr) external view returns (uint256) {
    return players[_addr].score;
}
}
