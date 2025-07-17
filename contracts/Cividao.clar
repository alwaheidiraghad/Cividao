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

(define-data-var next-proposal-id uint u1)
(define-data-var next-amendment-id uint u1)
(define-data-var total-members uint u0)
(define-data-var quorum-percentage uint u51)
(define-data-var voting-period uint u1440)

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