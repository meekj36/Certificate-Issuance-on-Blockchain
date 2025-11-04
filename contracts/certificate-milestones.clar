(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MILESTONE_NOT_REACHED (err u201))
(define-constant ERR_MILESTONE_ALREADY_CLAIMED (err u202))
(define-constant ERR_INVALID_MILESTONE_ID (err u203))
(define-constant ERR_INSUFFICIENT_CERTIFICATES (err u204))

(define-map milestone-definitions
  { milestone-id: uint }
  {
    name: (string-ascii 50),
    required-count: uint,
    reward-points: uint,
    active: bool
  }
)

(define-map user-milestones
  { user: principal, milestone-id: uint }
  { 
    claimed-at: uint,
    certificate-count-at-claim: uint
  }
)

(define-map user-total-points principal uint)

(define-map milestone-claim-count { milestone-id: uint } uint)

(define-data-var next-milestone-id uint u1)

(define-data-var contract-admin principal tx-sender)

(define-read-only (get-milestone-definition (milestone-id uint))
  (map-get? milestone-definitions { milestone-id: milestone-id })
)

(define-read-only (get-user-milestone (user principal) (milestone-id uint))
  (map-get? user-milestones { user: user, milestone-id: milestone-id })
)

(define-read-only (get-user-points (user principal))
  (default-to u0 (map-get? user-total-points user))
)

(define-read-only (has-claimed-milestone (user principal) (milestone-id uint))
  (is-some (get-user-milestone user milestone-id))
)

(define-read-only (get-milestone-stats (milestone-id uint))
  (default-to u0 (map-get? milestone-claim-count { milestone-id: milestone-id }))
)

(define-public (create-milestone 
  (name (string-ascii 50))
  (required-count uint)
  (reward-points uint)
)
  (let ((milestone-id (var-get next-milestone-id)))
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set milestone-definitions
      { milestone-id: milestone-id }
      { name: name, required-count: required-count, reward-points: reward-points, active: true }
    )
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (claim-milestone (milestone-id uint) (cert-count uint))
  (let
    (
      (milestone (unwrap! (get-milestone-definition milestone-id) ERR_INVALID_MILESTONE_ID))
      (user tx-sender)
    )
    (asserts! (get active milestone) ERR_INVALID_MILESTONE_ID)
    (asserts! (not (has-claimed-milestone user milestone-id)) ERR_MILESTONE_ALREADY_CLAIMED)
    (asserts! (>= cert-count (get required-count milestone)) ERR_INSUFFICIENT_CERTIFICATES)
    
    (map-set user-milestones
      { user: user, milestone-id: milestone-id }
      { claimed-at: stacks-block-height, certificate-count-at-claim: cert-count }
    )
    
    (map-set user-total-points
      user
      (+ (get-user-points user) (get reward-points milestone))
    )
    
    (map-set milestone-claim-count
      { milestone-id: milestone-id }
      (+ (get-milestone-stats milestone-id) u1)
    )
    
    (ok (get reward-points milestone))
  )
)

(begin
  (unwrap-panic (create-milestone "First Steps" u1 u10))
  (unwrap-panic (create-milestone "Learning Path" u3 u50))
  (unwrap-panic (create-milestone "Knowledge Seeker" u5 u100))
  (unwrap-panic (create-milestone "Expert Track" u10 u250))
)
