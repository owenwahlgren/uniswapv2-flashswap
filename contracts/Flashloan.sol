pragma solidity 0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

contract Flashloan {
    
    address payable owner;
    address executor;

    constructor(address _executor) public {
        owner = payable(msg.sender);
        executor = _executor;
    }


    function startArb(
        address pairAddress,
        uint amount0,
        uint amount1,
        address factoryOrigin,
        address secondRouter
    ) external {
        require(msg.sender == executor);
        IUniswapV2Pair(pairAddress).swap(
            amount0,
            amount1,
            address(this),
            bytes(abi.encode(factoryOrigin, secondRouter))
        );
    }


    function( address _sender,
        uint _amount0,
        uint _amount1, 
        bytes memory _data) public payable
        {
            address factoryOrigin;
            address secondRouter;
            (factoryOrigin, secondRouter) = abi.decode(_data, (address, address));
           
            address[] memory path = new address[](2);
            uint amountToken = _amount0 == 0 ? _amount1: _amount1;

            address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
            address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1

            require(msg.sender == UniswapV2Library.pairFor(factoryOrigin, token0, token1));
            require(_amount0 == 0 || _amount1 == 0);

            path[0] = _amount0 == 0 ? token1: token0;
            path[1] = _amount0 == 0 ? token0: token1;

            IUniswapV2ERC20 token = IUniswapV2ERC20(_amount0 == 0 ? token1: token0);
            token.approve(secondRouter, amountToken);


            uint amountRequired = UniswapV2Library.getAmountsIn(
                factoryOrigin,
                amountToken,
                path
            )[0];

            uint amountReceived = IUniswapV2Router01(secondRouter).swapExactTokensForTokens(amountToken, amountRequired, path, msg.sender, 10 days)[1];
            token.transfer(tx.origin, amountReceived - amountRequired);

        }

    function withdraw(address _token) public payable {
        require(msg.sender == owner);
        IUniswapV2ERC20 token = IUniswapV2ERC20(_token);
        token.transfer(owner, token.balanceOf(address(this)));
        owner.transfer(address(this).balance);
    }
}
