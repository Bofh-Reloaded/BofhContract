from dataclasses import dataclass
from os.path import join, dirname, realpath

from eth_utils import to_checksum_address

from bofh.utils.solidity import add_solidity_search_path, get_abi

add_solidity_search_path(join(dirname(dirname(dirname(realpath(__file__)))), "contracts"))

@dataclass
class DebugStatus:
    """debug struct returned by Bofhcontract.multiswap_debug()"""
    token0: str
    token1: str
    reserve0: int
    reserve1: int
    amountIn: int
    amountOut: int
    feePPM: int
    amountInWithFee: int
    tokenOut: str
    reserveIn: int
    reserveOut: int
    numerator: int
    denominator: int
    amount0Out: int
    amount1Out: int


@dataclass
class SwapInspection:
    tokenIn: str
    tokenOut: str
    reserveIn: int
    reserveOut: int
    transferredAmountIn: int
    measuredAmountIn: int
    transferredAmountOut: int
    measuredAmountOut: int

    @classmethod
    def from_output(cls, data) -> list:
        res = []
        if isinstance(data, (list, tuple)):
            for t in data:
                assert isinstance(t, (list, tuple))
                assert len(t) == 8
                tokenIn = to_checksum_address(t[0])
                tokenOut = to_checksum_address(t[1])
                reserveIn = int(t[2])
                reserveOut = int(t[3])
                transferredAmountIn = int(t[4])
                measuredAmountIn = int(t[5])
                transferredAmountOut = int(t[6])
                measuredAmountOut = int(t[7])
                res.append(cls(tokenIn=tokenIn
                               , tokenOut=tokenOut
                               , reserveIn=reserveIn
                               , reserveOut=reserveOut
                               , transferredAmountIn=transferredAmountIn
                               , measuredAmountIn=measuredAmountIn
                               , transferredAmountOut=transferredAmountOut
                               , measuredAmountOut=measuredAmountOut
                               ))
        else:
            raise RuntimeError(f"unsupported output format: {type(data)}")
        return res

    @classmethod
    def inspection_calldata(cls, path, initial_amount, override_fees=None):
        pools = []
        fees = []
        if override_fees:
            if isinstance(override_fees, list):
                pass
            elif isinstance(override_fees, int):
                override_fees = [override_fees] * path.size()
            else:
                raise TypeError("override_fees must be int or list[int]")
            if len(override_fees) != len(path):
                raise TypeError("override_fees len must match path len")
        for i in range(path.size()):
            swap = path.get(i)
            pools.append(str(swap.pool.address))
            fee = swap.pool.feesPPM()
            if override_fees and override_fees[i] is not None:
                fee = override_fees[i]
            fees.append(fee)
        return cls.pack_args_payload(pools=pools
                                     , fees=fees
                                     , initial_amount=initial_amount
                                     , expected_amount=0)

    @staticmethod
    def pack_args_payload(pools: list
                          , fees: list
                          , initial_amount: int
                          , expected_amount: int
                          , stop_after_pool=None):
        assert len(pools) == len(fees)
        args = []
        for i, (addr, fee) in enumerate(zip(pools, fees)):
            val = int(str(addr), 16) | (fee << 160)
            if stop_after_pool == i:
                val |= (1 << 180) # set this bit. on Debug contracts, it triggers OPT_BREAK_EARLY
            args.append(val)
        amounts_word = \
            ((initial_amount & 0xffffffffffffffffffffffffffffffff) << 0) | \
            ((expected_amount & 0xffffffffffffffffffffffffffffffff) << 128)
        args.append(amounts_word)

        return [args]


    @staticmethod
    def update_attack_plan(attack_plan, swap_inspection_seq):
        assert len(swap_inspection_seq) == attack_plan.path.size()
        for idx, s in enumerate(swap_inspection_seq):
            assert isinstance(s, SwapInspection)
            attack_plan.set_pool_token_reserve(idx
                                               , attack_plan.token_before_step(idx)
                                               , s.reserveIn)
            attack_plan.set_pool_token_reserve(idx
                                               , attack_plan.token_after_step(idx)
                                               , s.reserveOut)
            if idx == 0:
                attack_plan.set_issued_balance_before_step(idx, s.transferredAmountIn)
                attack_plan.set_measured_balance_before_step(idx, s.measuredAmountIn)
            attack_plan.set_issued_balance_after_step(idx, s.transferredAmountOut)
            attack_plan.set_measured_balance_after_step(idx, s.measuredAmountOut)
