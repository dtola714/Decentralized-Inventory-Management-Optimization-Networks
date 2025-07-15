;; Inventory Coordinator Verification Contract
;; Manages coordinator registration, verification, and permissions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-INSUFFICIENT-STAKE (err u104))

;; Data Variables
(define-data-var next-coordinator-id uint u1)
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum stake

;; Data Maps
(define-map coordinators
  { coordinator-id: uint }
  {
    principal: principal,
    name: (string-ascii 50),
    verified: bool,
    stake-amount: uint,
    registration-block: uint,
    total-managed-items: uint,
    performance-score: uint
  }
)

(define-map coordinator-by-principal
  { principal: principal }
  { coordinator-id: uint }
)

(define-map coordinator-permissions
  { coordinator-id: uint }
  {
    can-optimize: bool,
    can-forecast: bool,
    can-automate: bool,
    can-reduce-costs: bool
  }
)

;; Public Functions

;; Register as inventory coordinator
(define-public (register-coordinator (name (string-ascii 50)) (stake-amount uint))
  (let (
    (coordinator-id (var-get next-coordinator-id))
    (caller tx-sender)
  )
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (>= stake-amount (var-get minimum-stake)) ERR-INSUFFICIENT-STAKE)

    ;; Check if already registered
    (asserts! (is-none (map-get? coordinator-by-principal { principal: caller })) ERR-ALREADY-REGISTERED)

    ;; Store coordinator data
    (map-set coordinators
      { coordinator-id: coordinator-id }
      {
        principal: caller,
        name: name,
        verified: false,
        stake-amount: stake-amount,
        registration-block: block-height,
        total-managed-items: u0,
        performance-score: u100
      }
    )

    ;; Map principal to coordinator ID
    (map-set coordinator-by-principal
      { principal: caller }
      { coordinator-id: coordinator-id }
    )

    ;; Set default permissions
    (map-set coordinator-permissions
      { coordinator-id: coordinator-id }
      {
        can-optimize: false,
        can-forecast: false,
        can-automate: false,
        can-reduce-costs: false
      }
    )

    ;; Increment next ID
    (var-set next-coordinator-id (+ coordinator-id u1))

    (ok coordinator-id)
  )
)

;; Verify coordinator (only contract owner)
(define-public (verify-coordinator (coordinator-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (match (map-get? coordinators { coordinator-id: coordinator-id })
      coordinator-data
      (begin
        (map-set coordinators
          { coordinator-id: coordinator-id }
          (merge coordinator-data { verified: true })
        )

        ;; Grant basic permissions upon verification
        (map-set coordinator-permissions
          { coordinator-id: coordinator-id }
          {
            can-optimize: true,
            can-forecast: true,
            can-automate: true,
            can-reduce-costs: true
          }
        )

        (ok true)
      )
      ERR-NOT-REGISTERED
    )
  )
)

;; Update coordinator performance
(define-public (update-performance-score (coordinator-id uint) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-score u1000) ERR-INVALID-INPUT)

    (match (map-get? coordinators { coordinator-id: coordinator-id })
      coordinator-data
      (begin
        (map-set coordinators
          { coordinator-id: coordinator-id }
          (merge coordinator-data { performance-score: new-score })
        )
        (ok true)
      )
      ERR-NOT-REGISTERED
    )
  )
)

;; Update managed items count
(define-public (update-managed-items (coordinator-id uint) (item-count uint))
  (begin
    (asserts! (is-coordinator-verified coordinator-id) ERR-NOT-AUTHORIZED)

    (match (map-get? coordinators { coordinator-id: coordinator-id })
      coordinator-data
      (begin
        (map-set coordinators
          { coordinator-id: coordinator-id }
          (merge coordinator-data { total-managed-items: item-count })
        )
        (ok true)
      )
      ERR-NOT-REGISTERED
    )
  )
)

;; Read-only Functions

;; Check if coordinator is verified
(define-read-only (is-coordinator-verified (coordinator-id uint))
  (match (map-get? coordinators { coordinator-id: coordinator-id })
    coordinator-data (get verified coordinator-data)
    false
  )
)

;; Get coordinator info
(define-read-only (get-coordinator-info (coordinator-id uint))
  (map-get? coordinators { coordinator-id: coordinator-id })
)

;; Get coordinator by principal
(define-read-only (get-coordinator-by-principal (principal principal))
  (map-get? coordinator-by-principal { principal: principal })
)

;; Get coordinator permissions
(define-read-only (get-coordinator-permissions (coordinator-id uint))
  (map-get? coordinator-permissions { coordinator-id: coordinator-id })
)

;; Check specific permission
(define-read-only (has-permission (coordinator-id uint) (permission (string-ascii 20)))
  (match (map-get? coordinator-permissions { coordinator-id: coordinator-id })
    permissions
    (if (is-eq permission "optimize")
      (get can-optimize permissions)
      (if (is-eq permission "forecast")
        (get can-forecast permissions)
        (if (is-eq permission "automate")
          (get can-automate permissions)
          (if (is-eq permission "reduce-costs")
            (get can-reduce-costs permissions)
            false
          )
        )
      )
    )
    false
  )
)

;; Get total coordinators
(define-read-only (get-total-coordinators)
  (- (var-get next-coordinator-id) u1)
)

;; Get minimum stake requirement
(define-read-only (get-minimum-stake)
  (var-get minimum-stake)
)
