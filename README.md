# 🎓 Certificate Registry Smart Contract

A blockchain-based certificate issuance and verification system built with Clarity for the Stacks blockchain. Schools, bootcamps, and educational institutions can issue tamper-proof digital certificates that can be verified by anyone.

## ✨ Features

- 🏫 **Issuer Management**: Only approved institutions can issue certificates
- 📜 **Certificate Issuance**: Issue individual or bulk certificates with detailed metadata
- 🔍 **Verification System**: Verify certificate authenticity and validity
- 🚫 **Revocation Support**: Issuers can revoke certificates if needed
- 📊 **Query Functions**: Retrieve certificates by recipient, issuer, or ID
- 🛡️ **Security**: Built-in authorization and validation checks

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to validate the contract

## 📖 Usage

### For Contract Owner

#### Approve an Issuer
```clarity
(contract-call? .certificate-registry approve-issuer 'SP1EXAMPLE...)
```

#### Revoke an Issuer
```clarity
(contract-call? .certificate-registry revoke-issuer 'SP1EXAMPLE...)
```

### For Approved Issuers

#### Issue a Certificate
```clarity
(contract-call? .certificate-registry issue-certificate
  'SP1RECIPIENT...
  "Full Stack Web Development Bootcamp"
  u20240315
  "A+"
  (list "JavaScript" "React" "Node.js" "MongoDB")
  (some "https://metadata.example.com/cert123")
)
```

#### Bulk Issue Certificates
```clarity
(contract-call? .certificate-registry bulk-issue-certificates
  (list 'SP1RECIPIENT1... 'SP1RECIPIENT2... 'SP1RECIPIENT3...)
  "Data Science Bootcamp"
  u20240315
  "A"
  (list "Python" "Machine Learning" "SQL")
)
```

#### Revoke a Certificate
```clarity
(contract-call? .certificate-registry revoke-certificate u1)
```

### For Anyone (Read-Only Functions)

#### Get Certificate Details
```clarity
(contract-call? .certificate-registry get-certificate u1)
```

#### Verify Certificate
```clarity
(contract-call? .certificate-registry verify-certificate u1)
```

#### Check if Issuer is Approved
```clarity
(contract-call? .certificate-registry is-approved-issuer 'SP1ISSUER...)
```

#### Get Recipient's Certificates
```clarity
(contract-call? .certificate-registry get-recipient-certificates 'SP1RECIPIENT...)
```

#### Get Issuer's Certificates
```clarity
(contract-call? .certificate-registry get-issuer-certificates 'SP1ISSUER...)
```

## 🏗️ Contract Structure

### Data Maps
- `approved-issuers`: Tracks approved certificate issuers
- `certificates`: Stores all certificate data
- `certificate-by-recipient`: Maps recipient+issuer+program to certificate ID
- `issuer-certificates`: Lists certificates issued by each issuer
- `recipient-certificates`: Lists certificates received by each recipient

### Certificate Data Structure
```clarity
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
```

## 🔒 Security Features

- Only contract owner can approve/revoke issuers
- Only approved issuers can issue certificates
- Only issuers can revoke their own certificates
- Duplicate certificates for same recipient+issuer+program are prevented
- Certificate validity checks include revocation status

## 📊 Statistics

The contract tracks:
- Total number of certificates issued
- Total number of approved issuers
- Individual certificate validity status

## 🧪 Testing

Run the test suite with:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or issues, please open a GitHub issue or contact the development team.
```

**Git Commit Message:**
```
feat: implement MVP certificate registry smart contract with issuer management and verification
```

**GitHub Pull Request Title:**
```
🎓 Add Certificate Registry Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## Summary
This PR introduces a complete Certificate Registry smart contract MVP that enables educational institutions to issue and manage blockchain-based certificates.

## What's Added
- **Smart Contract**: Complete Clarity implementation with 150+ lines of production-ready code
- **Issuer Management**: Owner can approve/revoke certificate issuers
- **Certificate Issuance**: Individual and bulk certificate creation with rich metadata
- **Verification System**: Public verification of certificate authenticity
- **Revocation Support**: Issuers can revoke certificates when needed
- **Query Functions**: Comprehensive read-only functions for data retrieval
- **Documentation**: Complete README with usage examples and API documentation

## Key Features
✅ Secure issuer authorization system
✅ Tamper-proof certificate storage
✅ Public verification capabilities
✅ Bulk issuance for efficiency
✅ Certificate revocation mechanism
✅ Comprehensive query interface

## Technical Details
- Built with Clarity for Stacks blockchain
- Implements proper error handling and validation
- Uses efficient data structures for scalability
- Includes security checks and access controls

Ready for deployment and testing in Clarinet environment.
