// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Voting
 * @dev Voting system use in Alyra formation
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Voting is Ownable{

    event VoterRegistered(address voterAddress); 
    event VoterRevoked(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
        }

    struct Proposal {
        string description;
        uint voteCount;
        }

    modifier isRegistered{
         require (voters[msg.sender].isRegistered==true,"You are not authorized.");
         _;
    }

    modifier hasState(WorkflowStatus status){
         require (currentStatus == status,"You can't do that at this state of the voting process.");
         _;
    }

    mapping (address => Voter) voters;
    Proposal[] proposals;
    uint winningProposalId;

    WorkflowStatus currentStatus = WorkflowStatus.RegisteringVoters;



   /*
    Admin only actions, related to the workflow
   */
    function registerVoter(address _voterAddress) public onlyOwner{
        //Admin always have rights to add voters, regardless state of voting
        require (voters[_voterAddress].isRegistered == false, "This voter is already registered.");

        voters[_voterAddress] = Voter({isRegistered : true, hasVoted : false, votedProposalId : 0});
        emit VoterRegistered(_voterAddress);
    }

    function revokeVoter(address _voterAddress) public onlyOwner {
        require (voters[_voterAddress].isRegistered == true, "This voter is not registered.");

        //As we revoke the voter, we should rollback his vote
        if(voters[_voterAddress].hasVoted){
            proposals[voters[_voterAddress].votedProposalId].voteCount--;
        }

        delete voters[_voterAddress];

        //If vote has been tailled, we should refresh results
        if(currentStatus == WorkflowStatus.VotesTallied){
            selectWinner();
        }
        emit VoterRevoked(_voterAddress);
    }

    function startRegistration() public onlyOwner hasState(WorkflowStatus.RegisteringVoters){
        changeSessionStatus(WorkflowStatus.ProposalsRegistrationStarted);
    }

    function stopRegistration() public onlyOwner hasState(WorkflowStatus.ProposalsRegistrationStarted){
        changeSessionStatus(WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() public onlyOwner hasState(WorkflowStatus.ProposalsRegistrationEnded){
        changeSessionStatus(WorkflowStatus.VotingSessionStarted);
    }

    function stopVotingSession() public onlyOwner hasState(WorkflowStatus.VotingSessionStarted){
        changeSessionStatus(WorkflowStatus.VotingSessionEnded);
    }

    // In case of equality first proposal is taken.
    function selectWinner() public onlyOwner hasState(WorkflowStatus.VotingSessionEnded){
        for(uint i = 0 ; i < proposals.length ; i++){
            if(proposals[i].voteCount > proposals[winningProposalId].voteCount){
                winningProposalId = i;
            }
        }

        changeSessionStatus(WorkflowStatus.VotesTallied);
    }

    function sendMoney(address to, uint value) public onlyOwner{
        require(address(this).balance>=value, "Not enouph balance to send money.");
        address payable receiver = payable(to);
        receiver.transfer(value);
    }

    function changeSessionStatus(WorkflowStatus newStatus) private {
        emit WorkflowStatusChange(currentStatus, newStatus);
        currentStatus = newStatus;
    }

    /*
    User action

    */

    //Payable in case someone want to pay a bribe, won't change anything as we are incorruptible.
    function addProposal(string memory proposalDescription) public payable isRegistered hasState(WorkflowStatus.ProposalsRegistrationStarted){
        proposals.push(Proposal({description:proposalDescription,voteCount:0}));
        emit ProposalRegistered(proposals.length-1);
    }


    //Payable in case someone want to pay a bribe, won't change anything as we are incorruptible.
    function addVote(uint proposalId) public payable isRegistered hasState(WorkflowStatus.VotingSessionStarted){
        require (voters[msg.sender].hasVoted == false, "You have already voted for that session.");
        require (proposalId < proposals.length, "This proposal does not exists.");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = proposalId;
        proposals[proposalId].voteCount++;

        emit Voted(msg.sender,proposalId);
    }

    function getProposals() public isRegistered view returns(Proposal[] memory)  {
        return proposals;
    }

    function getVoters(address _voterAddress) public isRegistered view returns(Voter memory)  {
        require (voters[_voterAddress].isRegistered == true, "This voter does not exists.");
        return voters[_voterAddress];
    }

    function getWinner() public isRegistered hasState(WorkflowStatus.VotesTallied) view returns(Proposal memory)   {
        return proposals[winningProposalId];
    }

    function findProposalId(string memory proposalDescription) public view returns(uint){
        for(uint i = 0 ; i< proposals.length ; i ++){
            if(keccak256(abi.encodePacked((proposals[i].description))) == keccak256(abi.encodePacked((proposalDescription)))){
                return i;
            }
        }
        revert ("No proposition founded.");
    }

    function getVotingSessionCurrentState() public view returns (string memory){
        if(currentStatus == WorkflowStatus.RegisteringVoters){
            return "Session have not started yet.";
        }
        if(currentStatus == WorkflowStatus.ProposalsRegistrationStarted){
            return "Proposals registration is started, you can add your proposal.";
        }
        if(currentStatus == WorkflowStatus.ProposalsRegistrationEnded){
            return "Proposals registration is ended, no more proposal can be submited.";
        }
        if(currentStatus == WorkflowStatus.VotingSessionStarted){
            return "Vote session is started, you can vote for your favorite proposal.";
        }
        if(currentStatus == WorkflowStatus.VotingSessionEnded){
            return "Vote session is ended, votes are not allowed anymore.";
        }
        if(currentStatus == WorkflowStatus.VotesTallied){
            return "Votes have been tailled, you can consult the winner.";
        }
        return "Not able to give information about the session at this time.";
    }

    }