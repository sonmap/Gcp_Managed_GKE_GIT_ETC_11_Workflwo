import json
import os
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="GCS transfer PoC", version="1.0.0")


class TransferRequest(BaseModel):
    source_bucket: str = Field(min_length=3)
    source_object: str = Field(min_length=1)
    target_bucket: str = Field(min_length=3)
    target_object: str | None = None
    result_prefix: str = "result"
    execution_id: str | None = None


def run_command(args: list[str], timeout: int = 240) -> dict:
    proc = subprocess.run(
        args,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    return {
        "command": args,
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.post("/transfer")
def transfer(req: TransferRequest) -> dict:
    execution_id = req.execution_id or str(uuid.uuid4())
    target_object = req.target_object or f"output/{Path(req.source_object).name}"

    source_uri = f"gs://{req.source_bucket}/{req.source_object}"
    target_uri = f"gs://{req.target_bucket}/{target_object}"
    result_uri = f"gs://{req.target_bucket}/{req.result_prefix}/{execution_id}.json"

    started_at = datetime.now(timezone.utc).isoformat()

    source_ls = run_command(
        ["gcloud", "storage", "ls", "--long", source_uri, "--format=json"]
    )
    if source_ls["returncode"] != 0:
        raise HTTPException(
            status_code=404,
            detail={
                "message": "Source object lookup failed",
                "source": source_uri,
                "gcloud": source_ls,
            },
        )

    copy_result = run_command(
        ["gcloud", "storage", "cp", source_uri, target_uri, "--quiet"]
    )
    if copy_result["returncode"] != 0:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "GCS copy failed",
                "source": source_uri,
                "target": target_uri,
                "gcloud": copy_result,
            },
        )

    target_ls = run_command(
        ["gcloud", "storage", "ls", "--long", target_uri, "--format=json"]
    )

    result = {
        "execution_id": execution_id,
        "started_at": started_at,
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "cloud_run_revision": os.getenv("K_REVISION"),
        "source_uri": source_uri,
        "target_uri": target_uri,
        "result_uri": result_uri,
        "source_ls": source_ls,
        "copy": copy_result,
        "target_ls": target_ls,
    }

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as fp:
        json.dump(result, fp, ensure_ascii=False, indent=2)
        result_file = fp.name

    try:
        result_upload = run_command(
            ["gcloud", "storage", "cp", result_file, result_uri, "--quiet"]
        )
    finally:
        Path(result_file).unlink(missing_ok=True)

    result["result_upload"] = result_upload

    if result_upload["returncode"] != 0:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Result JSON upload failed",
                "result_uri": result_uri,
                "gcloud": result_upload,
                "transfer_result": result,
            },
        )

    return result
