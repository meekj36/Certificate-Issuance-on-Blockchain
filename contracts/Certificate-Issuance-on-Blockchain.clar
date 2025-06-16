(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u101))
(define-constant ERR_CERTIFICATE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_ISSUER (err u103))
(define-constant ERR_CERTIFICATE_REVOKED (err u104))
(define-constant ERR_ISSUER_NOT_APPROVED (err u105))

(define-map approved-issuers principal bool)

(define-map certificates
  { certificate-id: uint }
  {
    recipient: principal,
    issuer: principal,
    program-name: (string-ascii 100),
    completion-date: uint,
    grade: (string-ascii 10),
    skills: (list 10 (string-ascii 50)),
    metadata-uri: (optional (string-ascii 200)),
    issued-at: uint,
    is-revoked: bool
  }
)

(define-map certificate-by-recipient
  { recipient: principal, issuer: principal, program: (string-ascii 100) }
  uint
)

(define-map issuer-certificates principal (list 1000 uint))

(define-map recipient-certificates principal (list 100 uint))

(define-data-var next-certificate-id uint u1)

(define-data-var total-certificates uint u0)

(define-data-var total-issuers uint u0)

(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates { certificate-id: certificate-id })
)

(define-read-only (get-certificate-by-recipient (recipient principal) (issuer principal) (program (string-ascii 100)))
  (match (map-get? certificate-by-recipient { recipient: recipient, issuer: issuer, program: program })
    cert-id (get-certificate cert-id)
    none
  )
)

(define-read-only (get-issuer-certificates (issuer principal))
  (default-to (list) (map-get? issuer-certificates issuer))
)

(define-read-only (get-recipient-certificates (recipient principal))
  (default-to (list) (map-get? recipient-certificates recipient))
)

(define-read-only (is-approved-issuer (issuer principal))
  (default-to false (map-get? approved-issuers issuer))
)

(define-read-only (get-total-certificates)
  (var-get total-certificates)
)

(define-read-only (get-total-issuers)
  (var-get total-issuers)
)

(define-read-only (is-certificate-valid (certificate-id uint))
  (match (get-certificate certificate-id)
    certificate (not (get is-revoked certificate))
    false
  )
)

(define-public (approve-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-approved-issuer issuer)) ERR_CERTIFICATE_ALREADY_EXISTS)
    (map-set approved-issuers issuer true)
    (var-set total-issuers (+ (var-get total-issuers) u1))
    (ok true)
  )
)

(define-public (revoke-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-approved-issuer issuer) ERR_ISSUER_NOT_APPROVED)
    (map-delete approved-issuers issuer)
    (var-set total-issuers (- (var-get total-issuers) u1))
    (ok true)
  )
)

(define-public (issue-certificate 
  (recipient principal)
  (program-name (string-ascii 100))
  (completion-date uint)
  (grade (string-ascii 10))
  (skills (list 10 (string-ascii 50)))
  (metadata-uri (optional (string-ascii 200)))
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
      (issuer tx-sender)
      (current-block stacks-block-height)
    )
    (asserts! (is-approved-issuer issuer) ERR_ISSUER_NOT_APPROVED)
    (asserts! 
      (is-none (map-get? certificate-by-recipient { recipient: recipient, issuer: issuer, program: program-name }))
      ERR_CERTIFICATE_ALREADY_EXISTS
    )
    
    (map-set certificates
      { certificate-id: certificate-id }
      {
        recipient: recipient,
        issuer: issuer,
        program-name: program-name,
        completion-date: completion-date,
        grade: grade,
        skills: skills,
        metadata-uri: metadata-uri,
        issued-at: current-block,
        is-revoked: false
      }
    )
    
    (map-set certificate-by-recipient
      { recipient: recipient, issuer: issuer, program: program-name }
      certificate-id
    )
    
    (map-set issuer-certificates
      issuer
      (unwrap-panic (as-max-len? (append (get-issuer-certificates issuer) certificate-id) u1000))
    )
    
    (map-set recipient-certificates
      recipient
      (unwrap-panic (as-max-len? (append (get-recipient-certificates recipient) certificate-id) u100))
    )
    
    (var-set next-certificate-id (+ certificate-id u1))
    (var-set total-certificates (+ (var-get total-certificates) u1))
    
    (ok certificate-id)
  )
)

(define-public (revoke-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (issuer (get issuer certificate))
    )
    (asserts! (is-eq tx-sender issuer) ERR_UNAUTHORIZED)
    (asserts! (not (get is-revoked certificate)) ERR_CERTIFICATE_REVOKED)
    
    (map-set certificates
      { certificate-id: certificate-id }
      (merge certificate { is-revoked: true })
    )
    
    (ok true)
  )
)

(define-public (verify-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (ok {
      is-valid: (and (not (get is-revoked certificate)) (is-approved-issuer (get issuer certificate))),
      certificate: certificate
    })
  )
)

(define-public (bulk-issue-certificates 
  (recipients (list 50 principal))
  (program-name (string-ascii 100))
  (completion-date uint)
  (grade (string-ascii 10))
  (skills (list 10 (string-ascii 50)))
)
  (let
    (
      (issuer tx-sender)
    )
    (asserts! (is-approved-issuer issuer) ERR_ISSUER_NOT_APPROVED)
    (ok (map issue-single-certificate-helper 
      (map create-certificate-data recipients)
    ))
  )
)

(define-private (create-certificate-data (recipient principal))
  {
    recipient: recipient,
    program-name: "Bootcamp Program",
    completion-date: stacks-block-height,
    grade: "A",
    skills: (list "JavaScript" "React" "Node.js"),
    metadata-uri: none
  }
)

(define-private (issue-single-certificate-helper (cert-data { recipient: principal, program-name: (string-ascii 100), completion-date: uint, grade: (string-ascii 10), skills: (list 10 (string-ascii 50)), metadata-uri: (optional (string-ascii 200)) }))
  (issue-certificate
    (get recipient cert-data)
    (get program-name cert-data)
    (get completion-date cert-data)
    (get grade cert-data)
    (get skills cert-data)
    (get metadata-uri cert-data)
  )
)

(begin
  (map-set approved-issuers CONTRACT_OWNER true)
  (var-set total-issuers u1)
)
