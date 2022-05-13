// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./timer.sol";

contract DealsGame is Ownable, Pausable, Timer {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter private _ID;
    struct Lottery {
        string Name;
        uint256 Price;
        uint256 Max_Ticket;
        uint256 Max_Ticket_Per_Wallet;
        uint256 Start_Time;
        uint256 End_Time;
        uint256[5] Winner_Precentage;
        Status _Status;
        Payment_Methods _Payment_Methods;
        address[] Wallets;
    }

    mapping(uint256 => Lottery) public Lotteries;
    mapping(uint256 => mapping(address => uint256[])) Tickets;
    mapping(uint256 => uint256) Ticket_Amounts;

    enum Payment_Methods {
        Ethereum,
        Tether
    }
    // Represents the status of the lottery
    enum Status {
        NotStarted, // The lottery has not started yet
        Open, // The lottery is open for ticket purchases
        Closed, // The lottery is no longer open for ticket purchases
        Completed // The lottery has been closed and the numbers drawn
    }

    function Add_Lotttery(
        string memory _Name,
        uint256 _Price,
        uint256 _Max_Ticket,
        uint256 _Max_Ticket_Per_Wallet,
        uint256 _Start_Time,
        uint256 _End_Time,
        uint256[5] memory _Winner_Precentage,
        Status _Status,
        Payment_Methods _PM,
        address[] memory _Players
    ) public {
        Lotteries[_ID.current()] = Lottery(
            _Name,
            _Price,
            _Max_Ticket,
            _Max_Ticket_Per_Wallet,
            _Start_Time,
            _End_Time,
            _Winner_Precentage,
            _Status,
            _PM,
            _Players
        );
        Ticket_Amounts[_ID.current()] = 0;
        _ID.increment();
    }

    function Buy_Ticket(uint256 _Lottery_Id, uint256[] memory _Tickets_Codes)
        public
    {
        require(_Lottery_Id <= _ID.current(), "");
        //payment
        require(Ticket_Amounts[_Lottery_Id] < _Tickets_Codes.length, "");
        require(
            Tickets[_Lottery_Id][msg.sender].length < _Tickets_Codes.length,
            ""
        );
        require(getCurrentTime() >= Lotteries[_Lottery_Id].Start_Time, "");
        if (Lotteries[_Lottery_Id].Start_Time <= getCurrentTime()) {
            if (Lotteries[_Lottery_Id]._Status == Status.NotStarted) {
                Lotteries[_Lottery_Id]._Status = Status.Open;
            }
        }
        require(Lotteries[_Lottery_Id]._Status == Status.Open, "");

    }
}
