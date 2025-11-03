(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_NOT_MEMBER (err u201))
(define-constant ERR_NO_DIVIDENDS (err u202))
(define-constant ERR_INVALID_AMOUNT (err u203))
(define-constant ERR_ALREADY_DISTRIBUTED (err u204))

(define-data-var dividend-pool uint u0)
(define-data-var distribution-counter uint u0)
(define-data-var last-distribution-block uint u0)

(define-map distribution-snapshots uint {
    total-shares-snapshot: uint,
    amount-per-share: uint,
    distribution-block: uint,
    total-distributed: uint
})

(define-map member-claims {member: principal, distribution-id: uint} {
    claimed: bool,
    amount: uint,
    claim-block: uint
})

(define-map member-total-dividends principal uint)

(define-public (deposit-to-dividend-pool (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set dividend-pool (+ (var-get dividend-pool) amount))
        (ok amount)
    )
)

(define-public (distribute-dividends (total-shares uint))
    (let (
        (pool-amount (var-get dividend-pool))
        (distribution-id (+ (var-get distribution-counter) u1))
        (amount-per-share (/ pool-amount total-shares))
    )
        (begin
            (asserts! (> pool-amount u0) ERR_NO_DIVIDENDS)
            (asserts! (> total-shares u0) ERR_INVALID_AMOUNT)
            (map-set distribution-snapshots distribution-id {
                total-shares-snapshot: total-shares,
                amount-per-share: amount-per-share,
                distribution-block: stacks-block-height,
                total-distributed: pool-amount
            })
            (var-set distribution-counter distribution-id)
            (var-set last-distribution-block stacks-block-height)
            (var-set dividend-pool u0)
            (ok distribution-id)
        )
    )
)

(define-public (claim-dividend (distribution-id uint) (member-shares uint))
    (let (
        (snapshot (unwrap! (map-get? distribution-snapshots distribution-id) ERR_NO_DIVIDENDS))
        (dividend-amount (* (get amount-per-share snapshot) member-shares))
        (current-total (default-to u0 (map-get? member-total-dividends tx-sender)))
    )
        (begin
            (asserts! (> member-shares u0) ERR_INVALID_AMOUNT)
            (asserts! (is-none (map-get? member-claims {member: tx-sender, distribution-id: distribution-id})) ERR_ALREADY_DISTRIBUTED)
            (try! (as-contract (stx-transfer? dividend-amount tx-sender tx-sender)))
            (map-set member-claims {member: tx-sender, distribution-id: distribution-id} {
                claimed: true,
                amount: dividend-amount,
                claim-block: stacks-block-height
            })
            (map-set member-total-dividends tx-sender (+ current-total dividend-amount))
            (ok dividend-amount)
        )
    )
)

(define-read-only (get-dividend-pool)
    (var-get dividend-pool)
)

(define-read-only (get-distribution-info (distribution-id uint))
    (map-get? distribution-snapshots distribution-id)
)

(define-read-only (get-member-claim-status (member principal) (distribution-id uint))
    (map-get? member-claims {member: member, distribution-id: distribution-id})
)

(define-read-only (get-member-total-dividends (member principal))
    (default-to u0 (map-get? member-total-dividends member))
)

(define-read-only (get-current-distribution-id)
    (var-get distribution-counter)
)
