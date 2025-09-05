(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_MEMBER (err u101))
(define-constant ERR_NOT_MEMBER (err u102))
(define-constant ERR_INSUFFICIENT_SHARES (err u103))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_PROPOSAL_EXPIRED (err u106))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u107))
(define-constant ERR_INSUFFICIENT_FUNDS (err u108))
(define-constant ERR_INVALID_AMOUNT (err u109))
(define-constant ERR_RENT_NOT_SET (err u110))
(define-constant ERR_RENT_ALREADY_PAID (err u111))
(define-constant ERR_RENT_PERIOD_NOT_STARTED (err u112))

(define-constant REPUTATION_VOTE_BONUS u10)
(define-constant REPUTATION_PROPOSAL_SUCCESS_BONUS u25)
(define-constant REPUTATION_MAINTENANCE_BONUS u15)
(define-constant REPUTATION_DECAY_RATE u2)

(define-constant ERR_NO_EMERGENCY_REQUEST (err u113))
(define-constant ERR_EMERGENCY_ALREADY_VOTED (err u114))
(define-constant ERR_EMERGENCY_NOT_APPROVED (err u115))
(define-constant ERR_INSUFFICIENT_EMERGENCY_FUNDS (err u116))

(define-data-var emergency-fund-balance uint u0)
(define-data-var emergency-request-counter uint u0)

(define-data-var monthly-rent uint u0)
(define-data-var rent-due-block uint u0)
(define-data-var rent-period-length uint u4320)

(define-data-var total-shares uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var property-address (string-ascii 200) "")
(define-data-var property-value uint u0)

(define-map members principal {
    shares: uint,
    join-block: uint,
    active: bool
})

(define-map proposals uint {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    proposal-type: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool,
    created-block: uint
})

(define-map votes {proposal-id: uint, voter: principal} {
    vote: bool,
    shares-voted: uint
})

(define-map maintenance-records uint {
    description: (string-ascii 300),
    cost: uint,
    completed-block: uint,
    contractor: (string-ascii 100)
})

(define-data-var maintenance-counter uint u0)

(define-public (initialize-property (address (string-ascii 200)) (value uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set property-address address)
        (var-set property-value value)
        (ok true)
    )
)

(define-public (join-coop (shares uint))
    (let ((share-price (/ (var-get property-value) u100)))
        (begin
            (asserts! (> shares u0) ERR_INVALID_AMOUNT)
            (asserts! (is-none (map-get? members tx-sender)) ERR_ALREADY_MEMBER)
            (try! (stx-transfer? (* shares share-price) tx-sender (as-contract tx-sender)))
            (map-set members tx-sender {
                shares: shares,
                join-block: stacks-block-height,
                active: true
            })
            (var-set total-shares (+ (var-get total-shares) shares))
            (ok shares)
        )
    )
)

(define-public (buy-additional-shares (shares uint))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (share-price (/ (var-get property-value) u100))
    )
        (begin
            (asserts! (> shares u0) ERR_INVALID_AMOUNT)
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (try! (stx-transfer? (* shares share-price) tx-sender (as-contract tx-sender)))
            (map-set members tx-sender (merge member-data {
                shares: (+ (get shares member-data) shares)
            }))
            (var-set total-shares (+ (var-get total-shares) shares))
            (ok (+ (get shares member-data) shares))
        )
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (proposal-type (string-ascii 20)))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (proposal-id (+ (var-get proposal-counter) u1))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (>= (get shares member-data) u1) ERR_INSUFFICIENT_SHARES)
            (map-set proposals proposal-id {
                proposer: tx-sender,
                title: title,
                description: description,
                amount: amount,
                proposal-type: proposal-type,
                votes-for: u0,
                votes-against: u0,
                end-block: (+ stacks-block-height u144),
                executed: false,
                created-block: stacks-block-height
            })
            (var-set proposal-counter proposal-id)
            (ok proposal-id)
        )
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (member-shares (get shares member-data))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (< stacks-block-height (get end-block proposal-data)) ERR_PROPOSAL_EXPIRED)
            (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
            (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
                vote: vote-for,
                shares-voted: member-shares
            })
            (if vote-for
                (map-set proposals proposal-id (merge proposal-data {
                    votes-for: (+ (get votes-for proposal-data) member-shares)
                }))
                (map-set proposals proposal-id (merge proposal-data {
                    votes-against: (+ (get votes-against proposal-data) member-shares)
                }))
            )
            (ok true)
        )
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (total-votes (+ (get votes-for proposal-data) (get votes-against proposal-data)))
        (required-quorum (/ (var-get total-shares) u2))
    )
        (begin
            (asserts! (>= stacks-block-height (get end-block proposal-data)) ERR_PROPOSAL_EXPIRED)
            (asserts! (not (get executed proposal-data)) ERR_PROPOSAL_NOT_FOUND)
            (asserts! (>= total-votes required-quorum) ERR_PROPOSAL_NOT_PASSED)
            (asserts! (> (get votes-for proposal-data) (get votes-against proposal-data)) ERR_PROPOSAL_NOT_PASSED)
            (try! (if (is-eq (get proposal-type proposal-data) "maintenance")
                (execute-maintenance-proposal proposal-id)
                (ok true)
            ))
            (map-set proposals proposal-id (merge proposal-data {executed: true}))
            (ok true)
        )
    )
)
(define-private (execute-maintenance-proposal (proposal-id uint))
    (let (
        (proposal-data (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (amount (get amount proposal-data))
    )
        (begin
            (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_FUNDS)
            (try! (as-contract (stx-transfer? amount tx-sender (get proposer proposal-data))))
            (ok true)
        )
    )
)

(define-public (record-maintenance (description (string-ascii 300)) (cost uint) (contractor (string-ascii 100)))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (record-id (+ (var-get maintenance-counter) u1))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (map-set maintenance-records record-id {
                description: description,
                cost: cost,
                completed-block: stacks-block-height,
                contractor: contractor
            })
            (var-set maintenance-counter record-id)
            (ok record-id)
        )
    )
)

(define-public (leave-coop)
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (member-shares (get shares member-data))
        (share-value (/ (stx-get-balance (as-contract tx-sender)) (var-get total-shares)))
        (payout (* member-shares share-value))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (map-set members tx-sender (merge member-data {active: false}))
            (var-set total-shares (- (var-get total-shares) member-shares))
            (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
            (ok payout)
        )
    )
)

(define-read-only (get-member-info (member principal))
    (map-get? members member)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-maintenance-record (record-id uint))
    (map-get? maintenance-records record-id)
)

(define-read-only (get-property-info)
    {
        address: (var-get property-address),
        value: (var-get property-value),
        total-shares: (var-get total-shares)
    }
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-total-proposals)
    (var-get proposal-counter)
)

(define-read-only (get-total-maintenance-records)
    (var-get maintenance-counter)
)


(define-map rent-payments {member: principal, period: uint} {
    amount-paid: uint,
    payment-block: uint,
    late-payment: bool
})

(define-data-var current-rent-period uint u0)

(define-public (set-monthly-rent (rent-amount uint) (start-block uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> rent-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> start-block stacks-block-height) ERR_INVALID_AMOUNT)
        (var-set monthly-rent rent-amount)
        (var-set rent-due-block start-block)
        (var-set current-rent-period u1)
        (ok true)
    )
)

(define-public (pay-rent)
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (rent-amount (var-get monthly-rent))
        (current-period (var-get current-rent-period))
        (due-block (var-get rent-due-block))
        (period-length (var-get rent-period-length))
        (adjusted-period (if (>= stacks-block-height due-block)
            (+ current-period (/ (- stacks-block-height due-block) period-length))
            current-period))
    )
        (begin
            (asserts! (> rent-amount u0) ERR_RENT_NOT_SET)
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (>= stacks-block-height due-block) ERR_RENT_PERIOD_NOT_STARTED)
            (asserts! (is-none (map-get? rent-payments {member: tx-sender, period: adjusted-period})) ERR_RENT_ALREADY_PAID)
            (try! (stx-transfer? rent-amount tx-sender (as-contract tx-sender)))
            (map-set rent-payments {member: tx-sender, period: adjusted-period} {
                amount-paid: rent-amount,
                payment-block: stacks-block-height,
                late-payment: (> stacks-block-height (+ due-block (* adjusted-period period-length)))
            })
            (var-set current-rent-period adjusted-period)
            (ok adjusted-period)
        )
    )
)

(define-read-only (check-rent-status (member principal) (period uint))
    (map-get? rent-payments {member: member, period: period})
)

(define-read-only (get-rent-info)
    {
        monthly-rent: (var-get monthly-rent),
        rent-due-block: (var-get rent-due-block),
        current-period: (var-get current-rent-period),
        period-length: (var-get rent-period-length)
    }
)

(define-read-only (get-current-rent-period)
    (let (
        (due-block (var-get rent-due-block))
        (period-length (var-get rent-period-length))
    )
        (if (>= stacks-block-height due-block)
            (+ u1 (/ (- stacks-block-height due-block) period-length))
            u0)
    )
)


(define-map member-reputation principal {
    base-score: uint,
    votes-cast: uint,
    proposals-created: uint,
    proposals-passed: uint,
    maintenance-contributions: uint,
    last-activity-block: uint
})

(define-public (update-reputation-vote (member principal))
    (let (
        (current-rep (default-to {
            base-score: u100,
            votes-cast: u0,
            proposals-created: u0,
            proposals-passed: u0,
            maintenance-contributions: u0,
            last-activity-block: stacks-block-height
        } (map-get? member-reputation member)))
        (decayed-score (calculate-decay (get base-score current-rep) (get last-activity-block current-rep)))
    )
        (begin
            (map-set member-reputation member (merge current-rep {
                base-score: (+ decayed-score REPUTATION_VOTE_BONUS),
                votes-cast: (+ (get votes-cast current-rep) u1),
                last-activity-block: stacks-block-height
            }))
            (ok true)
        )
    )
)

(define-public (update-reputation-proposal-success (member principal))
    (let (
        (current-rep (unwrap! (map-get? member-reputation member) (err u404)))
        (decayed-score (calculate-decay (get base-score current-rep) (get last-activity-block current-rep)))
    )
        (begin
            (map-set member-reputation member (merge current-rep {
                base-score: (+ decayed-score REPUTATION_PROPOSAL_SUCCESS_BONUS),
                proposals-passed: (+ (get proposals-passed current-rep) u1),
                last-activity-block: stacks-block-height
            }))
            (ok true)
        )
    )
)

(define-public (update-reputation-maintenance (member principal))
    (let (
        (current-rep (default-to {
            base-score: u100,
            votes-cast: u0,
            proposals-created: u0,
            proposals-passed: u0,
            maintenance-contributions: u0,
            last-activity-block: stacks-block-height
        } (map-get? member-reputation member)))
        (decayed-score (calculate-decay (get base-score current-rep) (get last-activity-block current-rep)))
    )
        (begin
            (map-set member-reputation member (merge current-rep {
                base-score: (+ decayed-score REPUTATION_MAINTENANCE_BONUS),
                maintenance-contributions: (+ (get maintenance-contributions current-rep) u1),
                last-activity-block: stacks-block-height
            }))
            (ok true)
        )
    )
)

(define-private (calculate-decay (score uint) (last-block uint))
    (let ((blocks-since-activity (- stacks-block-height last-block)))
        (if (> blocks-since-activity u1440)
            (let ((decayed-score (- score (* (/ blocks-since-activity u1440) REPUTATION_DECAY_RATE))))
                (if (> decayed-score u50) decayed-score u50)
            )
            score
        )
    )
)

(define-read-only (get-member-reputation (member principal))
    (map-get? member-reputation member)
)

(define-read-only (get-effective-voting-weight (member principal))
    (match (map-get? members member)
        member-data 
        (match (map-get? member-reputation member)
            rep-data
            (let ((base-shares (get shares member-data))
                  (reputation-multiplier (/ (get base-score rep-data) u100)))
                (+ base-shares (/ (* base-shares reputation-multiplier) u10))
            )
            (get shares member-data)
        )
        u0
    )
)


(define-map emergency-fund-contributions principal uint)

(define-map emergency-requests uint {
    requester: principal,
    reason: (string-ascii 200),
    amount: uint,
    created-block: uint,
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    approved: bool,
    paid: bool
})

(define-map emergency-votes {request-id: uint, voter: principal} bool)

(define-public (contribute-to-emergency-fund (amount uint))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (current-contribution (default-to u0 (map-get? emergency-fund-contributions tx-sender)))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set emergency-fund-contributions tx-sender (+ current-contribution amount))
            (var-set emergency-fund-balance (+ (var-get emergency-fund-balance) amount))
            (ok amount)
        )
    )
)

(define-public (request-emergency-funds (reason (string-ascii 200)) (amount uint))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (request-id (+ (var-get emergency-request-counter) u1))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (asserts! (<= amount (var-get emergency-fund-balance)) ERR_INSUFFICIENT_EMERGENCY_FUNDS)
            (map-set emergency-requests request-id {
                requester: tx-sender,
                reason: reason,
                amount: amount,
                created-block: stacks-block-height,
                votes-for: u0,
                votes-against: u0,
                end-block: (+ stacks-block-height u72),
                approved: false,
                paid: false
            })
            (var-set emergency-request-counter request-id)
            (ok request-id)
        )
    )
)

(define-public (vote-emergency-request (request-id uint) (approve bool))
    (let (
        (member-data (unwrap! (map-get? members tx-sender) ERR_NOT_MEMBER))
        (request-data (unwrap! (map-get? emergency-requests request-id) ERR_NO_EMERGENCY_REQUEST))
    )
        (begin
            (asserts! (get active member-data) ERR_NOT_MEMBER)
            (asserts! (< stacks-block-height (get end-block request-data)) ERR_PROPOSAL_EXPIRED)
            (asserts! (is-none (map-get? emergency-votes {request-id: request-id, voter: tx-sender})) ERR_EMERGENCY_ALREADY_VOTED)
            (map-set emergency-votes {request-id: request-id, voter: tx-sender} approve)
            (if approve
                (map-set emergency-requests request-id (merge request-data {
                    votes-for: (+ (get votes-for request-data) u1)
                }))
                (map-set emergency-requests request-id (merge request-data {
                    votes-against: (+ (get votes-against request-data) u1)
                }))
            )
            (ok true)
        )
    )
)

(define-public (execute-emergency-payout (request-id uint))
    (let (
        (request-data (unwrap! (map-get? emergency-requests request-id) ERR_NO_EMERGENCY_REQUEST))
        (required-votes (/ (var-get total-shares) u3))
    )
        (begin
            (asserts! (>= stacks-block-height (get end-block request-data)) ERR_PROPOSAL_EXPIRED)
            (asserts! (not (get paid request-data)) ERR_PROPOSAL_NOT_FOUND)
            (asserts! (>= (get votes-for request-data) required-votes) ERR_EMERGENCY_NOT_APPROVED)
            (asserts! (> (get votes-for request-data) (get votes-against request-data)) ERR_EMERGENCY_NOT_APPROVED)
            (try! (as-contract (stx-transfer? (get amount request-data) tx-sender (get requester request-data))))
            (var-set emergency-fund-balance (- (var-get emergency-fund-balance) (get amount request-data)))
            (map-set emergency-requests request-id (merge request-data {approved: true, paid: true}))
            (ok (get amount request-data))
        )
    )
)

(define-read-only (get-emergency-fund-balance)
    (var-get emergency-fund-balance)
)

(define-read-only (get-emergency-request (request-id uint))
    (map-get? emergency-requests request-id)
)

(define-read-only (get-member-emergency-contributions (member principal))
    (default-to u0 (map-get? emergency-fund-contributions member))
)