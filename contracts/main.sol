// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./verify.sol";
import "./Interface.sol";

contract DealsGame is Ownable, Pausable, Verifier {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter private _ID;
    struct Lottery {
        uint256 Price;
        uint256 Max_Ticket_Per_Wallet;
        uint256 Start_Time;
        uint256 End_Time;
        Status _Status;
        Payment_Methods _Payment_Methods;
        address[] Wallets;
        uint256 Win_Code;
    }
    mapping(uint256 => Lottery) public Lotteries;
    mapping(uint256 => mapping(address => uint256[])) Tickets;
    mapping(uint256 => uint256[]) Sold_Tickets;
    mapping(uint256 => uint256) public Amount_Collected;
    mapping(uint256 => mapping(address => uint256)) public paid;
    address Validator_Address;
    enum Payment_Methods {
        BNB,
        BUSD
    }
    // Represents the status of the lottery
    enum Status {
        NotStarted, // The lottery has not started yet
        Open, // The lottery is open for ticket purchases
        Closed, // The lottery is no longer open for ticket purchases
        Completed // The lottery has been closed and the numbers drawn
    }
    //EVENT Add Lottery
    event New_Lottery(Lottery _Lottery);

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "");
        _;
    }

    function Add_Lotttery(
        uint256 _Price,
        uint256 _Max_Ticket_Per_Wallet,
        uint256 _Start_Time,
        uint256 _End_Time,
        Payment_Methods _PM,
        address[] memory _Players
    ) public onlyOwner {
        Lotteries[_ID.current()] = Lottery(
            _Price,
            _Max_Ticket_Per_Wallet,
            _Start_Time,
            _End_Time,
            Status.NotStarted,
            _PM,
            _Players,
            0
        );
        emit New_Lottery(Lotteries[_ID.current()]);
        _ID.increment();
    }

    function Buy_Ticket(
        uint256 _Lottery_Id,
        uint256[] memory _Tickets_Codes,
        Payment_Methods _PM
    ) public payable callerIsUser {
        require(_Lottery_Id <= _ID.current(), "Lottery code not defined");

        require(
            Tickets[_Lottery_Id][msg.sender].length + _Tickets_Codes.length <
                Lotteries[_Lottery_Id].Max_Ticket_Per_Wallet,
            "Limit the number of tickets for each wallet"
        );

        require(
            getCurrentTime() >= Lotteries[_Lottery_Id].Start_Time,
            "This lottery has not started yet"
        );
        if (Lotteries[_Lottery_Id].Start_Time <= getCurrentTime()) {
            if (Lotteries[_Lottery_Id]._Status == Status.NotStarted) {
                Lotteries[_Lottery_Id]._Status = Status.Open;
            }
        }
        require(
            Lotteries[_Lottery_Id]._Status == Status.Open,
            "The lottery is not open"
        );

        if (_PM == Payment_Methods.BNB) {
            require(
                msg.value ==
                    Lotteries[_Lottery_Id].Price.mul(_Tickets_Codes.length)
            );
            Amount_Collected[_Lottery_Id] += msg.value;
        } else if (_PM == Payment_Methods.BUSD) {
            require(
                EIP20Interface(0xD92E713d051C37EbB2561803a3b5FBAbc4962431)
                    .transferFrom(
                        tx.origin,
                        address(this),
                        Lotteries[_Lottery_Id].Price.mul(_Tickets_Codes.length)
                    )
            );
            Amount_Collected[_Lottery_Id] +=Lotteries[_Lottery_Id].Price.mul(_Tickets_Codes.length); 
        } else {
            revert();
        }

        if (Tickets[_Lottery_Id][msg.sender].length == 0) {
            Lotteries[_Lottery_Id].Wallets.push(msg.sender);
        }
        for (uint256 index = 0; index < _Tickets_Codes.length; index++) {
            require(
                _Tickets_Codes[index] / 1000000 == 0,
                "Tickets have an unauthorized number"
            );
            Tickets[_Lottery_Id][msg.sender].push(_Tickets_Codes[index]);
            Sold_Tickets[_Lottery_Id].push(_Tickets_Codes[index]);
            
        }
        if(paid[_Lottery_Id][msg.sender] == 0){
            paid[_Lottery_Id][msg.sender] = 1;
        }

    }

    function Lottery_Status_Changer(uint256 _Lottery_Id, Status _Status)
        public
        onlyOwner
    {
        require(
            _Status != Status.Completed,
            "Can not Set Lottery Status to Completed with this Functions!!!"
        );
        require(Lotteries[_Lottery_Id]._Status != Status.Completed, "");
        Lotteries[_Lottery_Id]._Status = _Status;
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function Complete_Lottery(uint256 _Lottery_Id) public onlyOwner {
        require(
            Lotteries[_Lottery_Id].End_Time <= getCurrentTime(),
            "It is not time to complete the lottery"
        );
        require(
            Lotteries[_Lottery_Id]._Status != Status.Completed,
            "Lottery Completed"
        );
        Lotteries[_Lottery_Id]._Status = Status.Completed;
            Lotteries[_Lottery_Id].Win_Code = uint256(keccak256(abi.encode(block.timestamp, block.difficulty)))%1000000;
    }

    function Set_Price(uint256 _Lottery_Id, uint256 _Price) public onlyOwner {
        Lotteries[_Lottery_Id].Price = _Price;
    }

    function Get_User_Tickets(uint256 _Lottery_Id, address _Address)
        public
        view
        returns (uint256[] memory)
    {
        return Tickets[_Lottery_Id][_Address];
    }

    function Get_SoldOut_Tickets(uint256 _Lottery_Id)
        public
        view
        returns (uint256[] memory)
    {
        return Sold_Tickets[_Lottery_Id];
    }

    function Get_Wallets(uint256 _Lottery_Id)
        public
        view
        returns (address[] memory)
    {
        return Lotteries[_Lottery_Id].Wallets;
    }

        function Get_WinCode(uint256 _Lottery_Id)
        public
        view
        returns (uint256)
    {
        return Lotteries[_Lottery_Id].Win_Code;
    }

    function Claim_Reward(
        string memory _message,
        bytes memory _sig,
        uint256 _Lottery_Id,
        Payment_Methods _PM
    ) public callerIsUser {
        require(verify(_message, _sig) == Validator_Address, "invalid request");
        require(st2num(_message) <= Amount_Collected[_Lottery_Id], "");
        require(paid[_Lottery_Id][msg.sender] == 1, "invalid claim");

        if (_PM == Payment_Methods.BNB) {
            payable(msg.sender).transfer(st2num(_message));
        } else if (_PM == Payment_Methods.BUSD) {
            EIP20Interface(0xD92E713d051C37EbB2561803a3b5FBAbc4962431).transfer(
                    msg.sender,
                    st2num(_message)
                );
        }
        paid[_Lottery_Id][msg.sender] = 2;
    }

        function Set_Validator_Address(address _Validator) public onlyOwner {
        Validator_Address = _Validator;
    }

    function st2num(string memory numString) public pure returns (uint256) {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10**(exp - 1)));
        }
        return val;
    }
}
