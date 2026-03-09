"""
blockchain.py — Blockchain Evidence API Endpoints
===================================================
POST /report   — File evidence (IPFS + SHA256 + save to SQLite)
POST /anchor   — Batch-anchor pending evidence to Polygon (Merkle tree)
GET  /reports  — List all evidence records
GET  /report/N — Single evidence with Merkle proof
GET  /verify/N — Verify evidence against on-chain Merkle root
GET  /status   — Blockchain configuration status
"""

import logging
from fastapi import APIRouter, UploadFile, File, Form, HTTPException

from api.blockchain.config import is_blockchain_configured, is_ipfs_configured, get_blockchain_info, get_effective_confidence
from api.blockchain.ipfs_service import upload_to_ipfs, compute_file_hash, get_ipfs_gateway_url, is_real_ipfs_cid
from api.blockchain.merkle_service import build_merkle_tree, verify_proof
from api.blockchain.chain_service import store_batch_root, get_batch, get_batch_count, get_explorer_url
from api.blockchain.evidence_store import (
    add_evidence, get_evidence, get_all_evidence,
    get_pending_evidence, mark_batch_anchored, get_evidence_count,
)

logger = logging.getLogger("riskguard.blockchain.api")
router = APIRouter()


# ══════════════════════════════════════════════════════════════════════════════
# POST /report — File a new evidence report
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/report")
async def file_report(
    file: UploadFile = File(...),
    profile_url: str = Form(default=""),
    threat_type: str = Form(default="Deepfake"),
    ai_result: str = Form(default="AI-Generated"),
    confidence: float = Form(default=0.0),
):
    """
    File a new evidence report.
    1. Compute SHA256 of the file
    2. Upload to IPFS via Pinata
    3. Save to local SQLite evidence DB
    Returns evidence record with IPFS CID and file hash.
    """
    # Read file bytes
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file")

    if len(file_bytes) > 15 * 1024 * 1024:  # 15MB limit
        raise HTTPException(status_code=413, detail="File too large (max 15MB)")

    # Step 1: SHA256 hash
    file_hash = compute_file_hash(file_bytes)
    logger.info(f"[REPORT] SHA256: {file_hash[:16]}... | File: {file.filename}")

    # Step 2: Upload to IPFS
    ipfs_cid = ""
    ipfs_url = ""
    if is_ipfs_configured():
        try:
            ipfs_result = await upload_to_ipfs(file_bytes, filename=file.filename or "evidence.bin")
            ipfs_cid = ipfs_result["ipfs_cid"]
            ipfs_url = ipfs_result["ipfs_url"]
        except Exception as e:
            logger.error(f"[REPORT] IPFS upload failed (continuing without): {e}")
            ipfs_cid = f"ipfs_unavailable_{file_hash[:16]}"
            ipfs_url = ""
    else:
        ipfs_cid = f"ipfs_not_configured_{file_hash[:16]}"
        logger.warning("[REPORT] IPFS not configured — storing hash only")

    # Step 3: Save to SQLite (apply confidence override)
    effective_confidence = get_effective_confidence(confidence)
    evidence = add_evidence(
        ipfs_cid=ipfs_cid,
        file_hash=file_hash,
        ai_result=ai_result,
        confidence=effective_confidence,
        profile_url=profile_url,
        threat_type=threat_type,
        filename=file.filename or "evidence.bin",
    )

    return {
        "success": True,
        "evidence": evidence,
        "ipfs_url": ipfs_url,
        "message": "Evidence filed successfully. Use /anchor to batch-anchor to blockchain.",
    }


# ══════════════════════════════════════════════════════════════════════════════
# POST /test-report — Quick test endpoint (Swagger-friendly, no file upload)
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/test-report")
async def test_report(
    threat_type: str = "Deepfake",
    ai_result: str = "AI-Generated",
    confidence: float = 0.0,
    profile_url: str = "",
    filename: str = "swagger_test.png",
):
    """
    🧪 TEST ENDPOINT — Swagger-friendly, no file upload needed.
    Creates a fake evidence record with a random SHA256 hash.
    Use this to test the full chain: report → anchor → dashboard.
    """
    import hashlib, time

    # Generate a fake file hash (deterministic for the same inputs)
    fake_content = f"{threat_type}:{ai_result}:{filename}:{time.time()}".encode()
    file_hash = hashlib.sha256(fake_content).hexdigest()

    effective_confidence = get_effective_confidence(confidence)

    evidence = add_evidence(
        ipfs_cid=f"test_QmFake{file_hash[:12]}",
        file_hash=file_hash,
        ai_result=ai_result,
        confidence=effective_confidence,
        profile_url=profile_url,
        threat_type=threat_type,
        filename=filename,
    )

    return {
        "success": True,
        "evidence": evidence,
        "message": "🧪 Test evidence created. Use /anchor to anchor to blockchain.",
    }


# ══════════════════════════════════════════════════════════════════════════════
# POST /anchor — Batch-anchor pending evidence to Polygon
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/anchor")
async def anchor_evidence():
    """
    Batch-anchor all pending evidence to the Polygon blockchain.
    1. Get all un-anchored evidence
    2. Build Merkle tree from their SHA256 hashes
    3. Call storeBatchRoot() on the smart contract
    4. Save Merkle proofs back to each evidence record
    """
    if not is_blockchain_configured():
        raise HTTPException(status_code=503, detail="Blockchain not configured. Check .env")

    # Get pending evidence
    pending = get_pending_evidence()
    if not pending:
        return {"success": True, "message": "No pending evidence to anchor", "anchored": 0}

    # Build Merkle tree from file hashes
    hashes = [e["file_hash"] for e in pending]
    ids = [e["id"] for e in pending]

    tree = build_merkle_tree(hashes)
    merkle_root = tree.root
    merkle_root_bytes = tree.root_bytes32

    logger.info(f"[ANCHOR] Anchoring {len(pending)} evidence records | Root: {merkle_root[:16]}...")

    # Store on blockchain
    try:
        chain_result = await store_batch_root(merkle_root_bytes, len(pending))
    except Exception as e:
        logger.error(f"[ANCHOR] Blockchain transaction failed: {e}")
        raise HTTPException(status_code=502, detail=f"Blockchain transaction failed: {e}")

    # Generate Merkle proofs for each evidence
    proofs = {}
    for i, eid in enumerate(ids):
        proof = tree.get_proof(hashes[i])
        proofs[eid] = proof

    # Update local DB
    mark_batch_anchored(
        evidence_ids=ids,
        batch_id=chain_result["batch_id"],
        merkle_root=merkle_root,
        tx_hash=chain_result["tx_hash"],
        proofs=proofs,
    )

    return {
        "success": True,
        "batch_id": chain_result["batch_id"],
        "tx_hash": chain_result["tx_hash"],
        "explorer_url": get_explorer_url(chain_result["tx_hash"]),
        "merkle_root": "0x" + merkle_root,
        "evidence_count": len(pending),
        "block_number": chain_result.get("block_number"),
        "gas_used": chain_result.get("gas_used"),
        "status": chain_result.get("status", "pending"),
    }


# ══════════════════════════════════════════════════════════════════════════════
# GET /reports — List all evidence records
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/reports")
async def list_reports():
    """List all evidence records with summary counts."""
    evidence_list = get_all_evidence()
    counts = get_evidence_count()
    return {
        "evidence": evidence_list,
        "counts": counts,
    }


# ══════════════════════════════════════════════════════════════════════════════
# GET /report/{id} — Single evidence with Merkle proof
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/report/{evidence_id}")
async def get_report(evidence_id: int):
    """Get a single evidence record with its Merkle proof."""
    evidence = get_evidence(evidence_id)
    if evidence is None:
        raise HTTPException(status_code=404, detail=f"Evidence #{evidence_id} not found")

    result = {"evidence": evidence}
    if evidence.get("ipfs_cid") and is_real_ipfs_cid(evidence["ipfs_cid"]):
        result["ipfs_url"] = get_ipfs_gateway_url(evidence["ipfs_cid"])
    if evidence.get("tx_hash"):
        result["explorer_url"] = get_explorer_url(evidence["tx_hash"])
    return result


# ══════════════════════════════════════════════════════════════════════════════
# GET /verify/{id} — Verify evidence against on-chain Merkle root
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/verify/{evidence_id}")
async def verify_evidence(evidence_id: int):
    """
    Verify an evidence record against its on-chain Merkle root.
    1. Get the evidence + Merkle proof from local DB
    2. Get the Merkle root from the blockchain
    3. Verify the proof
    """
    evidence = get_evidence(evidence_id)
    if evidence is None:
        raise HTTPException(status_code=404, detail=f"Evidence #{evidence_id} not found")

    if not evidence.get("anchored"):
        return {
            "verified": False,
            "reason": "Evidence has not been anchored to blockchain yet",
            "evidence_id": evidence_id,
        }

    if not is_blockchain_configured():
        # Offline verification using stored Merkle root
        if evidence.get("merkle_proof") and evidence.get("merkle_root"):
            is_valid = verify_proof(
                leaf_hash=evidence["file_hash"],
                proof=evidence["merkle_proof"],
                expected_root=evidence["merkle_root"],
            )
            return {
                "verified": is_valid,
                "method": "offline_merkle_proof",
                "evidence_id": evidence_id,
                "file_hash": evidence["file_hash"],
                "merkle_root": evidence["merkle_root"],
            }
        return {"verified": False, "reason": "Blockchain not configured and no stored proof"}

    # On-chain verification
    try:
        batch = await get_batch(evidence["batch_id"])
        on_chain_root = batch["merkle_root"]

        # Normalize: strip "0x" prefix from both sides for comparison
        local_root = evidence["merkle_root"].removeprefix("0x")
        chain_root = on_chain_root.removeprefix("0x")
        roots_match = local_root == chain_root

        # Verify Merkle proof
        # For single-item batches, proof is [] (empty list) — still valid
        proof = evidence.get("merkle_proof")
        if proof is not None:
            proof_valid = verify_proof(
                leaf_hash=evidence["file_hash"],
                proof=proof,
                expected_root=local_root,
            )
        else:
            proof_valid = False

        return {
            "verified": roots_match and proof_valid,
            "method": "on_chain_verification",
            "evidence_id": evidence_id,
            "file_hash": evidence["file_hash"],
            "merkle_root_local": "0x" + local_root,
            "merkle_root_chain": "0x" + chain_root,
            "roots_match": roots_match,
            "proof_valid": proof_valid,
            "batch_id": evidence["batch_id"],
            "tx_hash": evidence.get("tx_hash"),
            "explorer_url": get_explorer_url(evidence["tx_hash"]) if evidence.get("tx_hash") else None,
            "blockchain_timestamp": batch.get("timestamp"),
        }
    except Exception as e:
        logger.error(f"[VERIFY] On-chain verification failed: {e}")
        return {
            "verified": False,
            "reason": f"On-chain verification failed: {e}",
            "evidence_id": evidence_id,
        }


# ══════════════════════════════════════════════════════════════════════════════
# GET /status — Blockchain status
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/status")
async def blockchain_status():
    """Get blockchain configuration and evidence status."""
    info = get_blockchain_info()
    counts = get_evidence_count()

    batch_count = 0
    if is_blockchain_configured():
        try:
            batch_count = await get_batch_count()
        except Exception:
            pass

    return {
        **info,
        "evidence_counts": counts,
        "on_chain_batches": batch_count,
    }
