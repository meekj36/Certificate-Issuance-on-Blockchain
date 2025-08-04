(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u101))
(define-constant ERR_CERTIFICATE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_ISSUER (err u103))
(define-constant ERR_CERTIFICATE_REVOKED (err u104))
(define-constant ERR_ISSUER_NOT_APPROVED (err u105))
(define-constant ERR_BATCH_TOO_LARGE (err u106))
(define-constant ERR_EMPTY_BATCH (err u107))

(define-constant ERR_CERTIFICATE_EXPIRED (err u108))
(define-constant ERR_CERTIFICATE_NOT_EXPIRED (err u109))
(define-constant ERR_RENEWAL_NOT_ALLOWED (err u110))
(define-constant ERR_INVALID_EXPIRATION_DATE (err u111))

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

;; Batch validation function
(define-public (validate-certificates-batch (certificate-ids (list 25 uint)))
  (let
    (
      (batch-size (len certificate-ids))
    )
    (asserts! (> batch-size u0) ERR_EMPTY_BATCH)
    (asserts! (<= batch-size u25) ERR_BATCH_TOO_LARGE)
    
    (ok (map validate-certificate-helper certificate-ids))
  )
)

;; Helper function for individual certificate validation
(define-private (validate-certificate-helper (certificate-id uint))
  (match (get-certificate certificate-id)
    certificate
    {
      certificate-id: certificate-id,
      is-valid: (and 
        (not (get is-revoked certificate)) 
        (is-approved-issuer (get issuer certificate))
      ),
      recipient: (get recipient certificate),
      issuer: (get issuer certificate),
      program-name: (get program-name certificate),
      completion-date: (get completion-date certificate),
      grade: (get grade certificate),
      issued-at: (get issued-at certificate),
      is-revoked: (get is-revoked certificate)
    }
    {
      certificate-id: certificate-id,
      is-valid: false,
      recipient: 'SP000000000000000000002Q6VF78,
      issuer: 'SP000000000000000000002Q6VF78,
      program-name: "",
      completion-date: u0,
      grade: "",
      issued-at: u0,
      is-revoked: true
    }
  )
)

;; Read-only function to get batch certificate basic info
(define-read-only (get-certificates-batch-info (certificate-ids (list 25 uint)))
  (map get-certificate-basic-info certificate-ids)
)

;; Helper function for basic certificate info
(define-private (get-certificate-basic-info (certificate-id uint))
  (match (get-certificate certificate-id)
    certificate
    {
      certificate-id: certificate-id,
      exists: true,
      recipient: (get recipient certificate),
      issuer: (get issuer certificate),
      program-name: (get program-name certificate),
      is-revoked: (get is-revoked certificate)
    }
    {
      certificate-id: certificate-id,
      exists: false,
      recipient: 'SP000000000000000000002Q6VF78,
      issuer: 'SP000000000000000000002Q6VF78,
      program-name: "",
      is-revoked: true
    }
  )
)


(define-map certificate-expirations
  { certificate-id: uint }
  { 
    expiration-date: uint,
    renewable: bool,
    renewal-count: uint,
    max-renewals: uint
  }
)

(define-map renewal-requests
  { certificate-id: uint, request-id: uint }
  {
    requester: principal,
    requested-at: uint,
    approved: bool,
    processed: bool
  }
)

(define-data-var next-renewal-request-id uint u1)

(define-public (issue-certificate-with-expiration
  (recipient principal)
  (program-name (string-ascii 100))
  (completion-date uint)
  (grade (string-ascii 10))
  (skills (list 10 (string-ascii 50)))
  (metadata-uri (optional (string-ascii 200)))
  (validity-period uint)
  (renewable bool)
  (max-renewals uint)
)
  (let
    (
      (expiration-date (+ stacks-block-height validity-period))
      (certificate-id (try! (issue-certificate recipient program-name completion-date grade skills metadata-uri)))
    )
    (asserts! (> validity-period u0) ERR_INVALID_EXPIRATION_DATE)
    (map-set certificate-expirations
      { certificate-id: certificate-id }
      {
        expiration-date: expiration-date,
        renewable: renewable,
        renewal-count: u0,
        max-renewals: max-renewals
      }
    )
    (ok certificate-id)
  )
)

(define-read-only (is-certificate-expired (certificate-id uint))
  (match (map-get? certificate-expirations { certificate-id: certificate-id })
    expiration-data (>= stacks-block-height (get expiration-date expiration-data))
    false
  )
)

(define-read-only (get-certificate-expiration (certificate-id uint))
  (map-get? certificate-expirations { certificate-id: certificate-id })
)

(define-public (request-certificate-renewal (certificate-id uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (expiration-data (unwrap! (get-certificate-expiration certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (request-id (var-get next-renewal-request-id))
    )
    (asserts! (is-eq tx-sender (get recipient certificate)) ERR_UNAUTHORIZED)
    (asserts! (is-certificate-expired certificate-id) ERR_CERTIFICATE_NOT_EXPIRED)
    (asserts! (get renewable expiration-data) ERR_RENEWAL_NOT_ALLOWED)
    (asserts! (< (get renewal-count expiration-data) (get max-renewals expiration-data)) ERR_RENEWAL_NOT_ALLOWED)
    
    (map-set renewal-requests
      { certificate-id: certificate-id, request-id: request-id }
      {
        requester: tx-sender,
        requested-at: stacks-block-height,
        approved: false,
        processed: false
      }
    )
    
    (var-set next-renewal-request-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (approve-renewal (certificate-id uint) (request-id uint) (new-validity-period uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (renewal-request (unwrap! (map-get? renewal-requests { certificate-id: certificate-id, request-id: request-id }) ERR_CERTIFICATE_NOT_FOUND))
      (expiration-data (unwrap! (get-certificate-expiration certificate-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get issuer certificate)) ERR_UNAUTHORIZED)
    (asserts! (not (get processed renewal-request)) ERR_CERTIFICATE_ALREADY_EXISTS)
    (asserts! (> new-validity-period u0) ERR_INVALID_EXPIRATION_DATE)
    
    (map-set renewal-requests
      { certificate-id: certificate-id, request-id: request-id }
      (merge renewal-request { approved: true, processed: true })
    )
    
    (map-set certificate-expirations
      { certificate-id: certificate-id }
      {
        expiration-date: (+ stacks-block-height new-validity-period),
        renewable: (get renewable expiration-data),
        renewal-count: (+ (get renewal-count expiration-data) u1),
        max-renewals: (get max-renewals expiration-data)
      }
    )
    
    (ok true)
  )
)