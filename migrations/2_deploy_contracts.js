const BofhContract = artifacts.require("./contracts/BofhContract.sol");

module.exports = function(deployer) {
  deployer.deploy(BofhContract);
};
