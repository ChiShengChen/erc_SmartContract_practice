pragma solidity ^0.4.24;
// import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";  
// import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";  
// import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
// import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
// import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
/* Owned Contract */
contract Owned {
    // address public owner = msg.sender;
    /* specific owner account of gdp team */
    address public owner = 0x0;
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
        address seller;
        address buyer;
        string tokenName;
        address tokenAddr;
        string orderID;
        uint lockedAmount;
        uint lockedTime;
        uint sessionTime;
        uint8 status;
    }
    /* order object */
    Order order;
    /* session time parameter */
    uint public constant ORDER_SESSION = 7200;
    /* order status */
    uint8 private constant IsConfirmedBySeller = 4;
    uint8 private constant IsPaidByBuyer = 2;
    uint8 private constant IsEstablish = 1;
    uint8 private constant IsCanceled = 0;
    /* Order lock */
    bool public orderIsExisted = false;
    
    /* events */
    event TokenRegister(address owner, address _tokenAddr, string _tokenName, uint timestamp);
    event MakeOrder(address indexed _seller, address indexed _buyer, string _tokenName, address _tokenAddr, string _orderID, uint _lockedAmount, uint8 _status, uint timestamp);
    event CancelOrder(address indexed _canceler, address indexed _seller, string _tokenName, address _tokenAddr, string _orderID, uint _lockedAmount, uint8 _status, uint timestamp);
    event ConfirmOrder(address indexed _seller, address indexed _buyer, string _tokenName, address _tokenAddr, string _orderID, uint _lockedAmount, uint8 _status, uint timestamp);
    /* constructor */
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
    
    function makeOrder ( address _buyer, string _tokenName, address _tokenAddr,  string _orderID, uint _lockedAmount) isHuman public {
        
        /* check if the order is existed */
        require (!orderIsExisted, "The order has existed");
        /* check if the token address is valid */
        require (_tokenAddr != 0x0, "Invalid Token Address");
        uint _now = now;
        address _seller = msg.sender;
        /* Initialization of ERC20 token object */ 
        ERC20 erc20 = ERC20(_tokenAddr);
        /* Check if the passing amount is allowed by user */
        /* As it can be transfer from user to contract to be locked */ 
        require ( erc20.allowance( _seller, address(this) ) >= _lockedAmount, "Sufficient Allowance" );
        /* set order data */
        order = Order({
            seller: _seller,
            buyer: _buyer,
            tokenName: _tokenName,
            tokenAddr: _tokenAddr,
            orderID: _orderID,
            lockedAmount: _lockedAmount,
            lockedTime: _now,
            sessionTime: _now + ORDER_SESSION,
            status: IsEstablish
        });
        /* Transfer seller's money to the escrow contract */
        erc20.transferFrom( _seller, address(this), _lockedAmount);
        /* set existed */
        orderIsExisted = true;
        emit MakeOrder( _seller, _buyer, _tokenName, _tokenAddr, _orderID, _lockedAmount, IsEstablish, _now );
    }
    
    /* Cancel order */
    function cancelOrder () isHuman public {
        
        /* Only owner and buyer can cancel the order 
         * Owner: When the order is timeout
         * Buyer: Click cancel by itself
        */
        address _canceler = msg.sender;
        require (_canceler == owner || _canceler == order.buyer, "Only owner and buyer can cancel order");
        /* check order status */
        require (orderIsExisted, "No order existed");
        require (order.status < IsPaidByBuyer, "Wrong order status");
        address _tokenAddr = order.tokenAddr;
        uint _lockedAmount = order.lockedAmount;
        uint _now = now;
        /* set lockedAmount to zero */
        order.lockedAmount = 0;
        /* Initialize ERC20 object */
        ERC20 erc20 = ERC20(_tokenAddr);
        /* Transfer back to the seller once canceled */
        erc20.transfer( order.seller, _lockedAmount );
        /* set the order status canceled */
        order.status = IsCanceled;
        emit CancelOrder( _canceler, order.seller, order.tokenName, order.tokenAddr, order.orderID, order.lockedAmount, order.status, _now );
    }
    
    /* Buyer set whether the order is paid */
    function setPaid() isHuman public {
        address sender = msg.sender;
        /* only buyer can pay for the order */
        require (sender == order.buyer, "Only buyer can set paid!");
        /* check is paid */
        require (order.status < IsPaidByBuyer && order.status != IsCanceled, "Wrong order status");
        /* set the order status paid */
        order.status = IsEstablish | IsPaidByBuyer;
        
    }
    
    /* confirm order */
    function confirmOrder () isHuman public {
        address _seller = msg.sender;
        /* only seller can do this */
        require (orderIsExisted, "No order existed");
        require (_seller == order.seller, "Only seller can confirm!");
        
        /* check order status */
        require (order.status < IsConfirmedBySeller && order.status > IsPaidByBuyer, "Wrong order status");
        address _tokenAddr = order.tokenAddr;
        uint _lockedAmount = order.lockedAmount;
        uint _now = now;
        /* set lockedAmount to zero */
        // order.lockedAmount = 0;

        /* Initialize ERC20 object */
        ERC20 erc20 = ERC20(_tokenAddr);
        /* Transfer to the buyer */
        erc20.transfer( order.buyer, _lockedAmount );

        /* set the order status confirmed */
        order.status = IsEstablish | IsPaidByBuyer | IsConfirmedBySeller;
        emit ConfirmOrder( _seller, order.buyer, order.tokenName, order.tokenAddr, order.orderID, order.lockedAmount, order.status, _now );
    }

    
    /* Get user order data */
    function getOrderData() public view returns (
        address _seller,
        address _buyer,
        string _tokenName, 
        address _tokenAddr, 
        uint _lockedAmount, 
        uint _lockedTime, 
        uint8 _status ) 
    {
        
        /* Check if the order ID is correctly owned */
        address sender = msg.sender;
        require (
            sender == order.seller || 
            sender == order.buyer ||
            sender == owner
        );
        
        return (
            order.seller,
            order.buyer,
            order.tokenName,
            order.tokenAddr,
            order.lockedAmount,
            order.lockedTime,
            order.status
        );
    }
    /* get contract(order) address */
    function getContractAddress() public view returns( address ) {
        return address(this);
    }

    // function setAddress() public{
        
    // }
}