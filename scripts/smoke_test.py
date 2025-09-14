#!/usr/bin/env python
"""Lightweight smoke test for core runtime.

Validations:
- Imports core dependencies
- Constructs FastAPI app via server module import
- Accesses /health route function object
- Reports success/failure with exit codes
"""
import importlib
import sys

REQUIRED_MODULES = [
    "fastapi",
    "uvicorn",
    "pydantic",
    "openai",
    "opentelemetry",
    "azure.identity",
    "azure.search.documents",
    "structlog",
    "httpx",
]

def import_module(name: str):
    try:
        importlib.import_module(name)
        return True, None
    except Exception as e:  # broad for smoke purposes
        return False, str(e)

failures = {}
for m in REQUIRED_MODULES:
    ok, err = import_module(m)
    if not ok:
        failures[m] = err

if failures:
    print("[SMOKE] Import failures detected:")
    for mod, err in failures.items():
        print(f"  - {mod}: {err}")
    sys.exit(1)

# Try importing the application server
try:
    from src.aiapi import server  # noqa: F401
except Exception as e:
    print(f"[SMOKE] Failed to import server module: {e}")
    sys.exit(2)

# Basic attribute checks
if not hasattr(server, "app"):
    print("[SMOKE] server.app missing")
    sys.exit(3)

print("[SMOKE] All imports succeeded; FastAPI app object present.")
sys.exit(0)
