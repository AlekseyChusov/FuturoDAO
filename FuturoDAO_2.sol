// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/FuturoDAO_1.sol";
// ==============================
// Main Governance Contract
// ==============================
contract FuturoGovernance is Ownable {
    using SafeERC20 for IERC20;

    // Token contracts
    IERC20 public immutable ftrToken;
    IERC20 public immutable paymentToken; // USDC
    PriceOracle public oracle;

    constructor(
        address _ftrToken,
        address _paymentToken,
        address _oracle,
                address _owner

    )Ownable(_owner) {

        ftrToken = IERC20(_ftrToken);
        paymentToken = IERC20(_paymentToken);
        oracle = PriceOracle(_oracle);

    }
    // Proposal structure
    struct Proposal {
        uint256 id;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        uint256 strikePrice;
        uint256 expiryTime;
        address optionContract;
    }

    // Governance parameters
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant OPTION_EXPIRY = 365 days;
    uint256 public constant STRIKE_PREMIUM = 150; // 50% above current price
    uint256 public nextProposalId = 1;

    // Active proposals
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public lockedTokens;

    // Events
    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 proposalId, address voter, bool support, uint256 amount);
    event ProposalExecuted(uint256 id, address optionContract);
    event OptionsClaimed(address voter, uint256 proposalId, uint256 amount);



    // Create new proposal
    function createProposal(string calldata description) external {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            description: description,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            strikePrice: 0,
            expiryTime: 0,
            optionContract: address(0)
        });

        emit ProposalCreated(nextProposalId, description);
        nextProposalId++;
    }

    // Vote with token locking
    function vote(uint256 proposalId, bool support, uint256 amount) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Not started");
        require(block.timestamp < proposal.endTime, "Voting ended");
        
        // Lock tokens
        ftrToken.safeTransferFrom(msg.sender, address(this), amount);
        lockedTokens[proposalId][msg.sender] += amount;

        // Record votes
        if (support) {
            proposal.forVotes += amount;
        } else {
            proposal.againstVotes += amount;
        }

        emit Voted(proposalId, msg.sender, support, amount);
    }

    // Execute proposal and create options
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.endTime, "Voting ongoing");
        require(!proposal.executed, "Already executed");
        
        // Set option parameters
        proposal.strikePrice = oracle.getTWAP() * STRIKE_PREMIUM / 100;
        proposal.expiryTime = block.timestamp + OPTION_EXPIRY;
        
        // Create options contract
        BinaryOption options = new BinaryOption(
            address(paymentToken),
            address(oracle),
            address(this),
            proposal.strikePrice,
            proposal.expiryTime,
            proposal.forVotes + proposal.againstVotes
        );
        
        proposal.optionContract = address(options);
        proposal.executed = true;

        // Fund options contract
        paymentToken.safeTransfer(
            address(options), 
            proposal.forVotes + proposal.againstVotes
        );

        emit ProposalExecuted(proposalId, address(options));
    }

    // Claim options after execution
    function claimOptions(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.executed, "Proposal not executed");
        
        uint256 amount = lockedTokens[proposalId][msg.sender];
        require(amount > 0, "No tokens locked");
        
        lockedTokens[proposalId][msg.sender] = 0;
        BinaryOption(proposal.optionContract).distribute(msg.sender, amount);
        
        emit OptionsClaimed(msg.sender, proposalId, amount);
    }
}
