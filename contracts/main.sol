// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RandomNumber.sol";

contract DealsGame is Ownable, Pausable, Random {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter private _ID;
    struct Lottery {
        string Name;
        uint256 Price;
        uint256 Max_Ticket_Per_Wallet;
        uint256 Start_Time;
        uint256 End_Time;
        int256[6] Winner_Precentage;
        Status _Status;
        Payment_Methods _Payment_Methods;
        address[] Wallets;
        uint256[] Win_Code;
    }

    mapping(uint256 => Lottery) public Lotteries;
    mapping(uint256 => mapping(address => uint256[])) Tickets;
    mapping(uint256 => uint256) Ticket_Amounts;
    mapping(uint256 => uint256) Points;

    uint256[] _b;

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

    function Add_Lotttery(
        string memory _Name,
        uint256 _Price,
        uint256 _Max_Ticket_Per_Wallet,
        uint256 _Start_Time,
        uint256 _End_Time,
        Payment_Methods _PM,
        address[] memory _Players
    ) public {
        Lotteries[_ID.current()] = Lottery(
            _Name,
            _Price,
            _Max_Ticket_Per_Wallet,
            _Start_Time,
            _End_Time,
            [],
            Status.NotStarted,
            _PM,
            _Players,
            0
        );
        Ticket_Amounts[_ID.current()] = 0;
        _ID.increment();
    }

    //payment
    function Buy_Ticket(uint256 _Lottery_Id, uint256[] memory _Tickets_Codes)
        public
    {
        require(_Lottery_Id <= _ID.current(), "Lottery code not defined");

        //payment

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

        if (Tickets[_Lottery_Id][msg.sender].length == 0) {
            Lotteries[_Lottery_Id].Wallets.push(msg.sender);
        }
        for (uint256 index = 0; index < _Tickets_Codes.length; index++) {
            require(
                _Tickets_Codes[index] / 1000000 == 0,
                "Tickets have an unauthorized number"
            );
            Tickets[_Lottery_Id][msg.sender].push(_Tickets_Codes[index]);
        }
    }

    function Lottery_Status_Changer(uint256 _Lottery_Id, Status _S)
        public
        onlyOwner
    {
        require(
            _S != Status.Completed,
            "Can not Set Lottery Status to Completed with this Functions!!!"
        );
        require(Lotteries[_Lottery_Id]._Status != Status.Completed, "");
        Lotteries[_Lottery_Id]._Status = _S;
    }

    function Complete_Lottery(uint256 _Lottery_Id, int256[6] memory _Precentage)
        public
        onlyOwner
    {
        require(
            Lotteries[_Lottery_Id].End_Time <= getCurrentTime(),
            "It is not time to complete the lottery"
        );
        require(
            Lotteries[_Lottery_Id]._Status != Status.Completed,
            "Lottery Completed"
        );
        Lotteries[_Lottery_Id].Winner_Precentage = _Precentage;
        Lotteries[_Lottery_Id]._Status = Status.Completed;
        for (uint256 index = 0; index < 6; index++) {
            Lotteries[_Lottery_Id].Win_Code.push(uint256(getRandomNumber()));
        }
    }

    function Claim_Reward(uint256 _Lottery_Id) public {
        for (uint256 index = 0; index < 6; index++) {
            Points[index] = 0;
        }
        require(Lotteries[_Lottery_Id]._Status == Status.Completed, "");
        require(Tickets[_Lottery_Id][msg.sender].length != 0, "");
        uint256[] memory _Sep_Ticket;
        for (
            uint256 index = 0;
            index < Tickets[_Lottery_Id][msg.sender].length;
            index++
        ) {
            _Sep_Ticket = Seperate(Tickets[_Lottery_Id][msg.sender][index]);

            uint256 point = 0;
            for (uint256 i = 0; i < 6; i++) {
                if (_Sep_Ticket[i] == Lotteries[_Lottery_Id].Win_Code[i]) {
                    point++;
                } else {
                    continue;
                }
            }
            Points[point] = Points[point] + 1;
        }

        int256 pay_amount = _Price_calc(_Lottery_Id);
        require(
            payable(msg.sender).transfer(
                ((Ticket_Amounts[_Lottery_Id] * Lotteries[_Lottery_Id].Price) /
                    100) * pay_amount,
                ""
            )
        );
        delete Tickets[_Lottery_Id][msg.sender];
    }

    function _Price_calc(uint256 _Lottery_Id) internal returns (int256) {
        int256 a;
        a += Points[1] * Lotteries[_Lottery_Id].Winner_Precentage[0];
        a += Points[2] * Lotteries[_Lottery_Id].Winner_Precentage[1];
        a += Points[3] * Lotteries[_Lottery_Id].Winner_Precentage[2];
        a += Points[4] * Lotteries[_Lottery_Id].Winner_Precentage[3];
        a += Points[5] * Lotteries[_Lottery_Id].Winner_Precentage[4];
        a += Points[6] * Lotteries[_Lottery_Id].Winner_Precentage[5];
        return a;
    }

    //Price Oracle

    function Set_Price(uint256 _Lottery_Id, uint256 _Price) public onlyOwner {
        Lotteries[_Lottery_Id].Price = _Price;
    }

    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function Seperate(uint256 _a) internal returns (uint256[] memory) {
        delete _b;
        _b.push(_a / 100000);
        _b.push((_a / 10000) % 10);
        _b.push((_a / 1000) % 10);
        _b.push((_a / 100) % 10);
        _b.push((_a / 10) % 10);
        _b.push(_a % 10);
        return _b;
    }

    function Get_Tickets(uint256 _Lottery_Id, address _Address)
        public
        view
        returns (uint256[] memory)
    {
        require(Lotteries[_Lottery_Id]._Status == Status.Closed, "");
        return Tickets[_Lottery_Id][_Address];
    }
}
