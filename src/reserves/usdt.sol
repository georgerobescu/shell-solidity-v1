
contract ChaiReserve {
    mapping(address => uint256) public reserves;
    address constant reserve;

    constructor () public { }

    function getReserves (address addr) public returns (uint256) {
        return reserves[addr];
    }

    function unwrap (uint256 amount) public returns (uint256) {
        return amount;
    }

    function wrap (uint256 amount) public returns (uint256) {
        return amount;
    }

    function transfer (uint256 amount) public returns (uint256) {
        /*
            Need to handle bad erc20
        */
    }

    function transferFrom () public returns (uint256) {
        /*
            Need to handle bad erc20 here?
        */
    }
}