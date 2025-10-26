(define-non-fungible-token resume-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-proficiency (err u104))
(define-constant err-zero-proficiency (err u105))
(define-constant err-self-endorsement (err u106))

(define-map resumes
    uint 
    {
        owner: principal,
        name: (string-ascii 50),
        title: (string-ascii 100),
        created-at: uint
    }
)

(define-map work-experiences
    {resume-id: uint, experience-id: uint}
    {
        company: (string-ascii 100),
        role: (string-ascii 100),
        start-date: uint,
        end-date: uint,
        verified: bool,
        verifier: (optional principal)
    }
)

(define-map resume-counters
    principal
    uint
)

(define-map experience-counters
    uint
    uint
)

(define-public (mint-resume (name (string-ascii 50)) (title (string-ascii 100)))
    (let 
        (
            (resume-id (default-to u0 (get-resume-count tx-sender)))
            (new-id (+ resume-id u1))
        )
        (try! (nft-mint? resume-nft resume-id tx-sender))
        (map-set resumes resume-id {
            owner: tx-sender,
            name: name,
            title: title,
            created-at: burn-block-height
        })
        (map-set resume-counters tx-sender new-id)
        (ok resume-id)
    )
)

(define-public (add-experience 
    (resume-id uint)
    (company (string-ascii 100))
    (role (string-ascii 100))
    (start-date uint)
    (end-date uint)
)
    (let
        (
            (experience-id (default-to u0 (get-experience-count resume-id)))
            (new-id (+ experience-id u1))
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (map-set work-experiences {resume-id: resume-id, experience-id: experience-id}
            {
                company: company,
                role: role,
                start-date: start-date,
                end-date: end-date,
                verified: false,
                verifier: none
            }
        )
        (map-set experience-counters resume-id new-id)
        (ok experience-id)
    )
)

(define-public (verify-experience (resume-id uint) (experience-id uint))
    (let
        (
            (experience (unwrap! (get-experience resume-id experience-id) err-not-found))
        )
        (asserts! (not (get verified experience)) err-already-exists)
        (map-set work-experiences {resume-id: resume-id, experience-id: experience-id}
            (merge experience {
                verified: true,
                verifier: (some tx-sender)
            })
        )
        (ok true)
    )
)

(define-read-only (get-resume (resume-id uint))
    (map-get? resumes resume-id)
)

(define-read-only (get-experience (resume-id uint) (experience-id uint))
    (map-get? work-experiences {resume-id: resume-id, experience-id: experience-id})
)

(define-read-only (get-resume-count (owner principal))
    (map-get? resume-counters owner)
)

(define-read-only (get-experience-count (resume-id uint))
    (map-get? experience-counters resume-id)
)

(define-public (transfer (resume-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-unauthorized)
        (try! (nft-transfer? resume-nft resume-id sender recipient))
        (let
            ((resume (unwrap! (get-resume resume-id) err-not-found)))
            (map-set resumes resume-id 
                (merge resume {owner: recipient})
            )
            (ok true)
        )
    )
)


(define-map resume-skills
    {resume-id: uint, skill-id: uint}
    {
        skill-name: (string-ascii 50),
        skill-category: (string-ascii 30),
        proficiency-level: uint,
        added-at: uint
    }
)

(define-map skill-endorsements
    {resume-id: uint, skill-id: uint, endorser: principal}
    {
        endorsed-at: uint,
        endorser-title: (string-ascii 100)
    }
)

(define-map skill-counters
    uint
    uint
)

(define-map endorsement-counters
    {resume-id: uint, skill-id: uint}
    uint
)

(define-public (add-skill 
    (resume-id uint)
    (skill-name (string-ascii 50))
    (skill-category (string-ascii 30))
    (proficiency-level uint)
)
    (let
        (
            (skill-id (default-to u0 (get-skill-count resume-id)))
            (new-id (+ skill-id u1))
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (asserts! (<= proficiency-level u5) (err u104))
        (asserts! (> proficiency-level u0) (err u105))
        (map-set resume-skills {resume-id: resume-id, skill-id: skill-id}
            {
                skill-name: skill-name,
                skill-category: skill-category,
                proficiency-level: proficiency-level,
                added-at: burn-block-height
            }
        )
        (map-set skill-counters resume-id new-id)
        (ok skill-id)
    )
)

(define-public (endorse-skill 
    (resume-id uint) 
    (skill-id uint)
    (endorser-title (string-ascii 100))
)
    (let
        (
            (skill (unwrap! (get-skill resume-id skill-id) err-not-found))
            (resume (unwrap! (get-resume resume-id) err-not-found))
            (endorsement-key {resume-id: resume-id, skill-id: skill-id, endorser: tx-sender})
        )
        (asserts! (not (is-eq (get owner resume) tx-sender)) (err u106))
        (asserts! (is-none (map-get? skill-endorsements endorsement-key)) err-already-exists)
        (map-set skill-endorsements endorsement-key
            {
                endorsed-at: burn-block-height,
                endorser-title: endorser-title
            }
        )
        (let
            (
                (current-count (default-to u0 (get-endorsement-count resume-id skill-id)))
                (new-count (+ current-count u1))
            )
            (map-set endorsement-counters {resume-id: resume-id, skill-id: skill-id} new-count)
            (ok new-count)
        )
    )
)

(define-read-only (get-skill (resume-id uint) (skill-id uint))
    (map-get? resume-skills {resume-id: resume-id, skill-id: skill-id})
)

(define-read-only (get-skill-endorsement (resume-id uint) (skill-id uint) (endorser principal))
    (map-get? skill-endorsements {resume-id: resume-id, skill-id: skill-id, endorser: endorser})
)

(define-read-only (get-skill-count (resume-id uint))
    (map-get? skill-counters resume-id)
)

(define-read-only (get-endorsement-count (resume-id uint) (skill-id uint))
    (map-get? endorsement-counters {resume-id: resume-id, skill-id: skill-id})
)

(define-non-fungible-token achievement-badge {resume-id: uint, badge-id: uint})

(define-map badges
    {resume-id: uint, badge-id: uint}
    {
        badge-name: (string-ascii 100),
        badge-type: (string-ascii 50),
        issuer: (string-ascii 100),
        issued-date: uint,
        expiry-date: (optional uint),
        verified: bool,
        verifier: (optional principal),
        metadata-uri: (optional (string-ascii 200))
    }
)

(define-map badge-counters
    uint
    uint
)

(define-map authorized-badge-issuers
    principal
    bool
)

(define-public (authorize-badge-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-badge-issuers issuer true)
        (ok true)
    )
)

(define-public (mint-badge
    (resume-id uint)
    (badge-name (string-ascii 100))
    (badge-type (string-ascii 50))
    (issuer (string-ascii 100))
    (issued-date uint)
    (expiry-date (optional uint))
    (metadata-uri (optional (string-ascii 200)))
)
    (let
        (
            (badge-id (default-to u0 (get-badge-count resume-id)))
            (new-id (+ badge-id u1))
            (resume (unwrap! (get-resume resume-id) err-not-found))
            (badge-token-id {resume-id: resume-id, badge-id: badge-id})
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (try! (nft-mint? achievement-badge badge-token-id tx-sender))
        (map-set badges badge-token-id
            {
                badge-name: badge-name,
                badge-type: badge-type,
                issuer: issuer,
                issued-date: issued-date,
                expiry-date: expiry-date,
                verified: false,
                verifier: none,
                metadata-uri: metadata-uri
            }
        )
        (map-set badge-counters resume-id new-id)
        (ok badge-id)
    )
)

(define-public (verify-badge (resume-id uint) (badge-id uint))
    (let
        (
            (badge-key {resume-id: resume-id, badge-id: badge-id})
            (badge (unwrap! (get-badge resume-id badge-id) err-not-found))
        )
        (asserts! (not (get verified badge)) err-already-exists)
        (asserts! (default-to false (map-get? authorized-badge-issuers tx-sender)) err-unauthorized)
        (map-set badges badge-key
            (merge badge {
                verified: true,
                verifier: (some tx-sender)
            })
        )
        (ok true)
    )
)

(define-public (transfer-badge 
    (resume-id uint) 
    (badge-id uint) 
    (sender principal) 
    (recipient principal)
)
    (let
        (
            (badge-key {resume-id: resume-id, badge-id: badge-id})
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq tx-sender sender) err-unauthorized)
        (asserts! (is-eq (get owner resume) sender) err-unauthorized)
        (try! (nft-transfer? achievement-badge badge-key sender recipient))
        (ok true)
    )
)

(define-read-only (get-badge (resume-id uint) (badge-id uint))
    (map-get? badges {resume-id: resume-id, badge-id: badge-id})
)

(define-read-only (get-badge-count (resume-id uint))
    (map-get? badge-counters resume-id)
)

(define-read-only (is-authorized-issuer (issuer principal))
    (default-to false (map-get? authorized-badge-issuers issuer))
)

(define-read-only (get-badge-owner (resume-id uint) (badge-id uint))
    (nft-get-owner? achievement-badge {resume-id: resume-id, badge-id: badge-id})
)

(define-constant err-privacy-restricted (err u107))

(define-map resume-privacy-settings
    uint
    {
        is-public: bool,
        allow-skill-viewing: bool,
        allow-experience-viewing: bool,
        allow-badge-viewing: bool
    }
)

(define-map authorized-viewers
    {resume-id: uint, viewer: principal}
    {
        granted-at: uint,
        can-view-experiences: bool,
        can-view-skills: bool,
        can-view-badges: bool
    }
)

(define-public (set-privacy-settings
    (resume-id uint)
    (is-public bool)
    (allow-skill-viewing bool)
    (allow-experience-viewing bool)
    (allow-badge-viewing bool)
)
    (let
        (
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (map-set resume-privacy-settings resume-id
            {
                is-public: is-public,
                allow-skill-viewing: allow-skill-viewing,
                allow-experience-viewing: allow-experience-viewing,
                allow-badge-viewing: allow-badge-viewing
            }
        )
        (ok true)
    )
)

(define-public (grant-viewer-access
    (resume-id uint)
    (viewer principal)
    (can-view-experiences bool)
    (can-view-skills bool)
    (can-view-badges bool)
)
    (let
        (
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (map-set authorized-viewers {resume-id: resume-id, viewer: viewer}
            {
                granted-at: burn-block-height,
                can-view-experiences: can-view-experiences,
                can-view-skills: can-view-skills,
                can-view-badges: can-view-badges
            }
        )
        (ok true)
    )
)

(define-public (revoke-viewer-access (resume-id uint) (viewer principal))
    (let
        (
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (map-delete authorized-viewers {resume-id: resume-id, viewer: viewer})
        (ok true)
    )
)

(define-read-only (can-view-resume-data (resume-id uint) (viewer principal) (data-type (string-ascii 20)))
    (let
        (
            (resume (unwrap! (get-resume resume-id) (ok false)))
            (privacy-settings (get-privacy-settings resume-id))
            (viewer-permissions (get-viewer-permissions resume-id viewer))
        )
        (if (is-eq (get owner resume) viewer)
            (ok true)
            (if (get is-public privacy-settings)
                (if (is-eq data-type "experiences")
                    (ok (get allow-experience-viewing privacy-settings))
                    (if (is-eq data-type "skills")
                        (ok (get allow-skill-viewing privacy-settings))
                        (if (is-eq data-type "badges")
                            (ok (get allow-badge-viewing privacy-settings))
                            (ok false)
                        )
                    )
                )
                (match viewer-permissions
                    some-permissions
                    (if (is-eq data-type "experiences")
                        (ok (get can-view-experiences some-permissions))
                        (if (is-eq data-type "skills")
                            (ok (get can-view-skills some-permissions))
                            (if (is-eq data-type "badges")
                                (ok (get can-view-badges some-permissions))
                                (ok false)
                            )
                        )
                    )
                    (ok false)
                )
            )
        )
    )
)

(define-read-only (get-privacy-settings (resume-id uint))
    (default-to 
        {
            is-public: true,
            allow-skill-viewing: true,
            allow-experience-viewing: true,
            allow-badge-viewing: true
        }
        (map-get? resume-privacy-settings resume-id)
    )
)

(define-read-only (get-viewer-permissions (resume-id uint) (viewer principal))
    (map-get? authorized-viewers {resume-id: resume-id, viewer: viewer})
)

(define-read-only (get-experience-private (resume-id uint) (experience-id uint))
    (if (unwrap-panic (can-view-resume-data resume-id tx-sender "experiences"))
        (get-experience resume-id experience-id)
        none
    )
)

(define-read-only (get-skill-private (resume-id uint) (skill-id uint))
    (if (unwrap-panic (can-view-resume-data resume-id tx-sender "skills"))
        (get-skill resume-id skill-id)
        none
    )
)

(define-read-only (get-badge-private (resume-id uint) (badge-id uint))
    (if (unwrap-panic (can-view-resume-data resume-id tx-sender "badges"))
        (get-badge resume-id badge-id)
        none
    )
)

(define-map reputation-scores
    uint
    {
        base-score: uint,
        verification-bonus: uint,
        endorsement-bonus: uint,
        badge-bonus: uint,
        total-score: uint,
        last-updated: uint
    }
)

(define-map reputation-weights
    (string-ascii 20)
    uint
)

(define-public (initialize-reputation-weights)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set reputation-weights "verified-exp" u10)
        (map-set reputation-weights "unverified-exp" u5)
        (map-set reputation-weights "skill-endorsement" u3)
        (map-set reputation-weights "verified-badge" u15)
        (map-set reputation-weights "unverified-badge" u8)
        (ok true)
    )
)

(define-public (update-reputation-weights 
    (verified-exp-weight uint)
    (unverified-exp-weight uint)
    (endorsement-weight uint)
    (verified-badge-weight uint)
    (unverified-badge-weight uint)
)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set reputation-weights "verified-exp" verified-exp-weight)
        (map-set reputation-weights "unverified-exp" unverified-exp-weight)
        (map-set reputation-weights "skill-endorsement" endorsement-weight)
        (map-set reputation-weights "verified-badge" verified-badge-weight)
        (map-set reputation-weights "unverified-badge" unverified-badge-weight)
        (ok true)
    )
)

(define-public (calculate-reputation-score (resume-id uint))
    (let
        (
            (resume (unwrap! (get-resume resume-id) err-not-found))
            (exp-count (default-to u0 (get-experience-count resume-id)))
            (skill-count (default-to u0 (get-skill-count resume-id)))
            (badge-count (default-to u0 (get-badge-count resume-id)))
            (base-score u50)
        )
        (let
            (
                (exp-score (* exp-count u8))
                (skill-score (* skill-count u5))
                (badge-score (* badge-count u12))
                (total-score (+ (+ (+ base-score exp-score) skill-score) badge-score))
            )
            (map-set reputation-scores resume-id
                {
                    base-score: base-score,
                    verification-bonus: exp-score,
                    endorsement-bonus: skill-score,
                    badge-bonus: badge-score,
                    total-score: total-score,
                    last-updated: burn-block-height
                }
            )
            (ok total-score)
        )
    )
)

(define-public (update-reputation-score 
    (resume-id uint)
    (verified-exp-count uint)
    (total-endorsements uint)
    (verified-badge-count uint)
)
    (let
        (
            (resume (unwrap! (get-resume resume-id) err-not-found))
            (verified-exp-weight (default-to u10 (map-get? reputation-weights "verified-exp")))
            (endorsement-weight (default-to u3 (map-get? reputation-weights "skill-endorsement")))
            (verified-badge-weight (default-to u15 (map-get? reputation-weights "verified-badge")))
            (base-score u50)
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (let
            (
                (exp-score (* verified-exp-count verified-exp-weight))
                (skill-score (* total-endorsements endorsement-weight))
                (badge-score (* verified-badge-count verified-badge-weight))
                (total-score (+ (+ (+ base-score exp-score) skill-score) badge-score))
            )
            (map-set reputation-scores resume-id
                {
                    base-score: base-score,
                    verification-bonus: exp-score,
                    endorsement-bonus: skill-score,
                    badge-bonus: badge-score,
                    total-score: total-score,
                    last-updated: burn-block-height
                }
            )
            (ok total-score)
        )
    )
)

(define-read-only (get-reputation-score (resume-id uint))
    (map-get? reputation-scores resume-id)
)

(define-read-only (get-reputation-weights)
    {
        verified-exp: (default-to u10 (map-get? reputation-weights "verified-exp")),
        unverified-exp: (default-to u5 (map-get? reputation-weights "unverified-exp")),
        skill-endorsement: (default-to u3 (map-get? reputation-weights "skill-endorsement")),
        verified-badge: (default-to u15 (map-get? reputation-weights "verified-badge")),
        unverified-badge: (default-to u8 (map-get? reputation-weights "unverified-badge"))
    }
)

(define-read-only (get-reputation-rank (resume-id uint))
    (let
        (
            (score-data (get-reputation-score resume-id))
        )
        (match score-data
            some-score
            (let
                (
                    (total (get total-score some-score))
                )
                (if (<= total u75)
                    "Bronze"
                    (if (<= total u150)
                        "Silver"
                        (if (<= total u250)
                            "Gold"
                            (if (<= total u400)
                                "Platinum"
                                "Diamond"
                            )
                        )
                    )
                )
            )
            "Unranked"
        )
    )
)

(define-constant err-referral-exists (err u108))
(define-constant err-self-referral (err u109))
(define-constant err-invalid-status (err u110))

(define-map professional-referrals
    {resume-id: uint, referral-id: uint}
    {
        referrer: principal,
        referrer-company: (string-ascii 100),
        referrer-title: (string-ascii 100),
        relationship: (string-ascii 50),
        recommendation-text: (string-ascii 500),
        status: (string-ascii 20),
        created-at: uint,
        accepted-at: (optional uint)
    }
)

(define-map referral-counters
    uint
    uint
)

(define-map referral-status-counts
    {resume-id: uint, status: (string-ascii 20)}
    uint
)

(define-public (create-referral
    (resume-id uint)
    (referrer-company (string-ascii 100))
    (referrer-title (string-ascii 100))
    (relationship (string-ascii 50))
    (recommendation-text (string-ascii 500))
)
    (let
        (
            (referral-id (default-to u0 (get-referral-count resume-id)))
            (new-id (+ referral-id u1))
            (resume (unwrap! (get-resume resume-id) err-not-found))
            (referral-key {resume-id: resume-id, referral-id: referral-id})
        )
        (asserts! (not (is-eq (get owner resume) tx-sender)) err-self-referral)
        (map-set professional-referrals referral-key
            {
                referrer: tx-sender,
                referrer-company: referrer-company,
                referrer-title: referrer-title,
                relationship: relationship,
                recommendation-text: recommendation-text,
                status: "pending",
                created-at: burn-block-height,
                accepted-at: none
            }
        )
        (map-set referral-counters resume-id new-id)
        (increment-status-count resume-id "pending")
        (ok referral-id)
    )
)

(define-public (accept-referral (resume-id uint) (referral-id uint))
    (let
        (
            (referral-key {resume-id: resume-id, referral-id: referral-id})
            (referral (unwrap! (get-referral resume-id referral-id) err-not-found))
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status referral) "pending") err-invalid-status)
        (decrement-status-count resume-id "pending")
        (increment-status-count resume-id "accepted")
        (map-set professional-referrals referral-key
            (merge referral {
                status: "accepted",
                accepted-at: (some burn-block-height)
            })
        )
        (ok true)
    )
)

(define-public (reject-referral (resume-id uint) (referral-id uint))
    (let
        (
            (referral-key {resume-id: resume-id, referral-id: referral-id})
            (referral (unwrap! (get-referral resume-id referral-id) err-not-found))
            (resume (unwrap! (get-resume resume-id) err-not-found))
        )
        (asserts! (is-eq (get owner resume) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status referral) "pending") err-invalid-status)
        (decrement-status-count resume-id "pending")
        (increment-status-count resume-id "rejected")
        (map-set professional-referrals referral-key
            (merge referral {status: "rejected"})
        )
        (ok true)
    )
)

(define-private (increment-status-count (resume-id uint) (status (string-ascii 20)))
    (let
        (
            (current-count (default-to u0 (get-status-count resume-id status)))
            (new-count (+ current-count u1))
        )
        (map-set referral-status-counts {resume-id: resume-id, status: status} new-count)
        new-count
    )
)

(define-private (decrement-status-count (resume-id uint) (status (string-ascii 20)))
    (let
        (
            (current-count (default-to u0 (get-status-count resume-id status)))
            (new-count (if (> current-count u0) (- current-count u1) u0))
        )
        (map-set referral-status-counts {resume-id: resume-id, status: status} new-count)
        new-count
    )
)

(define-read-only (get-referral (resume-id uint) (referral-id uint))
    (map-get? professional-referrals {resume-id: resume-id, referral-id: referral-id})
)

(define-read-only (get-referral-count (resume-id uint))
    (map-get? referral-counters resume-id)
)

(define-read-only (get-status-count (resume-id uint) (status (string-ascii 20)))
    (map-get? referral-status-counts {resume-id: resume-id, status: status})
)

(define-read-only (get-accepted-referrals-count (resume-id uint))
    (default-to u0 (get-status-count resume-id "accepted"))
)

(define-read-only (get-pending-referrals-count (resume-id uint))
    (default-to u0 (get-status-count resume-id "pending"))
)
