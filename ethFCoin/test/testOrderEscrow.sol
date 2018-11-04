pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/OrderEscrow.sol";
import "../contracts/TutorialToken.sol";

contract TestOrderEscrow {

	OrderEscrow oe = OrderEscrow(DeployedAddresses.OrderEscrow());
	TutorialToken tt = TutorialToken(DeployedAddresses.TutorialToken());

	function testTokenCanLocked() {

		//如何先給帳號錢?
		address buyerAddr = oe.buyer();
		address senderAddr = oe.owner();
		address TTAddr = this ; //不知道怎麼抓
		uint lockedAmount = oe._amount();

		uint tokenRegister = oe.tokenRegister(TTAddr, tt.symbol());
		uint makerOrder = oe.makerOrder(tt.symbol(), 300, oe.orderID(), oe.buyer());

		Assert.equal(lockedAmount, 300, "lockedAmount should be 300");

	}


	function testSomeoneCanceltheTrade() {

		address buyerAddr = oe.buyer();
		address senderAddr = oe.owner();
		uint lockedAmount = oe._amount();

		uint makerOrder = oe.makerOrder(tt.symbol(), 600, oe.orderID(), oe.buyer()); 
		uint cancelOrder = oe.cancelOrder( oe.orderID());

		Assert.equal(lockedAmount, 0, "lockedAmount should be 0");
	}


	function testTakerPay2theMakerSuccessfully() {

		address buyerAddr = oe.buyer();
		address senderAddr = oe.owner();
		uint lockedAmount = oe._amount();

		uint makerOrder = oe.makerOrder(tt.symbol(), 600, oe.orderID(), oe.buyer()); 
		uint confirmOrder = oe.confirmOrder(oe.orderID(), buyerAddr);	
			
		Assert.equal(lockedAmount, 0, "lockedAmount should be 0");
		Assert.equal(buyerAddr, 600, "buyerAddress amount should be 600");
	}

}