const OrderEscrow = artifacts.require("./OrderEscrow.sol");
// const TokenExchange = artifacts.require('./TokenExchange.sol');
const TT = artifacts.require("./TutorialToken.sol");

const BigNumber = web3.BigNumber;

let sender, tt

contract('OrderEscrow', function(accounts) {

  

  let accountA, accountB;

   [accountA, accountB] = accounts;

  beforeEach(async () => {
    sender = await OrderEscrow.new();
    tt = await TT.new();


    await sender.addNewToken('TT', tt.address);


    let TTAmount = new BigNumber(700e5);
    // Give some TT to accountB first
    await tt.approve(sender.address, TTAmount, {
      from: accountA
    });

    // await sender.transferTokens('TT', accountB, TTAmount, {
    //   from: accountA
    // });
  });



    // it('should deploy the token and store the address', function(done){
    //     OrderEscrow.deployed().then(async function(instance) {
    //         const token = await instance.token.call();
    //         assert(token, 'Token address couldn\'t be stored');
    //         done();
    //    });
    // });


    // it('tokenRegister', function(done){
    //     OrderEscrow.deployed().then(async function(instance) {
    //       await instance.tokenRegister(accountA, TT);
    //       assert.equal(tokens[_tokenName].toNumber(), 0, 'Check if the token is registered');
    //       done();
    //    });
    // });


    it('escrow lock the tokens for two hours, and the trade successful or not', function(done){
        OrderEscrow.deployed().then(async function(instance) {
          
          await instance.makeOrder(tt, TTAmount, orderID, sender.address);

          let takerBalance = ((await tt.balanceOf(accountA)).toString());
          let orderBalance = ((await tt.balanceOf(accountB)).toString());
      
       });
    });

    it('someone cancel the trade', function(done){
        OrderEscrow.deployed().then(async function(instance) {
          
          await instance.cancelOrder(orderOwner[orderID]);

          let takerBalance = ((await tt.balanceOf(accountA)).toString());
          let orderBalance = ((await tt.balanceOf(accountB)).toString());
      
       });
    });

    it('the taker pay to the maker successfully', function(done){
       OrderEscrow.deployed().then(async function(instance) {
          
          await instance.confirmOrder(orderOwner[orderID], buyer.address);

          let takerBalance = ((await tt.balanceOf(accountA)).toString());
          let orderBalance = ((await tt.balanceOf(accountB)).toString());
      
       });
    });

});