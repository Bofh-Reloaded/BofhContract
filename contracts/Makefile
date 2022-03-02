all: contract


contract: BofhContract.sol
BofhContract.sol: BofhContract.pp.sol
	cpp -DNDEBUG=1 -CC -nostdinc BofhContract.pp.sol | grep -v "^#" > BofhContract.sol
	cpp -DNDEBUG=1 -DNO_DEBUG_CODE=1 -CC -nostdinc BofhContract.pp.sol | grep -v "^#" > BofhContract-nodebug.sol
	npx prettier --write BofhContract.sol
	npx prettier --write BofhContract-nodebug.sol
	solc --optimize --optimize-runs=2000 --color BofhContract.sol
	solc --optimize --optimize-runs=2000 --color BofhContract-nodebug.sol

clean:
	rm -f BofhContract.sol BofhContract-nodebug.sol
