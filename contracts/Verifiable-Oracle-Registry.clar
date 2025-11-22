
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-ORACLE-NOT-FOUND (err u1001))
(define-constant ERR-INSUFFICIENT-STAKE (err u1002))
(define-constant ERR-ORACLE-ALREADY-EXISTS (err u1003))
(define-constant ERR-VOTING-PERIOD-EXPIRED (err u1004))
(define-constant ERR-ALREADY-VOTED (err u1005))
(define-constant ERR-INVALID-PROPOSAL (err u1006))
(define-constant ERR-ORACLE-SLASHED (err u1007))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u1008))
(define-constant ERR-CANNOT-DELEGATE-TO-SELF (err u1009))
(define-constant ERR-NO-DELEGATION-FOUND (err u1010))
(define-constant ERR-NOT-IN-LEADERBOARD (err u1011))

(define-constant MIN-STAKE u1000000)
(define-constant MIN-REPUTATION u100)
(define-constant VOTING-PERIOD u144)
(define-constant SLASH-PERCENTAGE u20)
(define-constant REWARD-PERCENTAGE u5)
(define-constant LEADERBOARD-SIZE u10)

(define-data-var contract-owner principal tx-sender)
(define-data-var total-oracles uint u0)
(define-data-var proposal-counter uint u0)

(define-map oracles
  { oracle-id: uint }
  {
    owner: principal,
    stake: uint,
    reputation: uint,
    total-reports: uint,
    successful-reports: uint,
    last-activity: uint,
    status: (string-ascii 10),
    registration-height: uint
  }
)

(define-map oracle-owners
  { owner: principal }
  { oracle-id: uint }
)

(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    oracle-id: uint,
    proposal-type: (string-ascii 10),
    description: (string-ascii 256),
    votes-for: uint,
    votes-against: uint,
    creation-height: uint,
    status: (string-ascii 10)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map oracle-reports
  { oracle-id: uint, report-id: uint }
  {
    data-hash: (buff 32),
    timestamp: uint,
    verified: bool,
    challenger: (optional principal)
  }
)

(define-map staker-balances
  { staker: principal }
  { amount: uint }
)

(define-map delegations
  { delegator: principal }
  { delegate: principal }
)

(define-map delegation-power
  { delegate: principal }
  { total-power: uint }
)

(define-map leaderboard-positions
  { oracle-id: uint }
  { rank: uint, performance-score: uint }
)

(define-map leaderboard-rankings
  { rank: uint }
  { oracle-id: uint }
)

(define-public (register-oracle (stake uint) (metadata (string-ascii 256)))
  (let
    (
      (oracle-id (+ (var-get total-oracles) u1))
      (caller tx-sender)
    )
    (asserts! (>= stake MIN-STAKE) ERR-INSUFFICIENT-STAKE)
    (asserts! (is-none (map-get? oracle-owners { owner: caller })) ERR-ORACLE-ALREADY-EXISTS)
    
    (try! (stx-transfer? stake caller (as-contract tx-sender)))
    
    (map-set oracles
      { oracle-id: oracle-id }
      {
        owner: caller,
        stake: stake,
        reputation: u100,
        total-reports: u0,
        successful-reports: u0,
        last-activity: stacks-block-height,
        status: "active",
        registration-height: stacks-block-height
      }
    )
    
    (map-set oracle-owners { owner: caller } { oracle-id: oracle-id })
    (var-set total-oracles oracle-id)
    
    (ok oracle-id)
  )
)

(define-public (submit-data (oracle-id uint) (data-hash (buff 32)) (metadata (string-ascii 256)))
  (let
    (
      (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND))
      (caller tx-sender)
      (report-id (+ (get total-reports oracle-data) u1))
    )
    (asserts! (is-eq (get owner oracle-data) caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status oracle-data) "active") ERR-ORACLE-SLASHED)
    
    (map-set oracle-reports
      { oracle-id: oracle-id, report-id: report-id }
      {
        data-hash: data-hash,
        timestamp: stacks-block-height,
        verified: false,
        challenger: none
      }
    )
    
    (map-set oracles
      { oracle-id: oracle-id }
      (merge oracle-data {
        total-reports: report-id,
        last-activity: stacks-block-height
      })
    )
    
    (ok report-id)
  )
)

(define-public (verify-report (oracle-id uint) (report-id uint) (is-valid bool))
  (let
    (
      (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND))
      (report-data (unwrap! (map-get? oracle-reports { oracle-id: oracle-id, report-id: report-id }) ERR-ORACLE-NOT-FOUND))
      (caller tx-sender)
      (new-successful (if is-valid (+ (get successful-reports oracle-data) u1) (get successful-reports oracle-data)))
      (new-reputation (calculate-reputation (get total-reports oracle-data) new-successful))
    )
    (asserts! (not (is-eq caller (get owner oracle-data))) ERR-NOT-AUTHORIZED)
    
    (map-set oracle-reports
      { oracle-id: oracle-id, report-id: report-id }
      (merge report-data { verified: true, challenger: (some caller) })
    )
    
    (map-set oracles
      { oracle-id: oracle-id }
      (merge oracle-data {
        successful-reports: new-successful,
        reputation: new-reputation
      })
    )
    
    (if is-valid
      (begin 
        (try! (distribute-reward oracle-id caller))
        (let
          (
            (current-score (get-performance-score oracle-id))
          )
          (map-set leaderboard-positions
            { oracle-id: oracle-id }
            { rank: u0, performance-score: current-score }
          )
        )
        true
      )
      (begin (try! (slash-oracle oracle-id)) true)
    )
    
    (ok is-valid)
  )
)

(define-public (create-proposal (oracle-id uint) (proposal-type (string-ascii 10)) (description (string-ascii 256)))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (caller tx-sender)
    )
    (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND)
    
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: caller,
        oracle-id: oracle-id,
        proposal-type: proposal-type,
        description: description,
        votes-for: u0,
        votes-against: u0,
        creation-height: stacks-block-height,
        status: "active"
      }
    )
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL))
      (caller tx-sender)
      (voting-power (get-voting-power caller))
      (current-height stacks-block-height)
    )
    (asserts! (< (- current-height (get creation-height proposal-data)) VOTING-PERIOD) ERR-VOTING-PERIOD-EXPIRED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: caller })) ERR-ALREADY-VOTED)
    (asserts! (> voting-power u0) ERR-INSUFFICIENT-STAKE)
    
    (map-set votes
      { proposal-id: proposal-id, voter: caller }
      { vote: vote, voting-power: voting-power }
    )
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal-data {
        votes-for: (if vote (+ (get votes-for proposal-data) voting-power) (get votes-for proposal-data)),
        votes-against: (if vote (get votes-against proposal-data) (+ (get votes-against proposal-data) voting-power))
      })
    )
    
    (ok vote)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-INVALID-PROPOSAL))
      (current-height stacks-block-height)
    )
    (asserts! (>= (- current-height (get creation-height proposal-data)) VOTING-PERIOD) ERR-VOTING-PERIOD-EXPIRED)
    (asserts! (is-eq (get status proposal-data) "active") ERR-INVALID-PROPOSAL)
    
    (let
      (
        (votes-for (get votes-for proposal-data))
        (votes-against (get votes-against proposal-data))
        (proposal-passed (> votes-for votes-against))
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal-data { status: (if proposal-passed "executed" "rejected") })
      )
      
      (if (and proposal-passed (is-eq (get proposal-type proposal-data) "slash"))
        (begin (try! (slash-oracle (get oracle-id proposal-data))) true)
        true
      )
      
      (ok proposal-passed)
    )
  )
)

(define-public (add-stake (amount uint))
  (let
    (
      (caller tx-sender)
      (current-balance (default-to u0 (get amount (map-get? staker-balances { staker: caller }))))
    )
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    
    (map-set staker-balances
      { staker: caller }
      { amount: (+ current-balance amount) }
    )
    
    (ok (+ current-balance amount))
  )
)

(define-public (withdraw-stake (amount uint))
  (let
    (
      (caller tx-sender)
      (current-balance (default-to u0 (get amount (map-get? staker-balances { staker: caller }))))
    )
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-STAKE)
    
    (map-set staker-balances
      { staker: caller }
      { amount: (- current-balance amount) }
    )
    
    (try! (as-contract (stx-transfer? amount tx-sender caller)))
    (ok (- current-balance amount))
  )
)

(define-public (delegate-voting-power (delegate principal))
  (let
    (
      (delegator tx-sender)
      (delegator-power (get-voting-power delegator))
      (existing-delegation (map-get? delegations { delegator: delegator }))
    )
    (asserts! (not (is-eq delegator delegate)) ERR-CANNOT-DELEGATE-TO-SELF)
    (asserts! (> delegator-power u0) ERR-INSUFFICIENT-STAKE)
    
    (match existing-delegation
      prev-delegation
      (let
        (
          (old-delegate (get delegate prev-delegation))
          (old-delegate-power (default-to u0 (get total-power (map-get? delegation-power { delegate: old-delegate }))))
        )
        (map-set delegation-power
          { delegate: old-delegate }
          { total-power: (if (>= old-delegate-power delegator-power) (- old-delegate-power delegator-power) u0) }
        )
      )
      true
    )
    
    (let
      (
        (current-delegate-power (default-to u0 (get total-power (map-get? delegation-power { delegate: delegate }))))
      )
      (map-set delegation-power
        { delegate: delegate }
        { total-power: (+ current-delegate-power delegator-power) }
      )
    )
    
    (map-set delegations
      { delegator: delegator }
      { delegate: delegate }
    )
    
    (ok delegate)
  )
)

(define-public (undelegate-voting-power)
  (let
    (
      (delegator tx-sender)
      (delegation-data (unwrap! (map-get? delegations { delegator: delegator }) ERR-NO-DELEGATION-FOUND))
      (delegate (get delegate delegation-data))
      (delegator-power (get-voting-power delegator))
      (current-delegate-power (default-to u0 (get total-power (map-get? delegation-power { delegate: delegate }))))
    )
    (map-set delegation-power
      { delegate: delegate }
      { total-power: (if (>= current-delegate-power delegator-power) (- current-delegate-power delegator-power) u0) }
    )
    
    (map-delete delegations { delegator: delegator })
    (ok true)
  )
)

(define-read-only (get-oracle (oracle-id uint))
  (map-get? oracles { oracle-id: oracle-id })
)

(define-read-only (get-oracle-by-owner (owner principal))
  (match (map-get? oracle-owners { owner: owner })
    oracle-data (map-get? oracles { oracle-id: (get oracle-id oracle-data) })
    none
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-oracle-report (oracle-id uint) (report-id uint))
  (map-get? oracle-reports { oracle-id: oracle-id, report-id: report-id })
)

(define-read-only (get-voting-power (staker principal))
  (let
    (
      (stake-balance (default-to u0 (get amount (map-get? staker-balances { staker: staker }))))
      (oracle-data (get-oracle-by-owner staker))
      (base-power (match oracle-data
        oracle (+ stake-balance (get stake oracle))
        stake-balance
      ))
      (delegated-to-staker (default-to u0 (get total-power (map-get? delegation-power { delegate: staker }))))
    )
    (+ base-power delegated-to-staker)
  )
)

(define-read-only (get-delegation (delegator principal))
  (map-get? delegations { delegator: delegator })
)

(define-read-only (get-delegated-power (delegate principal))
  (default-to u0 (get total-power (map-get? delegation-power { delegate: delegate })))
)

(define-read-only (get-oracle-reputation (oracle-id uint))
  (match (get-oracle oracle-id)
    oracle-data (some (get reputation oracle-data))
    none
  )
)

(define-read-only (get-total-oracles)
  (var-get total-oracles)
)

(define-read-only (is-oracle-active (oracle-id uint))
  (match (get-oracle oracle-id)
    oracle-data (is-eq (get status oracle-data) "active")
    false
  )
)

(define-read-only (get-performance-score (oracle-id uint))
  (match (get-oracle oracle-id)
    oracle-data
    (let
      (
        (reputation (get reputation oracle-data))
        (total-reports (get total-reports oracle-data))
        (successful-reports (get successful-reports oracle-data))
        (stake (get stake oracle-data))
      )
      (if (is-eq total-reports u0)
        u0
        (+ (* reputation u100) (* successful-reports u10) (/ stake u100000))
      )
    )
    u0
  )
)

(define-read-only (get-leaderboard-rank (oracle-id uint))
  (match (map-get? leaderboard-positions { oracle-id: oracle-id })
    position (some (get rank position))
    none
  )
)

(define-read-only (get-oracle-at-rank (rank uint))
  (match (map-get? leaderboard-rankings { rank: rank })
    ranking (some (get oracle-id ranking))
    none
  )
)

(define-read-only (get-reward-multiplier (oracle-id uint))
  (match (get-leaderboard-rank oracle-id)
    rank
    (if (<= rank u3)
      u150
      (if (<= rank u7)
        u125
        u100
      )
    )
    u100
  )
)

(define-private (calculate-reputation (total-reports uint) (successful-reports uint))
  (if (is-eq total-reports u0)
    u100
    (/ (* successful-reports u1000) total-reports)
  )
)

(define-private (slash-oracle (oracle-id uint))
  (let
    (
      (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND))
      (slash-amount (/ (* (get stake oracle-data) SLASH-PERCENTAGE) u100))
    )
    (map-set oracles
      { oracle-id: oracle-id }
      (merge oracle-data {
        stake: (- (get stake oracle-data) slash-amount),
        reputation: (/ (get reputation oracle-data) u2),
        status: "slashed"
      })
    )
    (match (get-leaderboard-rank oracle-id)
      rank (map-delete leaderboard-positions { oracle-id: oracle-id })
      true
    )
    (ok slash-amount)
  )
)

(define-private (distribute-reward (oracle-id uint) (verifier principal))
  (let
    (
      (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND))
      (base-reward (/ (* (get stake oracle-data) REWARD-PERCENTAGE) u100))
      (multiplier (get-reward-multiplier oracle-id))
      (reward-amount (/ (* base-reward multiplier) u100))
    )
    (as-contract (stx-transfer? reward-amount tx-sender verifier))
  )
)

(define-public (update-oracle-rank (oracle-id uint) (new-rank uint))
  (let
    (
      (caller tx-sender)
      (oracle-data (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR-ORACLE-NOT-FOUND))
      (current-score (get-performance-score oracle-id))
    )
    (asserts! (is-eq caller (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rank LEADERBOARD-SIZE) ERR-NOT-IN-LEADERBOARD)
    
    (map-set leaderboard-positions
      { oracle-id: oracle-id }
      { rank: new-rank, performance-score: current-score }
    )
    
    (map-set leaderboard-rankings
      { rank: new-rank }
      { oracle-id: oracle-id }
    )
    
    (ok true)
  )
)

