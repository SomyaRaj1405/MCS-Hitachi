# MCS API Plan — 12 Endpoints

## Auth APIs
| ID | Method | Endpoint | Description | Role |
|---|---|---|---|---|
| FR-API-01 | POST | /auth/register | Register merchant or customer | Public |
| FR-API-02 | POST | /auth/login | Login and get JWT token | Public |

## Bill APIs
| ID | Method | Endpoint | Description | Role |
|---|---|---|---|---|
| FR-API-03 | POST | /bills | Create a new bill | Merchant |
| FR-API-04 | GET | /bills/{id} | Get bill by ID | Both |
| FR-API-05 | GET | /bills/customer/{id} | Get all bills for a customer | Customer |
| FR-API-06 | GET | /bills/merchant/{id} | Get all bills for a merchant | Merchant |

## Transaction APIs
| ID | Method | Endpoint | Description | Role |
|---|---|---|---|---|
| FR-API-07 | POST | /transactions/initiate | Initiate a payment | Customer |
| FR-API-08 | POST | /transactions/authorize | Authorize payment (90% pass) | System |
| FR-API-09 | POST | /transactions/settle | Settle authorized transaction | System |
| FR-API-10 | GET | /transactions/{id} | Get transaction by ID | Both |

## Reporting APIs
| ID | Method | Endpoint | Description | Role |
|---|---|---|---|---|
| FR-API-11 | GET | /reports/daily | Daily transaction summary | Merchant |
| FR-API-12 | GET | /reports/weekly | Weekly transaction summary | Merchant |