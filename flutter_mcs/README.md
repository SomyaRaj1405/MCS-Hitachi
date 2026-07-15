# flutter_mcs

## Presentation preflight

Start Docker Desktop, then run this command before starting the Spring backend
or Flutter application:

```powershell
.\tools\presentation_preflight.ps1
```

The script starts the repository's Kafka stack, waits for the broker to accept
requests, verifies the `transaction-completed` topic, and checks whether the
backend is reachable on port 8080. Kafka UI is available at
`http://localhost:8090`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
