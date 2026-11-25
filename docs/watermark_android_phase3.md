# Android Offline Signature Phase 3 Vertical Slice

Date: November 24, 2026

Status: Initial Android implementation. This milestone provides cryptographic consistency checks, not legal identity certification or ownership proof.

## Security model

Dali Camera creates a P-256 signing key in Android Keystore for each canonical owner identity. The private key is non-exportable through the application. Android uses hardware-backed key protection when the device and Keystore implementation provide it; otherwise the key remains protected by Android Keystore software enforcement.

Signing and verification are fully local. No photo, key, identity, digest, signature, or verification result is sent to a Dali server.

The implementation uses Android's documented `EC` Keystore key generation and `SHA256withECDSA` signatures. It supports Android API 23 and newer.

## Signed manifest

The signed manifest binds:

- a full SHA-256 hash of the complete DALI2 identity record, including its optional public label;
- full SHA-256 hashes of the canonical owner ID and unique photo ID;
- compact owner and photo references used by Dali Pixel v2;
- decoded image width and height;
- SHA-256 of normalized decoded ARGB pixels.

The self-contained provenance record also carries the public key, public-key fingerprint, signature, algorithm identifier, and optional Dali capture diagnostics. The public key is safe to share; the private key never enters photo metadata.

## Verification states

Photo Info can report:

- **Offline signature verified:** the ECDSA signature, image digest, dimensions, and DALI2 metadata identity agree;
- **Signed image does not match:** the decoded image pixels or dimensions differ from the signed manifest;
- **Signed identity conflict:** DALI2 metadata owner/photo identity differs from the signed manifest;
- **Signature valid; identity metadata missing:** the signature and image match but the full DALI2 metadata identity is unavailable;
- **Invalid watermark signature:** the manifest or signature does not validate with its embedded public key.

Photo Info separately compares the signed owner/photo references with the Dali Pixel v2 references.

## What “verified” means

Verification establishes that:

1. the holder of the corresponding private key signed the manifest;
2. the current decoded pixels match the signed image digest;
3. the current DALI2 metadata identity matches the signed identity hashes and references.

It does not establish the legal name of the key holder, copyright ownership, licensing rights, consent, or that the public label is globally unique. The current profile is self-asserted and offline.

## Current lifecycle

- New DALI2 captures create or reuse the owner identity's Keystore key.
- Locally rendered derivatives are re-signed after their final pixels are written.
- Metadata-only edits retain the signature so conflicting identity edits are detectable.
- Creating a new watermark identity creates a different owner-specific signing key when the next photo is captured.
- Old keys remain in Android Keystore so existing local derivatives can still be re-signed.
- Settings can copy and restore a versioned recovery code containing the Owner ID and optional Public ID.

The recovery code is fully offline and contains no photo data or private key. Its
checksum detects accidental damage, not malicious modification. Because Android
Keystore private keys are non-exportable, restoring after an uninstall or on a
different device preserves identity labeling but creates a new signing key and
key fingerprint. Existing photos remain independently verifiable using their
embedded public keys; the current version does not cryptographically link the old
and new signing keys.

## Automated acceptance

Android instrumentation covers:

- Keystore key generation and signature verification;
- image digest and dimensions matching;
- full owner/photo hash matching;
- capture diagnostics retained inside the provenance wrapper;
- locally rendered derivative re-signing;
- copied signed metadata rejected on unrelated pixels;
- conflicting DALI2 metadata detection.

Flutter tests cover all visible verification, warning, pixel-agreement, and pixel-conflict states.

## Limitations and next work

- Add encrypted, user-controlled signing-key continuity or a reviewed key-rotation proof.
- Add QR/file transport for the existing identity recovery code.
- Add explicit key rotation, local revocation records, deletion, and lost-device behavior.
- Decide whether optional biometric confirmation should protect signing operations.
- Add iOS Keychain/Secure Enclave signing after the manifest format is reviewed.
- Add a focused independent cryptographic and privacy review before production verification claims.
- Evaluate compatibility with C2PA/Content Credentials instead of presenting this private format as an industry standard.
- Benchmark full-resolution digest and signing latency, memory, and thermal impact on multiple devices.
