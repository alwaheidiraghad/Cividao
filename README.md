# 🏛️ Cividao - Constitutional DAO

A decentralized autonomous organization with constitutional governance and amendment capabilities built on Stacks blockchain.

## 📋 Overview

Cividao implements a sophisticated governance structure that allows community members to:
- 🗳️ Create and vote on proposals
- 📜 Draft and ratify constitutional amendments
- 🤝 Participate in democratic decision-making
- ⚖️ Maintain constitutional order through structured governance

## ✨ Features

### 🏛️ Core Governance
- **Member Management**: Join/leave DAO with voting power allocation
- **Proposal System**: Create, vote on, and execute community proposals
- **Constitutional Amendments**: Draft, vote on, and ratify constitutional changes
- **Quorum Requirements**: Configurable voting thresholds for decision validity

### 🔧 Administrative Functions
- **Voting Period Configuration**: Adjustable proposal voting windows
- **Quorum Management**: Dynamic quorum percentage settings
- **Amendment Supersession**: Ability to supersede outdated amendments

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new my-cividao-project
cd my-cividao-project
```

Copy the contract code to `contracts/Cividao.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage Guide

### 🤝 Joining the DAO

```clarity
(contract-call? .Cividao join-dao)
```

### 📝 Creating a Proposal

```clarity
(contract-call? .Cividao create-proposal 
  "Infrastructure Upgrade" 
  "Proposal to upgrade our technical infrastructure" 
  "technical")
```

### 🗳️ Voting on Proposals

```clarity
(contract-call? .Cividao vote-on-proposal u1 true)
```

### 📜 Creating Constitutional Amendments

```clarity
(contract-call? .Cividao create-constitutional-amendment 
  "Voting Rights Amendment" 
  "This amendment establishes expanded voting rights for all members")
```

### ⚖️ Voting on Amendments

```clarity
(contract-call? .Cividao vote-on-amendment u1 true)
```

### ✅ Executing Proposals

```clarity
(contract-call? .Cividao execute-proposal u1)
```

## 🔍 Read-Only Functions

- `get-member-status`: Check if address is DAO member
- `get-proposal`: Retrieve proposal details
- `get-amendment`: Get constitutional amendment info
- `get-total-members`: Current DAO membership count
- `is-proposal-active`: Check if proposal voting is active

## ⚙️ Configuration

### Quorum Settings
Default quorum is set to 51% of total members. Administrators can adjust:

```clarity
(contract-call? .Cividao update-quorum u60)
```

### Voting Period
Default voting period is 1440 blocks (~10 days). Adjust with:

```clarity
(contract-call? .Cividao update-voting-period u2880)
```

## 🛡️ Security Features

- ✅ Member-only proposal creation and voting
- ✅ Double-voting prevention
- ✅ Quorum enforcement for proposal execution
- ✅ Super-majority requirements for constitutional amendments
- ✅ Administrative controls for critical parameters

## 📊 Governance Structure

### Proposal Types
- **Standard Proposals**: Regular community decisions (51% quorum)
- **Constitutional Amendments**: Fundamental changes (102% quorum - double majority)

### Voting Power
- Each member receives 1 voting power upon joining
- Equal representation for all community members

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes with Clarinet
4. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.


