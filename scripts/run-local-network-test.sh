#!/usr/bin/env bash
set -euo pipefail

SERVICE_TYPE="_beamdrop._tcp"
HOST=""
PORT="49320"
RUN_SERVICE_SCAN="false"
TIMEOUT_SECONDS="5"

usage() {
  cat <<USAGE
Usage: scripts/run-local-network-test.sh [--service] [--host HOST] [--port PORT] [--timeout SECONDS]

Checks local BeamDrop network prerequisites for manual QA:
  --service          Try to browse for ${SERVICE_TYPE} using dns-sd or avahi-browse.
  --host HOST       Peer host/IP to test with TCP reachability.
  --port PORT       Peer port to test. Default: 49320.
  --timeout N       Timeout in seconds. Default: 5.

This script does not perform a BeamDrop transfer and does not validate trust,
encryption, or file hashes. Use it only as a network diagnostics aid.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)
      RUN_SERVICE_SCAN="true"
      shift
      ;;
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "BeamDrop local network diagnostic"
echo "Service: ${SERVICE_TYPE}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ "$RUN_SERVICE_SCAN" == "true" ]]; then
  echo
  echo "Discovery scan:"
  if command -v dns-sd >/dev/null 2>&1; then
    echo "Using dns-sd for ${TIMEOUT_SECONDS}s..."
    if command -v timeout >/dev/null 2>&1; then
      timeout "${TIMEOUT_SECONDS}" dns-sd -B "${SERVICE_TYPE}" local || true
    else
      dns-sd -B "${SERVICE_TYPE}" local &
      scan_pid=$!
      sleep "${TIMEOUT_SECONDS}"
      kill "${scan_pid}" >/dev/null 2>&1 || true
      wait "${scan_pid}" >/dev/null 2>&1 || true
    fi
  elif command -v avahi-browse >/dev/null 2>&1; then
    echo "Using avahi-browse for ${TIMEOUT_SECONDS}s..."
    if command -v timeout >/dev/null 2>&1; then
      timeout "${TIMEOUT_SECONDS}" avahi-browse -rt "${SERVICE_TYPE}" || true
    else
      avahi-browse -rt "${SERVICE_TYPE}" &
      scan_pid=$!
      sleep "${TIMEOUT_SECONDS}"
      kill "${scan_pid}" >/dev/null 2>&1 || true
      wait "${scan_pid}" >/dev/null 2>&1 || true
    fi
  else
    echo "No dns-sd or avahi-browse command found. Discovery scan skipped."
  fi
fi

if [[ -n "$HOST" ]]; then
  echo
  echo "TCP reachability:"
  echo "Target: ${HOST}:${PORT}"
  if command -v nc >/dev/null 2>&1; then
    if nc -vz -w "${TIMEOUT_SECONDS}" "$HOST" "$PORT"; then
      echo "Reachability: PASS"
    else
      echo "Reachability: FAIL"
      exit 1
    fi
  else
    echo "nc command not found. TCP reachability check skipped."
  fi
else
  echo
  echo "No --host provided; TCP reachability check skipped."
fi

echo
echo "Result: diagnostics complete. Pairing/trust/transfer still require app E2E QA."
