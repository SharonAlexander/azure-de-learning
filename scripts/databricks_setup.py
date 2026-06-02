"""
databricks_setup.py
Sets up Unity Catalog objects in Azure Databricks after workspace is provisioned.

Requirements:
    pip install requests
    Databricks CLI installed (winget install Databricks.DatabricksCLI)

Usage:
    python databricks_setup.py \
        --workspace-url https://adb-xxxx.azuredatabricks.net \
        --token dapi-xxxx \
        --storage-account sadelearnnew0001 \
        --access-connector-id /subscriptions/xxxx/resourceGroups/rg-delearn-dev/providers/Microsoft.Databricks/accessConnectors/ac-delearn-dev
"""

import argparse
import subprocess
import json
import time
import sys
import os
import requests
from typing import Optional, Dict, Any


# ── Argument parsing ─────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Databricks Unity Catalog setup script")
    p.add_argument("--workspace-url",        required=True,
                   help="e.g. https://adb-7405605289508865.5.azuredatabricks.net")
    p.add_argument("--token",                required=True,
                   help="Databricks Personal Access Token (dapi-xxxx)")
    p.add_argument("--storage-account",      required=True,
                   help="ADLS Gen2 storage account name")
    p.add_argument("--access-connector-id",  required=True,
                   help="Full Azure resource ID of Access Connector")
    return p.parse_args()


# ── Preflight checks ─────────────────────────────────────────────────────────

def check_prerequisites(workspace_url: str, token: str) -> None:
    """Verify CLI is installed and workspace is reachable before doing anything"""
    print("\n[0] Preflight checks")

    # Check Databricks CLI is installed
    result = subprocess.run(
        ["databricks", "--version"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("    ✗ Databricks CLI not found")
        print("      Install with: winget install Databricks.DatabricksCLI")
        print("      Or: pip install databricks-cli")
        sys.exit(1)
    cli_version = result.stdout.strip()
    print(f"    ✓ Databricks CLI found: {cli_version}")

    # Check workspace is reachable with the token
    try:
        r = requests.get(
            f"{workspace_url.rstrip('/')}/api/2.0/clusters/spark-versions",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        )
        if r.status_code == 200:
            print(f"    ✓ Workspace reachable: {workspace_url}")
        elif r.status_code == 401:
            print("    ✗ Token is invalid or expired — generate a new PAT")
            sys.exit(1)
        else:
            print(f"    ✗ Unexpected response {r.status_code} from workspace")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print(f"    ✗ Cannot reach workspace: {workspace_url}")
        sys.exit(1)


# ── CLI configuration ────────────────────────────────────────────────────────

def configure_cli(workspace_url: str, token: str) -> None:
    """
    Write DEFAULT profile to ~/.databrickscfg
    Preserves any existing non-DEFAULT profiles.
    """
    config_path = os.path.expanduser("~/.databrickscfg")
    new_default = f"[DEFAULT]\nhost  = {workspace_url.rstrip('/')}\ntoken = {token}\n"

    # Read existing config if present — preserve non-DEFAULT profiles
    existing_lines = []
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            existing_lines = f.readlines()

    # Remove existing DEFAULT block, keep everything else
    filtered = []
    in_default = False
    for line in existing_lines:
        if line.strip() == "[DEFAULT]":
            in_default = True
            continue
        if in_default and line.startswith("["):
            in_default = False
        if not in_default:
            filtered.append(line)

    with open(config_path, "w") as f:
        f.write(new_default + "\n")
        f.writelines(filtered)

    print(f"    ✓ CLI configured — DEFAULT profile set to {workspace_url}")


# ── CLI runner ───────────────────────────────────────────────────────────────

def run_cli(cmd: list, ignore_exists: bool = True) -> Optional[Dict]:
    """
    Run a Databricks CLI command.
    Returns parsed JSON output or None.
    Raises RuntimeError on unexpected failures.
    """
    full_cmd = cmd + ["--output", "json"]
    result = subprocess.run(full_cmd, capture_output=True, text=True)

    if result.returncode != 0:
        err = (result.stderr or result.stdout or "").strip()
        if ignore_exists and "already exists" in err.lower():
            print(f"    ✓ Already exists — skipping")
            return None
        print(f"    ✗ CLI error ({' '.join(cmd)}):")
        print(f"      {err}")
        raise RuntimeError(err)

    output = result.stdout.strip()
    if output:
        try:
            return json.loads(output)
        except json.JSONDecodeError:
            return {"raw": output}
    return None


# ── REST client ──────────────────────────────────────────────────────────────

class DatabricksRestClient:
    """
    Thin REST client for endpoints that don't require ARM management token
    (SQL warehouses, Unity Catalog SQL execution).
    Storage credentials and external locations use CLI instead.
    """

    def __init__(self, workspace_url: str, token: str):
        self.base    = workspace_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type":  "application/json"
        }

    def get(self, path: str) -> Dict:
        r = requests.get(f"{self.base}{path}", headers=self.headers, timeout=30)
        r.raise_for_status()
        return r.json()

    def post(self, path: str, payload: Dict) -> Dict:
        r = requests.post(
            f"{self.base}{path}",
            headers=self.headers,
            json=payload,
            timeout=30
        )
        if r.status_code not in (200, 201):
            raise RuntimeError(f"POST {path} failed {r.status_code}: {r.text}")
        return r.json()

    def execute_sql(self, warehouse_id: str, statement: str) -> Dict:
        """Execute a SQL statement via Statement Execution API"""
        return self.post("/api/2.0/sql/statements", {
            "warehouse_id": warehouse_id,
            "statement":    statement,
            "wait_timeout": "30s",
            "on_wait_timeout": "CONTINUE"   # don't error if 30s exceeded — poll instead
        })

    def wait_for_statement(self, statement_id: str, timeout_secs: int = 120) -> Dict:
        """Poll statement until terminal state"""
        for _ in range(timeout_secs):
            result = self.get(f"/api/2.0/sql/statements/{statement_id}")
            state  = result.get("status", {}).get("state", "")
            if state in ("SUCCEEDED", "FAILED", "CANCELED", "CLOSED"):
                return result
            time.sleep(1)
        raise TimeoutError(f"Statement {statement_id} did not finish within {timeout_secs}s")


# ── Step 1: Storage Credential ───────────────────────────────────────────────

def step1_create_storage_credential(access_connector_id: str) -> str:
    """
    Correct CLI syntax:
        databricks storage-credentials create NAME --json '{"azure_managed_identity": {...}}'
    NAME is a positional argument — NOT inside --json.
    """
    credential_name = "sc_adls_medallion"
    print(f"\n[1] Creating storage credential: {credential_name}")

    # azure_managed_identity goes in --json, NOT the name
    json_payload = json.dumps({
        "azure_managed_identity": {
            "access_connector_id": access_connector_id
        }
    })

    result = run_cli([
        "databricks", "storage-credentials", "create",
        credential_name,                  # positional NAME argument
        "--json", json_payload,           # additional fields only
        "--skip-validation"               # validate separately in step 3
    ])

    if result:
        print(f"    ✓ Created: {result.get('name', credential_name)}")
    return credential_name


# ── Step 2: External Location ────────────────────────────────────────────────

def step2_create_external_location(storage_account: str, credential_name: str) -> None:
    """
    Correct CLI syntax:
        databricks external-locations create NAME URL CREDENTIAL_NAME [flags]
    All three are positional arguments — NOT inside --json.
    """
    location_name = "el_medallion"
    url           = f"abfss://medallion@{storage_account}.dfs.core.windows.net/"

    print(f"\n[2] Creating external location: {location_name}")
    print(f"    URL: {url}")

    result = run_cli([
        "databricks", "external-locations", "create",
        location_name,                    # positional NAME
        url,                              # positional URL
        credential_name,                  # positional CREDENTIAL_NAME
        "--comment", "Medallion lakehouse container on ADLS Gen2"
    ])

    if result:
        print(f"    ✓ Created: {result.get('name', location_name)}")


# ── Step 3: Validate External Location ──────────────────────────────────────

def step3_validate_external_location(storage_account: str) -> None:
    """
    Correct CLI syntax:
        databricks storage-credentials validate
            --storage-credential-name NAME
            --url URL
    """
    print("\n[3] Validating external location")
    url = f"abfss://medallion@{storage_account}.dfs.core.windows.net/"

    result = run_cli([
        "databricks", "storage-credentials", "validate",
        "--storage-credential-name", "sc_adls_medallion",
        "--url", url
    ], ignore_exists=False)

    if result:
        for r in result.get("results", []):
            operation = r.get("operation", "UNKNOWN")
            passed    = r.get("result") == "PASS"
            icon      = "✓" if passed else "✗"

            # File Events failures are expected without extra roles — not a blocker
            if not passed and "FILE_EVENTS" in operation:
                print(f"    ⚠  {operation}: FAIL (optional — needs EventGrid roles, skip for now)")
            else:
                print(f"    {icon} {operation}: {'PASS' if passed else 'FAIL'}")


# ── Step 4: SQL Warehouse ────────────────────────────────────────────────────

def step4_create_sql_warehouse(client: DatabricksRestClient) -> str:
    """
    Create a serverless SQL warehouse for Unity Catalog DDL.
    Serverless starts instantly — no cluster to provision, no vCPU quota needed.
    Requirements already met: Premium workspace + Unity Catalog enabled.
    """
    print("\n[4] Creating serverless SQL warehouse for Unity Catalog DDL")

    payload = {
        "name":                     "setup-warehouse",
        "cluster_size":              "2X-Small",
        "warehouse_type":           "PRO",       # must be PRO for serverless
        "enable_serverless_compute": True,        # this is what makes it serverless
        "auto_stop_mins":           10,
        "min_num_clusters":         1,
        "max_num_clusters":         1,
        "enable_photon":            False
    }

    result = client.post("/api/2.0/sql/warehouses", payload)
    wh_id  = result.get("id")

    if not wh_id:
        raise RuntimeError(f"Warehouse creation failed — no ID in response: {result}")

    print(f"    Warehouse ID: {wh_id}")
    print("    Waiting for RUNNING state (serverless starts in ~10-15 seconds)...")

    for attempt in range(30):   # serverless is fast — 30 attempts × 3s = 90s max
        wh    = client.get(f"/api/2.0/sql/warehouses/{wh_id}")
        state = wh.get("state", "")
        if state == "RUNNING":
            print("    ✓ Serverless warehouse running")
            return wh_id
        if state in ("DELETED", "DELETING"):
            raise RuntimeError(f"Warehouse entered unexpected state: {state}")
        print(f"    ... state: {state}")
        time.sleep(3)

    raise TimeoutError("Serverless warehouse did not reach RUNNING state within 90s")


# ── Step 5: Unity Catalog Setup ──────────────────────────────────────────────

def step5_setup_unity_catalog(
    client:       DatabricksRestClient,
    warehouse_id: str,
    storage_account: str
) -> None:
    """
    Create catalog and schemas via SQL.
    Notes:
    - ALTER CATALOG SET LOCATION is removed — causes error if catalog already has location
    - Backtick-wrapped group names replaced with double-quoted to avoid Python escaping issues
    - Each statement is idempotent (IF NOT EXISTS)
    """
    print("\n[5] Setting up Unity Catalog — catalog and schemas")

    statements = [
        ("CREATE CATALOG IF NOT EXISTS de_learning COMMENT 'DE learning project catalog'",
         "Create catalog de_learning"),

        ("CREATE SCHEMA IF NOT EXISTS de_learning.bronze COMMENT 'Raw ingested data'",
         "Create schema: bronze"),

        ("CREATE SCHEMA IF NOT EXISTS de_learning.silver COMMENT 'Cleaned and validated data'",
         "Create schema: silver"),

        ("CREATE SCHEMA IF NOT EXISTS de_learning.gold COMMENT 'Business-ready aggregated data'",
         "Create schema: gold"),
    ]

    for sql, description in statements:
        print(f"    → {description}")
        try:
            result     = client.execute_sql(warehouse_id, sql)
            stmt_id    = result.get("statement_id")
            init_state = result.get("status", {}).get("state", "")

            if init_state == "SUCCEEDED":
                # Completed within the wait_timeout
                print("      ✓ Done")
                continue

            if stmt_id:
                final = client.wait_for_statement(stmt_id)
                state = final.get("status", {}).get("state", "")
                if state == "SUCCEEDED":
                    print("      ✓ Done")
                else:
                    err_msg = (
                        final.get("status", {})
                             .get("error", {})
                             .get("message", "unknown error")
                    )
                    if "already exists" in err_msg.lower():
                        print("      ✓ Already exists — skipping")
                    else:
                        print(f"      ✗ Failed: {err_msg}")
            else:
                print(f"      ✗ No statement_id in response: {result}")

        except RuntimeError as e:
            err = str(e).lower()
            if "already exists" in err:
                print("      ✓ Already exists — skipping")
            else:
                print(f"      ✗ Unexpected error: {e}")
                raise


# ── Step 6: Stop SQL Warehouse ───────────────────────────────────────────────

def step6_stop_warehouse(client: DatabricksRestClient, warehouse_id: str) -> None:
    print(f"\n[6] Stopping SQL warehouse: {warehouse_id}")
    try:
        client.post(f"/api/2.0/sql/warehouses/{warehouse_id}/stop", {})
        print("    ✓ Stop request sent — warehouse will stop within ~1 min")
    except RuntimeError as e:
        # Already stopped is not an error
        print(f"    ⚠  Stop request returned: {e} (may already be stopping)")


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    workspace_url    = args.workspace_url.rstrip("/")
    token            = args.token
    storage_account  = args.storage_account
    access_connector = args.access_connector_id

    print("=" * 55)
    print("  Databricks Unity Catalog Setup")
    print(f"  Workspace:       {workspace_url}")
    print(f"  Storage Account: {storage_account}")
    print("=" * 55)

    # Step 0 — Preflight
    check_prerequisites(workspace_url, token)

    # Configure CLI
    print("\n  Configuring Databricks CLI...")
    configure_cli(workspace_url, token)

    # Steps 1-3 use CLI (avoids ARM management token requirement)
    credential_name = step1_create_storage_credential(access_connector)
    step2_create_external_location(storage_account, credential_name)
    step3_validate_external_location(storage_account)

    # Steps 4-6 use REST API (no ARM token needed for warehouse/catalog APIs)
    client       = DatabricksRestClient(workspace_url, token)
    warehouse_id = step4_create_sql_warehouse(client)
    step5_setup_unity_catalog(client, warehouse_id, storage_account)
    step6_stop_warehouse(client, warehouse_id)

    print("\n" + "=" * 55)
    print("  ✓ Databricks setup complete")
    print()
    print("  Next steps:")
    print("  1. Open Databricks workspace → Catalog")
    print("     Verify: sc_adls_medallion credential exists")
    print("     Verify: el_medallion external location exists")
    print("     Verify: de_learning catalog with bronze/silver/gold schemas")
    print()
    print("  2. Run: scripts/synapse_setup.sql")
    print("     Against your Synapse serverless endpoint")
    print("=" * 55)


if __name__ == "__main__":
    main()