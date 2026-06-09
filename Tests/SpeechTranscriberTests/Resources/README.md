# Test Resources

Drop an `example.m4a` (or other audio file, adjusting the test) here to enable
the integration test `testTranscribeFromAudioFile`.

When this file is absent — or when the host cannot run Apple's on-device speech
engine — the integration test prints a skip notice and passes. All other tests
are pure and run everywhere.
