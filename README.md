# 🔮 Verifiable Oracle Registry

A decentralized, DAO-based oracle registry built on Stacks that ensures data integrity through community governance, staking mechanisms, and reputation tracking.

## 🎯 Overview

The Verifiable Oracle Registry addresses the critical trust problem in blockchain oracle systems by creating a transparent, community-governed registry where oracles are validated, ranked, and held accountable through on-chain mechanisms.

### ✨ Key Features

- 🗳️ **DAO Governance**: Community-driven oracle registration and management
- 💎 **Staking Mechanism**: Oracles must stake STX tokens to participate
- 📊 **Reputation System**: Dynamic reputation scoring based on performance
- ⚡ **Slashing Protection**: Automatic penalties for malicious behavior
- 🔍 **Audit Trail**: Complete transparency of oracle performance
- 🏆 **Reward System**: Incentives for accurate data providers

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd Verifiable-Oracle-Registry
clarinet check
```

## 📋 Contract Functions

### 🔐 Oracle Management

#### `register-oracle`
Register as a new oracle provider
```clarity
(register-oracle (stake uint) (metadata (string-ascii 256)))
```
- **stake**: Minimum 1,000,000 μSTX required
- **metadata**: Description of oracle service
- **Returns**: Oracle ID

#### `submit-data`
Submit oracle data for verification
```clarity
(submit-data (oracle-id uint) (data-hash (buff 32)) (metadata (string-ascii 256)))
```

#### `verify-report`
Verify submitted oracle data (community validation)
```clarity
(verify-report (oracle-id uint) (report-id uint) (is-valid bool))
```

### 🗳️ DAO Governance

#### `create-proposal`
Create governance proposal (slash, upgrade, etc.)
```clarity
(create-proposal (oracle-id uint) (proposal-type (string-ascii 10)) (description (string-ascii 256)))
```

#### `vote-on-proposal`
Vote on active proposals
```clarity
(vote-on-proposal (proposal-id uint) (vote bool))
```

#### `execute-proposal`
Execute passed proposals after voting period
```clarity
(execute-proposal (proposal-id uint))
```

### 💰 Staking Operations

#### `add-stake`
Add additional stake to increase voting power
```clarity
(add-stake (amount uint))
```

#### `withdraw-stake`
Withdraw available stake
```clarity
(withdraw-stake (amount uint))
```

## 📖 Usage Examples

### Registering as an Oracle

```clarity
;; Register with 2 STX stake
(contract-call? .verifiable-oracle-registry register-oracle u2000000 "Weather data oracle for NYC")
```

### Submitting Data

```clarity
;; Submit temperature data
(contract-call? .verifiable-oracle-registry submit-data u1 0x1234567890abcdef "Temperature: 25°C")
```

### Creating a Slash Proposal

```clarity
;; Propose to slash oracle #1 for false data
(contract-call? .verifiable-oracle-registry create-proposal u1 "slash" "Oracle provided false temperature data")
```

## 🔍 Read-Only Functions

### Query Oracle Information

```clarity
(get-oracle (oracle-id uint))                    ;; Get oracle details
(get-oracle-by-owner (owner principal))          ;; Find oracle by owner
(get-oracle-reputation (oracle-id uint))         ;; Get reputation score
(is-oracle-active (oracle-id uint))              ;; Check if oracle is active
```

### Query Proposals

```clarity
(get-proposal (proposal-id uint))                ;; Get proposal details
(get-voting-power (staker principal))            ;; Get voting power
```

### Query Reports

```clarity
(get-oracle-report (oracle-id uint) (report-id uint))  ;; Get specific report
```

## ⚙️ Configuration

### Constants

- **MIN-STAKE**: 1,000,000 μSTX (minimum stake required)
- **MIN-REPUTATION**: 100 (minimum reputation score)
- **VOTING-PERIOD**: 144 blocks (~24 hours)
- **SLASH-PERCENTAGE**: 20% (penalty for malicious oracles)
- **REWARD-PERCENTAGE**: 5% (reward for validators)

## 🛡️ Security Features

### Reputation System
- Dynamic scoring: `(successful_reports * 1000) / total_reports`
- Minimum reputation threshold for participation
- Reputation decay for slashed oracles

### Slashing Mechanism
- 20% stake penalty for proven malicious behavior
- Automatic status change to "slashed"
- Community-driven slash proposals

### Governance Safeguards
- Time-locked voting periods
- Weighted voting based on stake + oracle stake
- One vote per address per proposal

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `clarinet check && clarinet test`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co)
- [Clarity Language](https://docs.stacks.co/clarity)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)

---

Built with ❤️ for the Stacks ecosystem 🌟
