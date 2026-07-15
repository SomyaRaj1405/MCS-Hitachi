# MCS 1,000-Transaction Scalability Verification

Run date: 15 July 2026  
Acceptance target: p95 REST response time below 2,000 ms, zero failed lifecycle operations.

## Result

| Metric | Measured |
|---|---:|
| Complete transaction lifecycles | 1,000 |
| Merchants | 100 |
| REST requests | 3,000 |
| Failures | 0 |
| Total elapsed time | 16.104 s |
| Throughput | 62.10 transactions/s |
| Average REST response | 4.80 ms |
| p95 REST response | 9.45 ms |
| Maximum REST response | 687.53 ms |
| 2-second target | **PASS** |

The run creates 100 merchants and distributes 1,000 lifecycles evenly across them (10 per merchant). Each lifecycle creates a bill and calls the authenticated REST boundary for `initiate`, `authorize`, and `settle`. It then verifies 1,000 transaction rows, 1,000 settlement rows, and 100 merchant rows.

## Environment and interpretation

This is a repeatable application-level scalability test using Spring Boot, MockMvc, JWT authorization, JPA, and H2 in PostgreSQL compatibility mode. Kafka publishing is mocked so broker/network capacity is not included. The result demonstrates that the application logic can process far more than 1,000 transactions in a test run and satisfies the BRD latency target in this controlled environment. A production capacity claim still requires a deployment-level run against PostgreSQL, Kafka, real network hops, and production-sized infrastructure.

## Reproduce

PowerShell:

```powershell
cd mcs
.\mvnw.cmd --% -q -Dtest=TransactionScalabilityTest -Dmcs.performance.tests=true test
```

Bash:

```bash
cd mcs
./mvnw -q -Dtest=TransactionScalabilityTest -Dmcs.performance.tests=true test
```

Machine-readable output is written to `mcs/target/performance-reports/1000-transactions.json`.
