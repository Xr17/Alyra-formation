// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

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
    event Authorized(address _address); 
    event AuthorizationRevoked(address _address);

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

    modifier authorized{
         require (voters[msg.sender]==true,"You are not authorized.");
         _;
    }

    mapping (address => bool) voters;
    Proposal[] proposals;
    uint winningProposalId;

    WorkflowStatus currentStatus = WorkflowStatus.RegisteringVoters;

    //Admin always have rights to add voters, regardless state of voting

    function registerVoter(address _voterAddress) public onlyOwner {
        voters[_voterAddress] = true;
        emit VoterRegistered(_voterAddress);
    }

    function revokeVoter(address _voterAddress) public onlyOwner {
        delete voters[_voterAddress];

        //delete voter vote

        emit VoterRevoked(_voterAddress);
    }

    function startRegistration() public onlyOwner{
        changeSessionStatus(WorkflowStatus.RegisteringVoters,WorkflowStatus.ProposalsRegistrationStarted);
    }

    function stopRegistration() public onlyOwner{ 
        changeSessionStatus(WorkflowStatus.ProposalsRegistrationStarted,WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() public onlyOwner { 
        changeSessionStatus(WorkflowStatus.ProposalsRegistrationEnded,WorkflowStatus.VotingSessionStarted);
    }

    function stopVotingSession() public onlyOwner { 
      changeSessionStatus(WorkflowStatus.VotingSessionStarted,WorkflowStatus.VotingSessionEnded);
    }

    function selectWinner() public onlyOwner { 
        // todo select winner
      changeSessionStatus(WorkflowStatus.VotingSessionEnded,WorkflowStatus.VotesTallied);
    }

    function changeSessionStatus(WorkflowStatus expectedState, WorkflowStatus newState) private {
        require (currentStatus == expectedState, "Current workflow status does not allow this change.");

        currentStatus = newState;

        emit WorkflowStatusChange(expectedState, newState);
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
