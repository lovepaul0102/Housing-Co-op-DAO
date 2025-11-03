# 🏠 Housing Co-op DAO

A decentralized autonomous organization for shared residential property ownership and democratic maintenance decision-making on the Stacks blockchain.

## 🌟 Features

- 🤝 **Shared Ownership**: Buy shares in residential property
- 🗳️ **Democratic Voting**: Vote on maintenance proposals based on share ownership
- 💰 **Transparent Funding**: Pool resources for property maintenance
- 📊 **Maintenance Records**: Track all maintenance activities and costs
- 🚪 **Flexible Membership**: Join or leave the co-op at any time

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet with STX tokens

### Installation

```bash
clarinet new housing-coop-dao
cd housing-coop-dao
```

Copy the contract code into `contracts/housing-coop-dao.clar`

## 📋 Usage

### Initialize Property

The contract owner must first initialize the property:

```clarity
(contract-call? .housing-coop-dao initialize-property "123 Main St, City, State" u1000000)
```

### Join the Co-op

Purchase shares to become a member:

```clarity
(contract-call? .housing-coop-dao join-coop u10)
```

### Create Maintenance Proposal

Members can propose maintenance work:

```clarity
(contract-call? .housing-coop-dao create-proposal 
  "Roof Repair" 
  "Fix leaking roof in building A" 
  u50000 
  "maintenance")
```

### Vote on Proposals

Vote using your shares as voting power:

```clarity
(contract-call? .housing-coop-dao vote-on-proposal u1 true)
```

### Execute Approved Proposals

Execute proposals that have passed:

```clarity
(contract-call? .housing-coop-dao execute-proposal u1)
```

### Record Completed Maintenance

Document maintenance work:

```clarity
(contract-call? .housing-coop-dao record-maintenance 
  "Roof repair completed successfully" 
  u45000 
  "ABC Roofing Co")
```

## 🔍 Read-Only Functions

- `get-member-info`: View member details
- `get-proposal`: View proposal information
- `get-property-info`: View property details
- `get-contract-balance`: Check DAO treasury
- `get-maintenance-record`: View maintenance history

## 🏗️ Contract Architecture

### Core Components

1. **Membership System**: Share-based ownership with STX payments
2. **Proposal System**: Democratic voting with quorum requirements
3. **Treasury Management**: Automated fund distribution for approved proposals
4. **Maintenance Tracking**: Complete record of property maintenance

### Voting Mechanism

- Voting power proportional to share ownership
- 50% quorum requirement for proposal execution
- Simple majority (>50% of votes cast) needed to pass
- 144 block voting period (~24 hours)

## 🛡️ Security Features

- Member-only proposal creation and voting
- Quorum requirements prevent minority control
- Automated fund management reduces human error
- Immutable maintenance records

## 🧪 Testing

```bash
clarinet test
```

## 📄 License

MIT License - feel free to fork and modify for your housing co-op needs!

## 🤝 Contributing

Pull requests welcome! Please ensure all tests pass and follow the existing code style.

---

*Built with ❤️ for cooperative housing communities*
```

**Git Commit Message:**
```
feat: implement housing co-op DAO with share-based voting and maintenance proposals
```

**GitHub Pull Request Title:**
```
🏠 Add Housing Co-op DAO MVP with Democratic Maintenance Voting
```

**GitHub Pull Request Description:**
```
## Summary
Implements a complete Housing Co-op DAO smart contract that enables shared residential property ownership and democratic decision-making for maintenance activities.

## Features Added
- Share-based membership system with STX payments
- Proposal creation and voting mechanism for maintenance decisions
- Automated treasury management for approved proposals
- Comprehensive maintenance record tracking
- Member onboarding/offboarding functionality

## Technical Details
- 150+ lines of clean Clarity code
- Quorum-based voting (50% participation required)
- Proportional voting power based on share ownership
- 144-block voting periods with automatic execution
- Complete error handling and validation

## Testing
- All core functions implemented and ready for testing
- Includes comprehensive README with usage examples
- Ready for Clarinet test suite integration

This MVP provides a solid foundation for housing cooperatives to manage shared property ownership and maintenance decisions on the Stacks blockchain.
