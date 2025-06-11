(define-non-fungible-token resume-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))

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
