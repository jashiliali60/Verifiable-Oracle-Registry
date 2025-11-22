# Oracle Performance Leaderboard & Reward Multiplier System

## Feature Overview

This feature introduces a competitive leaderboard system that tracks oracle performance and rewards top performers with bonus multipliers.

## Value Proposition

- **Incentivizes Excellence**: Top-performing oracles earn up to 50% bonus rewards
- **Transparent Rankings**: Real-time performance scoring visible to all participants
- **Competitive Dynamics**: Creates healthy competition among oracle operators
- **Quality Assurance**: Naturally filters high-quality data providers to the top

## How It Works

### Performance Scoring Algorithm

Oracles are scored based on three key metrics:
- **Reputation** (weighted x100): Historical accuracy and reliability
- **Successful Reports** (weighted x10): Volume of verified accurate submissions
- **Stake Size** (weighted x0.00001): Financial commitment to the network

Formula: `score = (reputation × 100) + (successful_reports × 10) + (stake / 100000)`

### Reward Multipliers

- **Rank 1-3**: 150% of base reward (50% bonus)
- **Rank 4-7**: 125% of base reward (25% bonus)  
- **Rank 8-10**: 100% of base reward (no bonus)
- **Unranked**: 100% of base reward

### Key Functions

#### Read-Only Functions

- `get-performance-score(oracle-id)` - Returns calculated performance score
- `get-leaderboard-rank(oracle-id)` - Returns current rank or none
- `get-oracle-at-rank(rank)` - Returns oracle-id at specific rank
- `get-reward-multiplier(oracle-id)` - Returns multiplier percentage (100-150)

#### Public Functions

- `update-oracle-rank(oracle-id, new-rank)` - Owner can manually update rankings

### Automatic Updates

The leaderboard automatically updates performance scores when:
- Oracle data is verified as valid
- Rewards are distributed

Slashed oracles are automatically removed from the leaderboard.

## Technical Implementation

### Data Structures

```clarity
(define-map leaderboard-positions
  { oracle-id: uint }
  { rank: uint, performance-score: uint }
)

(define-map leaderboard-rankings
  { rank: uint }
  { oracle-id: uint }
)
```

### Constants

- `LEADERBOARD-SIZE`: Top 10 oracles tracked

### Integration Points

- Integrated with `verify-report` function for automatic score updates
- Integrated with `distribute-reward` for multiplier application
- Integrated with `slash-oracle` for removal on penalties

## Usage Examples

### Check Your Rank
```clarity
(contract-call? .verifiable-oracle-registry get-leaderboard-rank u1)
```

### View Performance Score
```clarity
(contract-call? .verifiable-oracle-registry get-performance-score u1)
```

### See Top Oracle
```clarity
(contract-call? .verifiable-oracle-registry get-oracle-at-rank u1)
```

### Check Reward Multiplier
```clarity
(contract-call? .verifiable-oracle-registry get-reward-multiplier u1)
```

## Benefits for Ecosystem

1. **For Oracle Operators**: Direct financial incentive to maintain high quality
2. **For Data Consumers**: Easy identification of reliable oracle sources
3. **For Network**: Self-regulating quality control mechanism
4. **For Governance**: Objective metrics for oracle evaluation

## Future Enhancements

- Automated rank calculation and updates
- Historical leaderboard tracking
- Seasonal competitions with special rewards
- Integration with reputation decay over inactivity
