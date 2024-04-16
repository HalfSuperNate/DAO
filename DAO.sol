// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/** 
 * @title DAO
 * @dev A decentralized autonomous organization for voting on proposals
 */
contract DAO {

    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }

    struct Proposal {
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public owner;
    address public chairperson;

    mapping(uint => mapping(address => Voter)) public voters;
    
    mapping(uint => Proposal[]) public proposals;
    uint256 round;

    mapping(uint => bytes32) public wonProposal;

    error NoRoundWinnerConfirmed(uint round);
    error RoundWinnerConfirmed(uint round);

    /** 
     * @dev Create a new ballot to choose one of 'proposalNames'.
     * @param proposalNames names of proposals
     */
    constructor(bytes32[] memory proposalNames) {
        owner = msg.sender;
        chairperson = msg.sender;
        voters[0][chairperson].weight = 1;

        for (uint i = 0; i < proposalNames.length; i++) {
            proposals[0].push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    /** 
     * @dev Create a new ballot round to choose one of 'proposalNames'.
     * @param proposalNames names of proposals
     */
    function createProposals(bytes32[] memory proposalNames) public {
        require(
            msg.sender == chairperson,
            "Only chairperson has access."
        );
        if(wonProposal[round].length <= 0) revert NoRoundWinnerConfirmed(round);
        uint _round = round + 1;
        for (uint i = 0; i < proposalNames.length; i++) {
            proposals[_round].push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
        round++;
    }

    /** 
     * @dev Give 'voter' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voter address of voter
     */
    function giveRightToVote(address voter) public {
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[round][voter].voted,
            "The voter already voted."
        );
        require(voters[round][voter].weight == 0);
        voters[round][voter].weight = 1;
    }

    //❌ Need to add interface for checking user wallet if they hold specific tokens
    // then assign vote weight for each held token for that wallet, marking those tokens as voted.

    /**
     * @dev Delegate your vote to the voter 'to' for this round.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        Voter storage sender = voters[round][msg.sender];
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[round][to].delegate != address(0)) {
            to = voters[round][to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[round][to];
        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[round][delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposal index of proposal in the proposals array
     */
    function vote(uint proposal) public {
        Voter storage sender = voters[round][msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[round][proposal].voteCount += sender.weight;
    }

    /** 
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningProposal_ index of winning proposal in the proposals array
     */
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals[round].length; p++) {
            if (proposals[round][p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[round][p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    /** 
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function winnerName() public view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[round][winningProposal()].name;
    }

    function confirmRoundWinner() external {
        require(
            admin(),
            "Only admins."
        );
        if(wonProposal[round].length != 0) revert RoundWinnerConfirmed(round);
        wonProposal[round] = proposals[round][winningProposal()].name;
    }

    function setChairperson(address _newChairperson) public {
        require(
            admin(),
            "Only admins."
        );
        chairperson = _newChairperson;
    }

    function setOwner(address _newOwner) public {
        require(
            admin(),
            "Only admins."
        );
        owner = _newOwner;
    }

    function admin() public view returns(bool) {
        if (msg.sender == owner || msg.sender == chairperson){
            return true;
        }
        // Not an Admin
        return false;
    }
}