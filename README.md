# 📄 Resume NFTs with Verifiable Work History 

A blockchain-based solution for creating verifiable digital resumes using NFTs on the Stacks blockchain.

## 🎯 Features

- Mint resume NFTs with basic profile information
- Add work experiences to resumes
- Get work experiences verified by employers
- Transfer resume ownership
- View resume and experience details

## 🚀 Usage

### Minting a Resume

```clarity
(contract-call? .resume-nfts mint-resume "John Doe" "Software Engineer")
```

### Adding Work Experience

```clarity
(contract-call? .resume-nfts add-experience u1 "Tech Corp" "Senior Developer" u1620000000 u1650000000)
```

### Verifying Experience
Employers can verify work experience:

```clarity
(contract-call? .resume-nfts verify-experience u1 u1)
```

### Viewing Resume Details

```clarity
(contract-call? .resume-nfts get-resume u1)
```

## 🔒 Security

- Only resume owners can add experiences
- Experiences can only be verified once
- Resume transfers require owner authorization

## 🤝 Contributing

Feel free to open issues and submit pull requests!
```
