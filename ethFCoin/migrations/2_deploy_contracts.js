var OrderEscrow = artifacts.require("./OrderEscrow.sol");

module.exports = function(deployer) {
  deployer.deploy(OrderEscrow);
};