// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/Ludo.sol";

contract LudoGameTest is Test {
    LudoToken token;
    LudoGame game;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    address carol = makeAddr("carol");
    address dave  = makeAddr("dave");
    address eve   = makeAddr("eve"); // extra

    uint256 constant STAKE = 100 ether;

    function setUp() public {
        // Deploy token & game
        token = new LudoToken();
        game = new LudoGame(address(token), STAKE);

        // Mint tokens to players
        token.mint(alice, 1000 ether);
        token.mint(bob,   1000 ether);
        token.mint(carol, 1000 ether);
        token.mint(dave,  1000 ether);
        token.mint(eve,   1000 ether);

        // Approve game to spend
        vm.startPrank(alice); token.approve(address(game), 1000 ether); vm.stopPrank();
        vm.startPrank(bob);   token.approve(address(game), 1000 ether); vm.stopPrank();
        vm.startPrank(carol); token.approve(address(game), 1000 ether); vm.stopPrank();
        vm.startPrank(dave);  token.approve(address(game), 1000 ether); vm.stopPrank();
        vm.startPrank(eve);   token.approve(address(game), 1000 ether); vm.stopPrank();
    }

    
    // -------------------------
    // Registration
    // -------------------------

    function testRegisterPlayers() public {
        vm.expectEmit(true, false, false, true);
        emit LudoGame.PlayerRegistered(alice, "Alice", LudoGame.Color.RED);
        vm.prank(alice);
        game.register("Alice", LudoGame.Color.RED);

        vm.prank(bob);
        game.register("Bob", LudoGame.Color.GREEN);

        vm.prank(carol);
        game.register("Carol", LudoGame.Color.BLUE);

        vm.prank(dave);
        game.register("Dave", LudoGame.Color.YELLOW);

        assertEq(game.playerCount(), 4);
        (string memory name,, uint256 score, bool registered, address addr) = game.players(alice);
        assertEq(name, "Alice");
        assertEq(score, 0);
        assertTrue(registered);
        assertEq(addr, alice);
    }

    function testRegisterSameAddressTwiceReverts() public {
        vm.prank(alice);
        game.register("Alice", LudoGame.Color.RED);

        vm.expectRevert(LudoGame.AlreadyRegistered.selector);
        vm.prank(alice);
        game.register("AliceAgain", LudoGame.Color.GREEN);
    }

    function testRegisterSameColorReverts() public {
        vm.prank(alice);
        game.register("Alice", LudoGame.Color.RED);

        vm.expectRevert(LudoGame.ColorAlreadyTaken.selector);
        vm.prank(bob);
        game.register("Bob", LudoGame.Color.RED);
    }

    function testRegisterMoreThanFourReverts() public {
        vm.prank(alice); game.register("Alice", LudoGame.Color.RED);
        vm.prank(bob);   game.register("Bob", LudoGame.Color.GREEN);
        vm.prank(carol); game.register("Carol", LudoGame.Color.BLUE);
        vm.prank(dave);  game.register("Dave", LudoGame.Color.YELLOW);

        vm.expectRevert(LudoGame.MaxPlayersReached.selector);
        vm.prank(eve);
        game.register("Eve", LudoGame.Color.RED);
    }

    // -------------------------
    // Game Start
    // -------------------------

    function testStartGameAndStake() public {
        _registerFour();

        vm.expectEmit(false, false, false, true);
        emit LudoGame.GameStarted(STAKE, 4);

        vm.prank(alice);
        game.startGame();

        assertTrue(game.gameStarted());
        assertEq(token.balanceOf(address(game)), STAKE * 4);
    }

    function testStartGameWithLessPlayersReverts() public {
        vm.prank(alice);
        game.register("Alice", LudoGame.Color.RED);

        vm.expectRevert(LudoGame.NotEnoughPlayers.selector);
        vm.prank(alice);
        game.startGame();
    }

    // -------------------------
    // Dice Rolls
    // -------------------------

    function testRollDiceIncreasesScore() public {
    _startWithFour();

    vm.prank(alice);
    uint256 dice = game.rollDice();

    uint256 score = game.getScore(alice);
    assertEq(score, dice);
}
    function testRollDiceBeforeStartReverts() public {
        vm.prank(alice);
        game.register("Alice", LudoGame.Color.RED);

        vm.expectRevert(LudoGame.GameNotStarted.selector);
        vm.prank(alice);
        game.rollDice();
    }

    // -------------------------
    // Winner Declaration
    // -------------------------

    function testDeclareWinnerTransfersPrize() public {
    _startWithFour();

    // Give Alice high score
     // Alice rolls many times
    vm.startPrank(alice);
    for (uint i = 0; i < 10; i++) {
        game.rollDice();
    }
    vm.stopPrank();
    uint256 balanceBefore = alice.balance;

    game.declareWinner();

    uint256 balanceAfter = alice.balance;
    assertGt(balanceAfter, balanceBefore);

    (string memory name,, uint256 score,,) = game.getPlayer(alice); 
    assertEq(name, "Alice");
    assertGt(score, 0);
}

    // -------------------------
    // Helpers
    // -------------------------

    function _registerFour() internal {
        vm.prank(alice); 
        game.register("Alice", LudoGame.Color.RED);
        vm.prank(bob);   
        game.register("Bob", LudoGame.Color.GREEN);
        vm.prank(carol); 
        game.register("Carol", LudoGame.Color.BLUE);
        vm.prank(dave);  
        game.register("Dave", LudoGame.Color.YELLOW);
    }

    function _startWithFour() internal {
    _registerFour();
    vm.prank(alice);
    game.startGame();
}

}
