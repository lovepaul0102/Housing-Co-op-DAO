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
