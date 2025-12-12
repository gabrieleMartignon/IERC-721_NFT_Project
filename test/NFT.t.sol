// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {NFT, RequestStatus, Rarity} from "src/NFT.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {stdStorage, StdStorage} from "lib/forge-std/src/StdStorage.sol";
using stdStorage for StdStorage;

contract NFTTest is Test {
    NFT public nftContract;
    VRFCoordinatorV2_5Mock public coordinatorMock;
    uint256 public subId;
    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    receive() external payable {}

    function setUp() public {
        // Deploy mock VRF Coordinator
        coordinatorMock = new VRFCoordinatorV2_5Mock(1, 1, 1);

        // Create a VRF subscription
        subId = coordinatorMock.createSubscription();

        // Fund subscription
        coordinatorMock.fundSubscription(subId, 10000000000 ether);

        // Create a instance of the NFT Contract
        nftContract = new NFT("DnA collection", "DnA", 1 ether, 1000, address(coordinatorMock), subId);

        // Add consumer/spender to the subscription
        coordinatorMock.addConsumer(subId, address(nftContract));
    }

    function testMint_OutOfSupply() public {
        stdstore.target(address(nftContract)).sig("nextTokenId()").checked_write(1000);
        vm.expectRevert("No more NFT available for minting");
        nftContract.mint{value: 1 ether}();
    }

    function testMint_NoFunds() public {
        vm.expectRevert("Funds insufficient");
        nftContract.mint();
    }

    function testMint() public {
        // Minting and requesting random numbers from VR mock
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        assertEq(nftContract.requestToTokenId(requestId), 1);

        //Simulating response and checking rarity metadata
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        RequestStatus memory status = nftContract.getRequestStatus(requestId);
        assertTrue(status.fulfilled, "Request not fulfilled");
        assertTrue(status.randomWords[0] > 0, "Random number not received");
        (,,,,,,, Rarity rarity,) = nftContract.tokenIdMetadata(1);
        assertTrue(rarity == Rarity.Common, "Rarity assigned");

        // Checking balance and token owner after minting
        assertEq(nftContract.balance(user1), 1);
        assertEq(nftContract.tokenIdOwner(1), user1);
    }

    // Trying withdraw funds as not the owner
    function testWithdrawFunds_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Contract owner only");
        vm.deal(address(nftContract), 10 ether);
        nftContract.withdrawFunds(1 ether);
    }

    // Trying withdraw more funds than contract balance
    function testWithdrawFunds_ExceedingContractBalance() public {
        vm.prank(user1);
        vm.expectRevert("Amount requested exceed contract balance");
        nftContract.withdrawFunds(1 ether);
    }

    // Successful withdraw
    function testWithdrawFunds() public {
        vm.deal(address(nftContract), 5 ether);
        vm.prank(nftContract.contractOwner());
        nftContract.withdrawFunds(1 ether);
    }

    // Approving for token not minted
    function testGetApproved_TokeNotMintedYet() public {
        vm.prank(user1);
        vm.expectRevert("Token doesn't exist");
        nftContract.getApproved(1);
    }

    // Approving for token non existant
    function testApprove_TokenNotMintedYet() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        vm.expectRevert("Token doesn't exist");
        nftContract.approve(address(nftContract), 2);
    }

    // Approve called by non-owner, should revert

    function testApprove_CallerNotTokenOwner() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user2);
        vm.expectRevert("Caller is not owner");
        nftContract.approve(address(nftContract), 1);
    }

    // Approve to current owner, should revert

    function testApprove_CallerIsCurrentOwner() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        vm.expectRevert("Approval to current owner");
        nftContract.approve(user1, 1);
    }

    // Successful approve, verify approved address is stored

    function testApprove() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        nftContract.approve(user2, 1);
        assertEq(nftContract.addressApproved(1), user2);
    }

    // setApprovalForAll with address(0), should revert
    function testSetApprovalForAll_UsingAddress0() public {
        vm.expectRevert("Choose a valid address");
        nftContract.setApprovalForAll(address(0), true);
    }

    // Successful setApprovalForAll, verify operator approval and removal

    function testSetApprovalForAll() public {
        vm.prank(user1);
        nftContract.setApprovalForAll(user2, true);
        assertEq(nftContract.operatorApproved(user1, user2), true);
        vm.prank(user1);
        nftContract.setApprovalForAll(user2, false);
        assertEq(nftContract.operatorApproved(user1, user2), false);
    }

    // safeTransferFrom with invalid addresses, should revert

    function testSafeTransfer_InvalidAddress() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        vm.expectRevert("Invalid transfer address");
        nftContract.safeTransferFrom(user1, address(0), 1);
        vm.expectRevert("Invalid transfer address");
        nftContract.safeTransferFrom(address(0), user1, 1);
    }

    // Successful safeTransferFrom, verify token moves from user1 to user2 and back

    function testSafeTransfer() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        nftContract.approve(user2, 1);
        vm.prank(user1);
        nftContract.safeTransferFrom(user1, user2, 1);
        assertEq(nftContract.balance(user2), 1);

        vm.prank(user2);
        nftContract.approve(user1, 1);
        vm.prank(user2);
        nftContract.safeTransferFrom(user2, user1, 1);
        assertEq(nftContract.balance(user1), 1);
    }

    // transferFrom with invalid addresses should revert
    function testTransferFrom_InvalidAddress() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        vm.expectRevert("Invalid transfer address");
        nftContract.transferFrom(user1, address(0), 1);
        vm.expectRevert("Invalid transfer address");
        nftContract.transferFrom(address(0), user1, 1);
    }

    // transferFrom not calle by token owner
    function testTransferFrom_NotFromOwner() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        vm.expectRevert("Address received is not the token owner");
        nftContract.transferFrom(user2, user1, 1);
    }

    // Succesfull transferFrom
    function testTransferFrom() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        nftContract.mint{value: 5 ether}();
        uint256 requestId = nftContract.lastRequestId();
        coordinatorMock.fulfillRandomWords(requestId, address(nftContract));
        vm.prank(user1);
        nftContract.transferFrom(user1, user2, 1);
        assertTrue(nftContract.ownerOf(1) == user2, "");
    }
}
