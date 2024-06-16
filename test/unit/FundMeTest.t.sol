// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    //Users
    address alice = makeAddr("alice");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant GAS_PRICE = 1;

    modifier funded() {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function setUp() external {
        // This function is called before each test#
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(alice, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        uint256 expected = 5 * 10 ** 18;
        uint256 actual = fundMe.MINIMUM_USD();
        assertEq(actual, expected, "Minimum USD is not 5");
    }

    function testOwnerIsMsgSender() public view {
        address expected = msg.sender;
        address actual = fundMe.getOwner();
        assertEq(actual, expected, "Owner is not msg.sender");
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 expected = 4;
        uint256 actual = fundMe.getVersion();
        assertEq(actual, expected, "Price feed version is not accurate");
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // expect a revert in the next line
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(alice);
        assertEq(amountFunded, SEND_VALUE, "Amount funded is not accurate");
    }

    function testFundAddsFunderToArrayOfFunders() public {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, alice, "Funder is not accurate");
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        vm.expectRevert(); // expect a revert in the next line
        vm.prank(alice);
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnderBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(
            endingOwnderBalance,
            startingOwnerBalance + startingFundMeBalance,
            "Owner balance is not accurate"
        );
        assertEq(endingFundMeBalance, 0, "FundMe balance is not accurate");
    }

    function testWithDrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        uint256 endingOwnderBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0, "FundMe balance is not accurate");
        assertEq(
            endingOwnderBalance,
            startingOwnerBalance + startingFundMeBalance,
            "Owner balance is not accurate"
        );
    }
}
