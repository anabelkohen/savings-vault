;; Time-Locked Savings Vault Contract
;; A simple savings contract that locks funds for a specified time period

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-FUNDS-LOCKED (err u102))
(define-constant ERR-NO-VAULT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-UNLOCK-TIME (err u105))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structure for individual savings vault
(define-map savings-vaults
  { owner: principal }
  {
    balance: uint,
    unlock-time: uint,
    created-at: uint
  }
)

;; Track total locked funds
(define-data-var total-locked-funds uint u0)

;; Events
(define-map vault-events
  { event-id: uint }
  {
    event-type: (string-ascii 20),
    owner: principal,
    amount: uint,
    timestamp: uint
  }
)

(define-data-var next-event-id uint u0)

;; Create a new savings vault with time lock
(define-public (create-vault (unlock-delay uint))
  (let (
    (sender tx-sender)
    (current-time block-height)
    (unlock-time (+ current-time unlock-delay))
  )
    ;; Validate unlock delay (minimum 144 blocks = ~24 hours)
    (asserts! (>= unlock-delay u144) ERR-INVALID-UNLOCK-TIME)
    
    ;; Check if vault already exists
    (asserts! (is-none (map-get? savings-vaults { owner: sender })) ERR-NOT-AUTHORIZED)
    
    ;; Create the vault
    (map-set savings-vaults
      { owner: sender }
      {
        balance: u0,
        unlock-time: unlock-time,
        created-at: current-time
      }
    )
    
    ;; Log event
    (log-event "VAULT_CREATED" sender u0)
    
    (ok unlock-time)
  )
)

;; Deposit STX into savings vault
(define-public (deposit (amount uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? savings-vaults { owner: sender }) ERR-NO-VAULT-FOUND))
    (new-balance (+ (get balance vault) amount))
  )
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update vault balance
    (map-set savings-vaults
      { owner: sender }
      (merge vault { balance: new-balance })
    )
    
    ;; Update total locked funds
    (var-set total-locked-funds (+ (var-get total-locked-funds) amount))
    
    ;; Log event
    (log-event "DEPOSIT" sender amount)
    
    (ok new-balance)
  )
)

;; Withdraw funds (only after unlock time)
(define-public (withdraw (amount uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? savings-vaults { owner: sender }) ERR-NO-VAULT-FOUND))
    (current-time block-height)
    (vault-balance (get balance vault))
    (new-balance (- vault-balance amount))
  )
    ;; Check if funds are unlocked
    (asserts! (>= current-time (get unlock-time vault)) ERR-FUNDS-LOCKED)
    
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount vault-balance) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update vault balance
    (map-set savings-vaults
      { owner: sender }
      (merge vault { balance: new-balance })
    )
    
    ;; Update total locked funds
    (var-set total-locked-funds (- (var-get total-locked-funds) amount))
    
    ;; Transfer STX back to user
    (try! (as-contract (stx-transfer? amount tx-sender sender)))
    
    ;; Log event
    (log-event "WITHDRAWAL" sender amount)
    
    (ok new-balance)
  )
)

;; Withdraw all funds
(define-public (withdraw-all)
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? savings-vaults { owner: sender }) ERR-NO-VAULT-FOUND))
    (vault-balance (get balance vault))
  )
    (withdraw vault-balance)
  )
)

;; Extend lock time (can only extend, not reduce)
(define-public (extend-lock (additional-delay uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? savings-vaults { owner: sender }) ERR-NO-VAULT-FOUND))
    (current-unlock-time (get unlock-time vault))
    (new-unlock-time (+ current-unlock-time additional-delay))
  )
    ;; Validate extension
    (asserts! (> additional-delay u0) ERR-INVALID-UNLOCK-TIME)
    
    ;; Update vault unlock time
    (map-set savings-vaults
      { owner: sender }
      (merge vault { unlock-time: new-unlock-time })
    )
    
    ;; Log event
    (log-event "LOCK_EXTENDED" sender additional-delay)
    
    (ok new-unlock-time)
  )
)

;; Emergency withdrawal (with penalty) - only contract owner can enable
(define-data-var emergency-enabled bool false)

(define-public (toggle-emergency (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set emergency-enabled enabled)
    (ok enabled)
  )
)

;; Emergency withdrawal with 10% penalty
(define-public (emergency-withdraw (amount uint))
  (let (
    (sender tx-sender)
    (vault (unwrap! (map-get? savings-vaults { owner: sender }) ERR-NO-VAULT-FOUND))
    (vault-balance (get balance vault))
    (penalty (/ amount u10)) ;; 10% penalty
    (net-amount (- amount penalty))
    (new-balance (- vault-balance amount))
  )
    ;; Check if emergency withdrawals are enabled
    (asserts! (var-get emergency-enabled) ERR-NOT-AUTHORIZED)
    
    ;; Validate amount
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount vault-balance) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update vault balance
    (map-set savings-vaults
      { owner: sender }
      (merge vault { balance: new-balance })
    )
    
    ;; Update total locked funds
    (var-set total-locked-funds (- (var-get total-locked-funds) amount))
    
    ;; Transfer net amount (after penalty) back to user
    (try! (as-contract (stx-transfer? net-amount tx-sender sender)))
    
    ;; Log event
    (log-event "EMERGENCY_WITHDRAWAL" sender amount)
    
    (ok net-amount)
  )
)

;; Helper function to log events
(define-private (log-event (event-type (string-ascii 20)) (owner principal) (amount uint))
  (let (
    (event-id (var-get next-event-id))
  )
    (map-set vault-events
      { event-id: event-id }
      {
        event-type: event-type,
        owner: owner,
        amount: amount,
        timestamp: block-height
      }
    )
    (var-set next-event-id (+ event-id u1))
    true
  )
)

;; Read-only functions

;; Get vault information
(define-read-only (get-vault-info (owner principal))
  (map-get? savings-vaults { owner: owner })
)

;; Check if vault is unlocked
(define-read-only (is-vault-unlocked (owner principal))
  (match (map-get? savings-vaults { owner: owner })
    vault (>= block-height (get unlock-time vault))
    false
  )
)

;; Get time until unlock
(define-read-only (time-until-unlock (owner principal))
  (match (map-get? savings-vaults { owner: owner })
    vault 
      (if (>= block-height (get unlock-time vault))
        u0
        (- (get unlock-time vault) block-height)
      )
    u0
  )
)

;; Get total locked funds
(define-read-only (get-total-locked-funds)
  (var-get total-locked-funds)
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Get vault event
(define-read-only (get-vault-event (event-id uint))
  (map-get? vault-events { event-id: event-id })
)

;; Get next event ID
(define-read-only (get-next-event-id)
  (var-get next-event-id)
)