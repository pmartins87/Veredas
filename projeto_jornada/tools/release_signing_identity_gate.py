#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "product" / "release_signing_identity.json"
IDENTITY = ROOT / "mobile" / "release_identity.json"
ARTIFACT = ROOT / "mobile" / "release_artifact_contract.json"
HEX64 = re.compile(r"^[0-9A-F]{64}$")
PENDING_PREFIX = "PENDING_"


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def fail(message: str) -> None:
    raise ValueError(message)


def normalized_fingerprint(value: Any) -> str:
    return str(value).replace(":", "").replace(" ", "").upper()


def cert_der(path: Path) -> tuple[bytes, str]:
    raw = path.read_bytes()
    if b"-----BEGIN CERTIFICATE-----" in raw:
        text = raw.decode("ascii")
        body = text.split("-----BEGIN CERTIFICATE-----", 1)[1].split("-----END CERTIFICATE-----", 1)[0]
        der = base64.b64decode("".join(body.split()), validate=True)
        return der, "PEM"
    return raw, "DER"


def inspect_public_certificate(path: Path) -> dict[str, Any]:
    der, fmt = cert_der(path)
    if not der:
        fail("upload certificate is empty")
    sha256 = hashlib.sha256(der).hexdigest().upper()

    pubkey = subprocess.run(
        ["openssl", "x509", "-inform", fmt, "-in", str(path), "-pubkey", "-noout"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    key_text = subprocess.run(
        ["openssl", "pkey", "-pubin", "-text", "-noout"],
        input=pubkey,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    match = re.search(r"Public-Key:\s*\((\d+)\s+bit\)", key_text, re.IGNORECASE)
    if not match:
        fail("could not determine upload public-key size")
    bits = int(match.group(1))
    algorithm = "RSA" if "modulus:" in key_text.lower() or "rsa" in key_text.lower() else "UNKNOWN"

    end_line = subprocess.run(
        ["openssl", "x509", "-inform", fmt, "-in", str(path), "-enddate", "-noout"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if not end_line.startswith("notAfter="):
        fail("could not determine upload certificate expiry")
    expiry_raw = end_line.split("=", 1)[1]
    expiry = datetime.strptime(expiry_raw, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    return {
        "sha256": sha256,
        "algorithm": algorithm,
        "key_size_bits": bits,
        "not_after_utc": expiry.isoformat().replace("+00:00", "Z"),
    }


def parse_contract_datetime(value: str, label: str) -> datetime:
    if value.startswith(PENDING_PREFIX):
        fail(f"{label} is still pending")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{label} is not ISO-8601 UTC: {value}") from exc
    if parsed.tzinfo is None:
        fail(f"{label} must include timezone")
    return parsed.astimezone(timezone.utc)


def validate_static(contract: dict[str, Any], identity: dict[str, Any], artifact: dict[str, Any], release: bool) -> list[str]:
    errors: list[str] = []
    try:
        app_id = str(contract.get("application_id", ""))
        identity_id = str(identity.get("android", {}).get("application_id", ""))
        artifact_id = str(artifact.get("application_id", ""))
        if not app_id or app_id != identity_id or app_id != artifact_id:
            fail("application_id drift across signing/identity/artifact contracts")

        play = contract.get("play_app_signing", {})
        upload = contract.get("upload_key", {})
        policy = contract.get("identity_policy", {})
        if play.get("required") is not True:
            fail("Google Play App Signing must be required")
        if str(play.get("app_signing_key_managed_by")) != "Google Play":
            fail("app-signing key manager must be Google Play")
        if play.get("private_key_in_repository") is not False or play.get("private_key_in_ci_secrets") is not False:
            fail("Google-held app-signing private key must not be represented as locally stored")
        if str(upload.get("algorithm")) != "RSA" or int(upload.get("minimum_key_size_bits", 0)) < 2048:
            fail("upload key policy must require RSA >= 2048 bits")
        if upload.get("keystore_committed") is not False or upload.get("credentials_committed") is not False:
            fail("upload keystore/credentials must not be committed")
        if policy.get("upload_and_app_signing_certificates_must_differ") is not True:
            fail("upload/app-signing certificate separation must be required")
        if policy.get("private_keys_must_never_be_persisted_as_release_evidence") is not True:
            fail("private-key evidence persistence must be forbidden")

        upload_fp = normalized_fingerprint(upload.get("certificate_sha256", ""))
        app_fp = normalized_fingerprint(play.get("app_signing_certificate_sha256", ""))
        if not str(upload.get("certificate_sha256", "")).startswith(PENDING_PREFIX) and not HEX64.fullmatch(upload_fp):
            fail("upload certificate SHA-256 must be 64 hexadecimal characters")
        if not str(play.get("app_signing_certificate_sha256", "")).startswith(PENDING_PREFIX) and not HEX64.fullmatch(app_fp):
            fail("app-signing certificate SHA-256 must be 64 hexadecimal characters")
        if HEX64.fullmatch(upload_fp) and HEX64.fullmatch(app_fp) and upload_fp == app_fp:
            fail("upload and app-signing certificate fingerprints must differ")

        if release:
            if play.get("configured_in_play_console") is not True:
                fail("Play App Signing is not verified as configured")
            if upload.get("registered_in_play_console") is not True:
                fail("upload certificate is not verified as registered in Play Console")
            if upload.get("redundant_encrypted_backups_outside_repository_verified") is not True:
                fail("redundant encrypted upload-keystore backups are not verified")
            if not HEX64.fullmatch(upload_fp) or not HEX64.fullmatch(app_fp):
                fail("both signing certificate SHA-256 fingerprints must be frozen for release")
            cutoff = parse_contract_datetime(str(policy.get("certificate_expiry_must_be_after", "")), "certificate cutoff")
            upload_expiry = parse_contract_datetime(str(upload.get("certificate_not_after_utc", "")), "upload certificate expiry")
            app_expiry = parse_contract_datetime(str(play.get("app_signing_certificate_not_after_utc", "")), "app-signing certificate expiry")
            if upload_expiry <= cutoff or app_expiry <= cutoff:
                fail("signing certificate expiry does not exceed required cutoff")
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(str(exc))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Play upload/app-signing identity without persisting private keys.")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--upload-cert", type=Path, default=None, help="Public upload certificate (DER or PEM) exported from the CI keystore.")
    parser.add_argument("--evidence-output", type=Path, default=None)
    args = parser.parse_args()

    try:
        contract = read_object(CONTRACT)
        identity = read_object(IDENTITY)
        artifact = read_object(ARTIFACT)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"RELEASE_SIGNING_IDENTITY FAIL: {exc}")
        return 1

    errors = validate_static(contract, identity, artifact, args.release)
    cert_info: dict[str, Any] | None = None
    if args.upload_cert is not None:
        try:
            cert_info = inspect_public_certificate(args.upload_cert)
            upload = contract["upload_key"]
            expected = normalized_fingerprint(upload.get("certificate_sha256", ""))
            if args.release and not HEX64.fullmatch(expected):
                fail("release contract does not contain a frozen upload certificate SHA-256")
            if HEX64.fullmatch(expected) and cert_info["sha256"] != expected:
                fail("CI upload certificate SHA-256 does not match the frozen release identity")
            if cert_info["algorithm"] != str(upload.get("algorithm")):
                fail("CI upload certificate public-key algorithm does not match contract")
            if int(cert_info["key_size_bits"]) < int(upload.get("minimum_key_size_bits", 0)):
                fail("CI upload certificate key size is below the contract minimum")
            if args.release:
                contract_expiry = parse_contract_datetime(str(upload.get("certificate_not_after_utc", "")), "upload certificate expiry")
                actual_expiry = parse_contract_datetime(str(cert_info["not_after_utc"]), "actual upload certificate expiry")
                if actual_expiry != contract_expiry:
                    fail("CI upload certificate expiry does not match frozen contract")
        except (OSError, ValueError, subprocess.CalledProcessError) as exc:
            errors.append(str(exc))
    elif args.release:
        errors.append("--release requires --upload-cert public certificate evidence")

    evidence = {
        "schema_version": 1,
        "application_id": contract.get("application_id"),
        "release_mode": args.release,
        "upload_certificate": cert_info,
        "expected_upload_certificate_sha256": normalized_fingerprint(contract.get("upload_key", {}).get("certificate_sha256", "")),
        "expected_play_app_signing_certificate_sha256": normalized_fingerprint(contract.get("play_app_signing", {}).get("app_signing_certificate_sha256", "")),
        "private_key_material_recorded": false,
        "errors": errors,
    }
    if args.evidence_output is not None:
        args.evidence_output.parent.mkdir(parents=True, exist_ok=True)
        args.evidence_output.write_text(json.dumps(evidence, indent=2, ensure_ascii=False), encoding="utf-8")

    if errors:
        print(f"RELEASE_SIGNING_IDENTITY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("RELEASE_SIGNING_IDENTITY PASS: upload/app-signing identities separated; private-key evidence forbidden")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
