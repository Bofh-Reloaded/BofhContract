all: contract

contract: BofhContract.sol
BofhContract.sol: BofhContract.pp.sol
	cpp -DNDEBUG=1 -CC -nostdinc BofhContract.pp.sol | grep -v "^#" > BofhContract.sol
	npx prettier --write BofhContract.sol
	solc --optimize --optimize-runs=2000 --color BofhContract.sol

clean:
	rm -f BofhContract.sol
