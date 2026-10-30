# brf_samlat_flutter_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local backend (PocketBase dev DB)

Debug builds talk to `http://127.0.0.1:8090` unless `--dart-define=PB_URL=...`
is given (note: `ios/Flutter/Debug.xcconfig` currently injects the prod
`PB_URL`; comment it out to test locally on iOS). Don't run that local backend
on `../brf-samlat-pb/pb_data` — it holds real member data and has live SMTP.
Build a fake-data dev DB instead (see `../brf-samlat-pb/README.md`):

```bash
cd ../brf-samlat-pb
scripts/create-dev-db.sh        # creates ./pb_data_dev and prints the logins
INVITATION_TOKEN_SECRET=dev-invitation-secret \
  ./pocketbase serve --dir=./pb_data_dev --hooksDir=./pb_hooks --migrationsDir=./pb_migrations
```

On the Android emulator use `--dart-define=PB_URL=http://10.0.2.2:8090`.
