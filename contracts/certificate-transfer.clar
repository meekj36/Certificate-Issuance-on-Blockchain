(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u101))
(define-constant ERR_CERTIFICATE_REVOKED (err u104))
(define-constant ERR_TRANSFER_TO_SELF (err u116))
(define-constant ERR_TRANSFER_HISTORY_FULL (err u117))
(define-constant ERR_INVALID_TRANSFER (err u118))

(define-map certificate-ownership
  { certificate-id: uint }
  { current-owner: principal, original-recipient: principal }
)

(define-map transfer-history
  { certificate-id: uint, transfer-index: uint }
  {
    from-principal: principal,
    to-principal: principal,
    transferred-at: uint,
    reason: (optional (string-ascii 100))
  }
)

(define-map certificate-transfer-count
  { certificate-id: uint }
  uint
)

(define-map owner-certificates principal (list 100 uint))

(define-read-only (get-current-owner (certificate-id uint))
  (match (map-get? certificate-ownership { certificate-id: certificate-id })
    ownership-data (some (get current-owner ownership-data))
    none
  )
)

(define-read-only (get-transfer-count (certificate-id uint))
  (default-to u0 (map-get? certificate-transfer-count { certificate-id: certificate-id }))
)

(define-read-only (get-transfer-record (certificate-id uint) (transfer-index uint))
  (map-get? transfer-history { certificate-id: certificate-id, transfer-index: transfer-index })
)

(define-read-only (get-ownership-history (certificate-id uint))
  (let
    (
      (transfer-count (get-transfer-count certificate-id))
    )
    (map get-transfer-at-index (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))
  )
)

(define-private (get-transfer-at-index (index uint))
  (get-transfer-record u0 index)
)

(define-public (initialize-ownership (certificate-id uint) (original-recipient principal))
  (begin
    (asserts! (is-none (get-current-owner certificate-id)) ERR_INVALID_TRANSFER)
    (map-set certificate-ownership
      { certificate-id: certificate-id }
      { current-owner: original-recipient, original-recipient: original-recipient }
    )
    (map-set owner-certificates
      original-recipient
      (unwrap-panic (as-max-len? (append (get-owner-certs original-recipient) certificate-id) u100))
    )
    (ok true)
  )
)

(define-public (transfer-certificate 
  (certificate-id uint)
  (new-owner principal)
  (reason (optional (string-ascii 100)))
)
  (let
    (
      (ownership-data (unwrap! (map-get? certificate-ownership { certificate-id: certificate-id }) ERR_CERTIFICATE_NOT_FOUND))
      (current-owner (get current-owner ownership-data))
      (transfer-count (get-transfer-count certificate-id))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner current-owner)) ERR_TRANSFER_TO_SELF)
    (asserts! (< transfer-count u10) ERR_TRANSFER_HISTORY_FULL)
    
    (map-set transfer-history
      { certificate-id: certificate-id, transfer-index: transfer-count }
      {
        from-principal: current-owner,
        to-principal: new-owner,
        transferred-at: stacks-block-height,
        reason: reason
      }
    )
    
    (map-set certificate-ownership
      { certificate-id: certificate-id }
      (merge ownership-data { current-owner: new-owner })
    )
    
    (map-set certificate-transfer-count
      { certificate-id: certificate-id }
      (+ transfer-count u1)
    )
    
    (map-set owner-certificates
      new-owner
      (unwrap-panic (as-max-len? (append (get-owner-certs new-owner) certificate-id) u100))
    )
    
    (ok transfer-count)
  )
)

(define-private (get-owner-certs (owner principal))
  (default-to (list) (map-get? owner-certificates owner))
)
