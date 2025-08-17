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
(define-constant ERR_INSUFFICIENT_REPUTATION (err u115))
(define-constant ERR_BADGE_NOT_FOUND (err u116))
(define-constant ERR_BADGE_ALREADY_EARNED (err u117))
(define-constant ERR_INVALID_REPUTATION (err u118))

(define-data-var next-proposal-id uint u1)
(define-data-var next-amendment-id uint u1)
(define-data-var total-members uint u0)
(define-data-var quorum-percentage uint u51)
(define-data-var voting-period uint u1440)
(define-data-var treasury-balance uint u0)
(define-data-var next-budget-id uint u1)
(define-data-var next-expense-id uint u1)
(define-data-var next-badge-id uint u1)
(define-data-var reputation-decay-rate uint u5)

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

(define-map member-reputation
  principal
  {
    total-points: uint,
    last-activity: uint,
    proposals-created: uint,
    successful-proposals: uint,
    votes-cast: uint,
    budgets-created: uint
  }
)

(define-map merit-badges
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    points-required: uint,
    badge-type: (string-ascii 20),
    active: bool
  }
)

(define-map member-badges
  { member: principal, badge-id: uint }
  { earned-at: uint, verified: bool }
)

(define-map reputation-activities
  principal
  {
    proposal-bonus: uint,
    voting-bonus: uint,
    budget-bonus: uint,
    consecutive-votes: uint
  }
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

(define-read-only (get-member-reputation (member principal))
  (default-to { total-points: u0, last-activity: u0, proposals-created: u0, successful-proposals: u0, votes-cast: u0, budgets-created: u0 } 
    (map-get? member-reputation member))
)

(define-read-only (get-merit-badge (badge-id uint))
  (map-get? merit-badges badge-id)
)

(define-read-only (get-member-badge (member principal) (badge-id uint))
  (map-get? member-badges { member: member, badge-id: badge-id })
)

(define-read-only (get-reputation-activities (member principal))
  (default-to { proposal-bonus: u0, voting-bonus: u0, budget-bonus: u0, consecutive-votes: u0 }
    (map-get? reputation-activities member))
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
    (map-set member-reputation tx-sender { total-points: u10, last-activity: stacks-block-height, proposals-created: u0, successful-proposals: u0, votes-cast: u0, budgets-created: u0 })
    (map-set reputation-activities tx-sender { proposal-bonus: u0, voting-bonus: u0, budget-bonus: u0, consecutive-votes: u0 })
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

(define-public (create-merit-badge (name (string-ascii 50)) (description (string-ascii 200)) (points-required uint) (badge-type (string-ascii 20)))
  (let ((badge-id (var-get next-badge-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> points-required u0) ERR_INVALID_REPUTATION)
    (map-set merit-badges badge-id {
      name: name,
      description: description,
      points-required: points-required,
      badge-type: badge-type,
      active: true
    })
    (var-set next-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)

(define-public (award-reputation-points (member principal) (points uint) (activity-type (string-ascii 20)))
  (let (
    (current-rep (get-member-reputation member))
    (current-activities (get-reputation-activities member))
  )
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (get-member-status member) ERR_NOT_MEMBER)
    (asserts! (> points u0) ERR_INVALID_REPUTATION)
    (map-set member-reputation member (merge current-rep {
      total-points: (+ (get total-points current-rep) points),
      last-activity: stacks-block-height
    }))
    (unwrap-panic (check-and-award-badges member))
    (ok true)
  )
)

(define-public (update-voting-reputation (voter principal))
  (let (
    (current-rep (get-member-reputation voter))
    (current-activities (get-reputation-activities voter))
  )
    (asserts! (get-member-status voter) ERR_NOT_MEMBER)
    (map-set member-reputation voter (merge current-rep {
      votes-cast: (+ (get votes-cast current-rep) u1),
      total-points: (+ (get total-points current-rep) u5),
      last-activity: stacks-block-height
    }))
    (map-set reputation-activities voter (merge current-activities {
      consecutive-votes: (+ (get consecutive-votes current-activities) u1),
      voting-bonus: (if (> (get consecutive-votes current-activities) u10) u2 u0)
    }))
    (ok true)
  )
)

(define-public (update-proposal-reputation (proposer principal) (successful bool))
  (let (
    (current-rep (get-member-reputation proposer))
    (bonus-points (if successful u25 u10))
  )
    (asserts! (get-member-status proposer) ERR_NOT_MEMBER)
    (map-set member-reputation proposer (merge current-rep {
      proposals-created: (+ (get proposals-created current-rep) u1),
      successful-proposals: (if successful (+ (get successful-proposals current-rep) u1) (get successful-proposals current-rep)),
      total-points: (+ (get total-points current-rep) bonus-points),
      last-activity: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (update-budget-reputation (creator principal))
  (let ((current-rep (get-member-reputation creator)))
    (asserts! (get-member-status creator) ERR_NOT_MEMBER)
    (map-set member-reputation creator (merge current-rep {
      budgets-created: (+ (get budgets-created current-rep) u1),
      total-points: (+ (get total-points current-rep) u15),
      last-activity: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (apply-reputation-decay (member principal))
  (let (
    (current-rep (get-member-reputation member))
    (decay-rate (var-get reputation-decay-rate))
    (blocks-since-activity (- stacks-block-height (get last-activity current-rep)))
  )
    (asserts! (get-member-status member) ERR_NOT_MEMBER)
    (asserts! (> blocks-since-activity u2016) ERR_INVALID_REPUTATION)
    (map-set member-reputation member (merge current-rep {
      total-points: (if (> (get total-points current-rep) decay-rate) (- (get total-points current-rep) decay-rate) u0)
    }))
    (ok true)
  )
)

(define-public (claim-merit-badge (badge-id uint))
  (let (
    (badge (unwrap! (get-merit-badge badge-id) ERR_BADGE_NOT_FOUND))
    (member-rep (get-member-reputation tx-sender))
  )
    (asserts! (get-member-status tx-sender) ERR_NOT_MEMBER)
    (asserts! (get active badge) ERR_BADGE_NOT_FOUND)
    (asserts! (>= (get total-points member-rep) (get points-required badge)) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (is-none (get-member-badge tx-sender badge-id)) ERR_BADGE_ALREADY_EARNED)
    (map-set member-badges { member: tx-sender, badge-id: badge-id } { earned-at: stacks-block-height, verified: true })
    (ok true)
  )
)

(define-private (check-and-award-badges (member principal))
  (let ((member-rep (get-member-reputation member)))
    (begin
      (if (>= (get total-points member-rep) u100)
        (map-set member-badges { member: member, badge-id: u1 } { earned-at: stacks-block-height, verified: true })
        true
      )
      (if (>= (get successful-proposals member-rep) u5)
        (map-set member-badges { member: member, badge-id: u2 } { earned-at: stacks-block-height, verified: true })
        true
      )
      (ok true)
    )
  )
)

(define-read-only (calculate-reputation-voting-power (member principal))
  (let (
    (base-power (get-member-voting-power member))
    (reputation (get-member-reputation member))
    (reputation-multiplier (/ (get total-points reputation) u50))
    (capped-multiplier (if (> reputation-multiplier u3) u3 reputation-multiplier))
  )
    (+ base-power capped-multiplier)
  )
)

(define-read-only (get-member-rank (member principal))
  (let ((reputation (get-member-reputation member)))
    (if (>= (get total-points reputation) u500)
      "Expert"
      (if (>= (get total-points reputation) u250)
        "Advanced"
        (if (>= (get total-points reputation) u100)
          "Intermediate"
          (if (>= (get total-points reputation) u50)
            "Contributor"
            "Newcomer"
          )
        )
      )
    )
  )
)

(define-public (deactivate-merit-badge (badge-id uint))
  (let ((badge (unwrap! (get-merit-badge badge-id) ERR_BADGE_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set merit-badges badge-id (merge badge { active: false }))
    (ok true)
  )
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



