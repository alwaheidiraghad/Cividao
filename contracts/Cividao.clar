(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VOTED (err u102))
(define-constant ERR_VOTING_ENDED (err u103))
(define-constant ERR_VOTING_ACTIVE (err u104))
(define-constant ERR_INSUFFICIENT_VOTES (err u105))
(define-constant ERR_AMENDMENT_NOT_FOUND (err u106))
(define-constant ERR_INVALID_QUORUM (err u107))
(define-constant ERR_NOT_MEMBER (err u108))
(define-constant ERR_INSUFFICIENT_FUNDS (err u109))
(define-constant ERR_BUDGET_NOT_FOUND (err u110))
(define-constant ERR_BUDGET_EXHAUSTED (err u111))
(define-constant ERR_INVALID_AMOUNT (err u112))
(define-constant ERR_EXPENSE_NOT_FOUND (err u113))
(define-constant ERR_BUDGET_ALREADY_EXISTS (err u114))

(define-data-var next-proposal-id uint u1)
(define-data-var next-amendment-id uint u1)
(define-data-var total-members uint u0)
(define-data-var quorum-percentage uint u51)
(define-data-var voting-period uint u1440)
(define-data-var treasury-balance uint u0)
(define-data-var next-budget-id uint u1)
(define-data-var next-expense-id uint u1)

(define-map members principal bool)
(define-map member-voting-power principal uint)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: (string-ascii 20),
    start-block: uint,
    end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    executed: bool,
    amendment-id: (optional uint)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map constitutional-amendments
  uint
  {
    title: (string-ascii 100),
    content: (string-ascii 1000),
    ratified: bool,
    ratification-block: (optional uint),
    superseded: bool
  }
)

(define-map amendment-votes
  { amendment-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map budgets
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    total-amount: uint,
    spent-amount: uint,
    category: (string-ascii 50),
    created-at: uint,
    created-by: principal,
    active: bool
  }
)

(define-map expenses
  uint
  {
    budget-id: uint,
    amount: uint,
    description: (string-ascii 200),
    recipient: principal,
    approved: bool,
    created-at: uint,
    created-by: principal,
    approved-by: (optional principal)
  }
)

(define-map budget-approvals
  { budget-id: uint, approver: principal }
  { approved: bool, approval-time: uint }
)

(define-read-only (get-member-status (member principal))
  (default-to false (map-get? members member))
)

(define-read-only (get-member-voting-power (member principal))
  (default-to u0 (map-get? member-voting-power member))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-amendment (amendment-id uint))
  (map-get? constitutional-amendments amendment-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-amendment-vote (amendment-id uint) (voter principal))
  (map-get? amendment-votes { amendment-id: amendment-id, voter: voter })
)

(define-read-only (get-total-members)
  (var-get total-members)
)

(define-read-only (get-quorum-percentage)
  (var-get quorum-percentage)
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-budget (budget-id uint))
  (map-get? budgets budget-id)
)

(define-read-only (get-expense (expense-id uint))
  (map-get? expenses expense-id)
)

(define-read-only (get-budget-approval (budget-id uint) (approver principal))
  (map-get? budget-approvals { budget-id: budget-id, approver: approver })
)

(define-read-only (calculate-required-votes)
  (let ((total-voting-power (var-get total-members)))
    (/ (* total-voting-power (var-get quorum-percentage)) u100)
  )
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal (and 
      (>= stacks-block-height (get start-block proposal))
      (<= stacks-block-height (get end-block proposal))
    )
    false
  )
)

(define-public (join-dao)
  (begin
    (asserts! (not (get-member-status tx-sender)) ERR_UNAUTHORIZED)
    (map-set members tx-sender true)
    (map-set member-voting-power tx-sender u1)
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)
  )
)

(define-public (leave-dao)
  (begin
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (map-delete members tx-sender)
    (map-delete member-voting-power tx-sender)
    (var-set total-members (- (var-get total-members) u1))
    (ok true)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (proposal-type (string-ascii 20)))
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      proposal-type: proposal-type,
      start-block: stacks-block-height,
      end-block: (+ stacks-block-height (var-get voting-period)),
      yes-votes: u0,
      no-votes: u0,
      executed: false,
      amendment-id: none
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (voter-power (get-member-voting-power tx-sender))
  )
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (is-proposal-active proposal-id) ERR_VOTING_ENDED)
    (asserts! (is-none (get-vote proposal-id tx-sender)) ERR_ALREADY_VOTED)
    
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { vote: vote, voting-power: voter-power })
    
    (if vote
      (map-set proposals proposal-id (merge proposal { yes-votes: (+ (get yes-votes proposal) voter-power) }))
      (map-set proposals proposal-id (merge proposal { no-votes: (+ (get no-votes proposal) voter-power) }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (not (is-proposal-active proposal-id)) ERR_VOTING_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_UNAUTHORIZED)
    (asserts! (>= (get yes-votes proposal) (calculate-required-votes)) ERR_INSUFFICIENT_VOTES)
    (asserts! (> (get yes-votes proposal) (get no-votes proposal)) ERR_INSUFFICIENT_VOTES)
    
    (map-set proposals proposal-id (merge proposal { executed: true }))
    (ok true)
  )
)

(define-public (create-constitutional-amendment (title (string-ascii 100)) (content (string-ascii 1000)))
  (let ((amendment-id (var-get next-amendment-id)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (map-set constitutional-amendments amendment-id {
      title: title,
      content: content,
      ratified: false,
      ratification-block: none,
      superseded: false
    })
    (var-set next-amendment-id (+ amendment-id u1))
    (ok amendment-id)
  )
)

(define-public (vote-on-amendment (amendment-id uint) (vote bool))
  (let ((voter-power (get-member-voting-power tx-sender)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (is-some (get-amendment amendment-id)) ERR_AMENDMENT_NOT_FOUND)
    (asserts! (is-none (get-amendment-vote amendment-id tx-sender)) ERR_ALREADY_VOTED)
    
    (map-set amendment-votes { amendment-id: amendment-id, voter: tx-sender } { vote: vote, voting-power: voter-power })
    (ok true)
  )
)

(define-public (ratify-amendment (amendment-id uint))
  (let (
    (amendment (unwrap! (get-amendment amendment-id) ERR_AMENDMENT_NOT_FOUND))
    (required-votes (* (calculate-required-votes) u2))
  )
    (asserts! (not (get ratified amendment)) ERR_UNAUTHORIZED)
    ;; (asserts! (>= (get-amendment-yes-votes amendment-id) required-votes) ERR_INSUFFICIENT_VOTES)
    
    (map-set constitutional-amendments amendment-id (merge amendment { 
      ratified: true, 
      ratification-block: (some stacks-block-height) 
    }))
    (ok true)
  )
)

(define-public (supersede-amendment (amendment-id uint))
  (let ((amendment (unwrap! (get-amendment amendment-id) ERR_AMENDMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get ratified amendment) ERR_UNAUTHORIZED)
    
    (map-set constitutional-amendments amendment-id (merge amendment { superseded: true }))
    (ok true)
  )
)

(define-public (update-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> new-quorum u0) (<= new-quorum u100)) ERR_INVALID_QUORUM)
    (var-set quorum-percentage new-quorum)
    (ok true)
  )
)

(define-public (update-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period new-period)
    (ok true)
  )
)

(define-public (deposit-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok true)
  )
)

(define-public (create-budget (title (string-ascii 100)) (description (string-ascii 500)) (total-amount uint) (category (string-ascii 50)))
  (let ((budget-id (var-get next-budget-id)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? budgets budget-id)) ERR_BUDGET_ALREADY_EXISTS)
    (map-set budgets budget-id {
      title: title,
      description: description,
      total-amount: total-amount,
      spent-amount: u0,
      category: category,
      created-at: stacks-block-height,
      created-by: tx-sender,
      active: true
    })
    (var-set next-budget-id (+ budget-id u1))
    (ok budget-id)
  )
)

(define-public (approve-budget (budget-id uint))
  (let ((budget (unwrap! (get-budget budget-id) ERR_BUDGET_NOT_FOUND)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (get active budget) ERR_BUDGET_NOT_FOUND)
    (asserts! (is-none (get-budget-approval budget-id tx-sender)) ERR_ALREADY_VOTED)
    (map-set budget-approvals { budget-id: budget-id, approver: tx-sender } { approved: true, approval-time: stacks-block-height })
    (ok true)
  )
)

(define-public (create-expense (budget-id uint) (amount uint) (description (string-ascii 200)) (recipient principal))
  (let (
    (expense-id (var-get next-expense-id))
    (budget (unwrap! (get-budget budget-id) ERR_BUDGET_NOT_FOUND))
  )
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active budget) ERR_BUDGET_NOT_FOUND)
    (asserts! (<= (+ (get spent-amount budget) amount) (get total-amount budget)) ERR_BUDGET_EXHAUSTED)
    (map-set expenses expense-id {
      budget-id: budget-id,
      amount: amount,
      description: description,
      recipient: recipient,
      approved: false,
      created-at: stacks-block-height,
      created-by: tx-sender,
      approved-by: none
    })
    (var-set next-expense-id (+ expense-id u1))
    (ok expense-id)
  )
)

(define-public (approve-expense (expense-id uint))
  (let ((expense (unwrap! (get-expense expense-id) ERR_EXPENSE_NOT_FOUND)))
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (not (get approved expense)) ERR_UNAUTHORIZED)
    (map-set expenses expense-id (merge expense { approved: true, approved-by: (some tx-sender) }))
    (ok true)
  )
)

(define-public (execute-expense (expense-id uint))
  (let (
    (expense (unwrap! (get-expense expense-id) ERR_EXPENSE_NOT_FOUND))
    (budget-id (get budget-id expense))
    (budget (unwrap! (get-budget budget-id) ERR_BUDGET_NOT_FOUND))
    (amount (get amount expense))
    (recipient (get recipient expense))
  )
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (get approved expense) ERR_UNAUTHORIZED)
    (asserts! (>= (var-get treasury-balance) amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (get active budget) ERR_BUDGET_NOT_FOUND)
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (map-set budgets budget-id (merge budget { spent-amount: (+ (get spent-amount budget) amount) }))
    (ok true)
  )
)

(define-public (deactivate-budget (budget-id uint))
  (let ((budget (unwrap! (get-budget budget-id) ERR_BUDGET_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get created-by budget))) ERR_UNAUTHORIZED)
    (map-set budgets budget-id (merge budget { active: false }))
    (ok true)
  )
)

(define-read-only (get-budget-remaining (budget-id uint))
  (match (get-budget budget-id)
    budget (ok (- (get total-amount budget) (get spent-amount budget)))
    ERR_BUDGET_NOT_FOUND
  )
)

(define-read-only (calculate-budget-approval-count (budget-id uint))
  (let ((required-approvals (calculate-required-votes)))
    (fold count-budget-approvals (list tx-sender) u0)
  )
)

(define-private (count-budget-approvals (approver principal) (acc uint))
  (+ acc u1)
)

;; (define-read-only (get-amendment-yes-votes (amendment-id uint))
;;   (fold count-amendment-yes-votes (list) u0)
;; )

;; (define-private (count-amendment-yes-votes (item (tuple)) (acc uint))
;;   (ok acc (+ acc (if (get vote item) (get voting-power item) u0)))
;; )

(define-read-only (get-active-amendments)
  (filter is-amendment-active (list u1 u2 u3 u4 u5))
)

(define-private (is-amendment-active (amendment-id uint))
  (match (get-amendment amendment-id)
    amendment (and (get ratified amendment) (not (get superseded amendment)))
    false
  )
)