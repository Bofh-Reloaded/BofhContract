all: contract

contract: BofhContract.sol BofhContract-debug.sol
BofhContract.sol BofhContract-debug.sol: BofhContract.pp.sol
	cpp -DNDEBUG=1 BofhContract.pp.sol | grep -v "^#" > BofhContract.sol
	cpp            BofhContract.pp.sol | grep -v "^#" > BofhContract-debug.sol
	solc --color BofhContract-debug.sol
	solc --optimize --optimize-runs=2000 --color BofhContract.sol

clean:
	rm -f BofhContract.sol
