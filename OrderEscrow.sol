pragma solidity ^0.4.24;


/* Owned Contract */
contract Owned {
	address public owner = msg.sender;
	event OwnerChanged(address indexed old, address indexed current);
	modifier onlyOwner { require(msg.sender == owner); _; }
	function setOwner(address _newOwner) onlyOwner public { emit OwnerChanged(owner, _newOwner); owner = _newOwner; }
}


/* ERC20 contract interface */
contract ERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}



contract OrderEscrow is Owned {

	/* order structure */
	struct Order {
		bytes32 tokenName;
		address tokenAddr;
		uint lockedAmount;
		uint lockedTime;
		uint sessionTime;
		address buyer;
		bytes4 txStatus;
	}
	
	/* User Order Data */
	/* user address => ( order id => Order structure ) */
	mapping (address => mapping (bytes32 => Order)) userOrders;

	mapping (bytes32 => address) orderOwner;
	
	/* token records, for registrations of ERC tokens */
	/* token name => token address */
	mapping (bytes32 => address) tokens;

	/* contract Balance Data */
	/* token address => amount */
	mapping (address => uint) contractERCBalance;


	/* events */
	event TokenRegister(address owner, address _tokenAddr, bytes32 _tokenName, uint timestamp);
	event MakeOrder(address sender, bytes32 orderID, address _tokenAddr, bytes32 _tokenName, uint _lockedAmount, address _buyer, uint timestamp);
	event CancelOrder(address sender, bytes32 orderID, uint lockedAmount, uint timestamp);
	event ConfirmOrder(address sender, address buyer, bytes32 orderID, uint lockedAmount, uint timestamp);


	constructor() public {
	}


	/* Is Human: Check if the transactions are executed by humen, which is user address */ 
	modifier isHuman() {
        address _addr = msg.sender;
        require (_addr == tx.origin);
        
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "Addresses not owned by human are forbidden");
        _;
    }


	/* Register token to the contract, which makes it valid. Only owner can edit */
	function tokenRegister( address _tokenAddr, bytes32 _tokenName ) onlyOwner private {

		/* Check if the token is registered */
		require (tokens[_tokenName] == 0x0, "The Token Has Registered");
		
		/* registration */
		tokens[_tokenName] = _tokenAddr;

		emit TokenRegister( msg.sender, _tokenAddr, _tokenName, now );		
	}


	/* Make order */
	function makeOrder( bytes32 _tokenName, uint _amount, bytes32 orderID, address _buyer ) isHuman public {
		
		/* Check if the token is valid */
		address _tokenAddr = tokens[_tokenName];
		require ( _tokenAddr != 0x0, "Invalid Token Name");

		uint _now = now;
		address sender = msg.sender;

		/* Initialization of ERC20 token object */ 
		ERC20 erc20 = ERC20(_tokenAddr);

		/* Check if the passing amount is allowed by user */
		/* As it can be transfer from user to contract to be locked */ 
		require ( erc20.allowance( sender, address(this) ) >= _amount, "Sufficient Allowance" );
		erc20.transferFrom( sender, address(this), _amount);

		/* Take records of token amount in contract */
		contractERCBalance[_tokenAddr] += _amount;

		/* Set order data */
		userOrders[sender][orderID] = Order({
			tokenName: _tokenName, 
			tokenAddr: _tokenAddr,
			lockedAmount: _amount,
			lockedTime: _now,
			sessionTime: _now + 7200,
			buyer: _buyer,
			txStatus: "0"
		});

		/* Set the owner of the order by UUID */
		orderOwner[orderID] = sender;

		emit MakeOrder( sender, orderID, _tokenAddr, _tokenName, _amount, _buyer, _now );
	}


	/* Cancel order */
	function cancelOrder ( bytes32 orderID ) isHuman public {

		/* Check if the order ID is correctly owned */
		address sender = msg.sender;
		require (orderOwner[orderID] == sender);

		/* Get the user(sender)'s order data */ 
		Order storage _order = userOrders[sender][orderID];
		bytes32 _tokenName = _order.tokenName;
		address _tokenAddr = _order.tokenAddr;

		/** Check status of the order and token validity.  
		  * The former should be on pending, and the other should be registered 
		**/
		require (_order.txStatus == "0" && tokens[_tokenName] != 0x0);

		uint _lockedAmount = _order.lockedAmount;
		uint _now = now;

		/* Update balance in the contract */
		contractERCBalance[_tokenAddr] -= _lockedAmount;

		/* Initialize ERC20 object */
		ERC20 erc20 = ERC20(_tokenAddr);

		/* Send back to the order maker */
		erc20.transfer( sender, _lockedAmount );
		
		/* Set order status to "canceled" */
		_order.txStatus = "2";
		// delete orderOwner[orderOwner];

		emit CancelOrder( sender, orderID, _lockedAmount, _now );
	}


	function confirmOrder ( bytes32 orderID, address _buyer ) isHuman public {

		/* Check if the order ID is correctly owned */
		address sender = msg.sender;
		require (orderOwner[orderID] == sender);

		/* Get the user(sender)'s order data */ 
		Order storage _order = userOrders[sender][orderID];
		bytes32 _tokenName = _order.tokenName;
		address _tokenAddr = _order.tokenAddr;

		/** Check status of the order and token validity.  
		  * The former should be on pending, and the other should be registered 
		**/
		require (_order.txStatus == "0" && tokens[_tokenName] != 0x0);
		
		uint _lockedAmount = _order.lockedAmount;
		uint _now = now;

		/* Update balance in the contract */
		contractERCBalance[_tokenAddr] -= _lockedAmount;

		/* Initialize ERC20 object */
		ERC20 erc20 = ERC20(_tokenAddr);

		/* Send to the order taker(buyer) */
		erc20.transfer( _buyer, _lockedAmount );
		
		/* Set order status to "Success" */
		_order.txStatus = "1";
		// delete orderOwner[orderOwner];

		emit ConfirmOrder( sender, _buyer, orderID, _lockedAmount, _now );
	}


	/* Get user order data */
	function getOrderData( bytes32 orderID ) public view returns (bytes32, uint, uint, address, bytes4) {
		
		/* Check if the order ID is correctly owned */
		address sender = msg.sender;
		require (orderOwner[orderID] == sender);
		
		Order storage _order = userOrders[sender][orderID]; 
		return (
			_order.tokenName,
			_order.lockedAmount,
			_order.lockedTime,
			_order.buyer,
			_order.txStatus
		);
	}


	/* Get the order validity time left */
	function getOrderLeftTime( bytes32 orderID ) public view returns( uint ) {
		
		/* Check if the order ID is correctly owned */
		address sender = msg.sender;
		require (orderOwner[orderID] == sender);

		uint _now = now;
		return ( userOrders[sender][orderID].sessionTime - _now );
	}
	
}