pragma solidity 0.5.16;

// This is a contract from AMPLYFI contract suite

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract UniswapLiq {

    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    

    function addLiquidity() external payable {
	    uint256 _collectedEth = msg.value;
		address burnAddress = address(0x0);
	    uniswapRouter.addLiquidityETH.value(_collectedEth)(
		msg.sender,
		_collectedEth * 5 / 4,
		_collectedEth * 5 / 4,
		_collectedEth,
		burnAddress, //Initial liquidity tokens are burned.
		now - 3560000);
     }
}
