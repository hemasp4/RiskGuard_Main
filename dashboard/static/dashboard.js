/**
 * dashboard.js — Cybercrime Investigation Dashboard
 * Real-time evidence updates via SSE + verification & anchoring.
 */

// ══════════════════════════════════════════════════════════════════════════════
// SERVER-SENT EVENTS — Real-time evidence notifications
// ══════════════════════════════════════════════════════════════════════════════

let eventSource = null;
let lastUpdateTime = null;

function connectSSE() {
    if (eventSource) eventSource.close();

    eventSource = new EventSource('/events');

    eventSource.addEventListener('evidence_update', function (e) {
        try {
            const data = JSON.parse(e.data);
            console.log('[SSE] New evidence update:', data);

            // Show notification toast
            showNotification(
                `🚨 New Evidence Report!`,
                `${data.counts.total} total • ${data.counts.pending} pending anchor`
            );

            // Auto-refresh the evidence table
            refreshEvidenceTable();

            lastUpdateTime = new Date();
        } catch (err) {
            console.error('[SSE] Parse error:', err);
        }
    });

    eventSource.onerror = function () {
        console.log('[SSE] Connection lost, reconnecting in 5s...');
        eventSource.close();
        setTimeout(connectSSE, 5000);
    };

    eventSource.onopen = function () {
        console.log('[SSE] ✅ Connected — listening for live evidence updates');
    };
}

// Start SSE on page load
if (document.querySelector('.dashboard-main')) {
    connectSSE();
}


// ══════════════════════════════════════════════════════════════════════════════
// LIVE TABLE REFRESH (no full page reload)
// ══════════════════════════════════════════════════════════════════════════════

async function refreshEvidenceTable() {
    try {
        const resp = await fetch('/api/reports');
        const data = await resp.json();

        if (data.evidence) {
            updateStatsBar(data.counts);
            updateEvidenceTable(data.evidence);
        }
    } catch (err) {
        console.error('[REFRESH] Error:', err);
    }
}

function updateStatsBar(counts) {
    const statValues = document.querySelectorAll('.stat-value');
    if (statValues.length >= 4) {
        statValues[0].textContent = counts.total || 0;
        statValues[1].textContent = counts.anchored || 0;
        statValues[2].textContent = counts.pending || 0;
    }

    // Update anchor button
    const anchorBtn = document.getElementById('anchorBtn');
    if (counts.pending > 0) {
        if (!anchorBtn) {
            // Reload to show anchor button
            location.reload();
        } else {
            anchorBtn.textContent = `⛓️ Anchor ${counts.pending} Pending to Blockchain`;
        }
    }
}

function updateEvidenceTable(evidence) {
    const tbody = document.querySelector('.evidence-table tbody');
    if (!tbody) {
        // No table yet (was empty state) — reload
        if (evidence.length > 0) location.reload();
        return;
    }

    // Get current IDs
    const existingIds = new Set();
    tbody.querySelectorAll('tr').forEach(row => {
        const idCell = row.querySelector('.mono');
        if (idCell) existingIds.add(idCell.textContent.trim());
    });

    // Check for new evidence
    let hasNew = false;
    evidence.forEach(e => {
        if (!existingIds.has(`#${e.id}`)) {
            hasNew = true;
        }
    });

    if (hasNew) {
        // Rebuild table for simplicity (flash new rows)
        tbody.innerHTML = '';
        evidence.forEach(e => {
            const isNew = !existingIds.has(`#${e.id}`);
            const row = createEvidenceRow(e, isNew);
            tbody.appendChild(row);
        });
    }
}

function createEvidenceRow(e, isNew) {
    const tr = document.createElement('tr');
    if (isNew) {
        tr.classList.add('row-flash');
    }

    const confidence = Math.round((e.confidence || 0) * 100);
    const ipfsCid = e.ipfs_cid || '';
    const hasRealIpfs = ipfsCid && !ipfsCid.startsWith('ipfs_') && !ipfsCid.startsWith('test_');

    tr.innerHTML = `
        <td class="mono">#${e.id}</td>
        <td class="file-cell" title="${e.filename || ''}">${(e.filename || '').substring(0, 20)}</td>
        <td><span class="badge badge-danger">${e.ai_result || ''}</span></td>
        <td>
            <span class="confidence-bar">
                <span class="confidence-fill" style="width: ${confidence}%"></span>
                <span class="confidence-text">${confidence}%</span>
            </span>
        </td>
        <td>${e.threat_type || ''}</td>
        <td>${hasRealIpfs
            ? `<a href="https://gateway.pinata.cloud/ipfs/${ipfsCid}" target="_blank" class="link-ipfs">📦 ${ipfsCid.substring(0, 8)}...</a>`
            : '<span class="text-muted">—</span>'
        }</td>
        <td>${e.tx_hash
            ? `<a href="https://amoy.polygonscan.com/tx/${e.tx_hash}" target="_blank" class="link-chain">🔗 ${e.tx_hash.substring(0, 10)}...</a>`
            : '<span class="text-muted">—</span>'
        }</td>
        <td>${e.anchored
            ? '<span class="badge badge-verified">✅ Verified</span>'
            : '<span class="badge badge-pending">⏳ Pending</span>'
        }</td>
        <td class="actions-cell">
            <a href="/evidence/${e.id}" class="btn btn-sm btn-outline">View</a>
            ${e.anchored ? `<button class="btn btn-sm btn-verify" onclick="verifyEvidence(${e.id}, this)">Verify</button>` : ''}
        </td>
    `;
    return tr;
}


// ══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION TOAST
// ══════════════════════════════════════════════════════════════════════════════

function showNotification(title, message) {
    // Remove existing
    const existing = document.querySelector('.live-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.className = 'live-toast';
    toast.innerHTML = `
        <div class="toast-icon">🚨</div>
        <div class="toast-content">
            <div class="toast-title">${title}</div>
            <div class="toast-message">${message}</div>
        </div>
        <button class="toast-close" onclick="this.closest('.live-toast').remove()">✕</button>
    `;
    document.body.appendChild(toast);

    // Play notification sound (built-in beep)
    try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.frequency.value = 800;
        gain.gain.value = 0.1;
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.15);
    } catch (_) { }

    // Auto-remove after 8s
    setTimeout(() => toast.remove(), 8000);
}


// ══════════════════════════════════════════════════════════════════════════════
// EVIDENCE VERIFICATION
// ══════════════════════════════════════════════════════════════════════════════

async function verifyEvidence(evidenceId, buttonEl) {
    const originalText = buttonEl.textContent;
    buttonEl.textContent = '⏳ Verifying...';
    buttonEl.disabled = true;

    try {
        const resp = await fetch(`/verify/${evidenceId}`);
        const data = await resp.json();

        let resultDiv = document.getElementById('verifyResult');

        if (data.verified) {
            if (resultDiv) {
                resultDiv.className = 'verify-result verify-success';
                resultDiv.innerHTML = `
                    <strong>✅ Evidence Verified</strong><br>
                    <small>Method: ${data.method || 'on-chain'}</small><br>
                    <small>File Hash: <code>${data.file_hash || ''}</code></small><br>
                    <small>Merkle Root: <code>${(data.merkle_root_chain || data.merkle_root_local || '').substring(0, 20)}...</code></small>
                    ${data.explorer_url ? `<br><a href="${data.explorer_url}" target="_blank" style="color: #FFD700;">View on PolygonScan →</a>` : ''}
                `;
                resultDiv.style.display = 'block';
            }
            buttonEl.textContent = '✅ Verified';
            buttonEl.style.borderColor = '#00E676';
            buttonEl.style.color = '#00E676';
        } else {
            if (resultDiv) {
                resultDiv.className = 'verify-result verify-failed';
                resultDiv.innerHTML = `
                    <strong>❌ Verification Failed</strong><br>
                    <small>${data.reason || 'Merkle proof did not match on-chain root'}</small>
                `;
                resultDiv.style.display = 'block';
            }
            buttonEl.textContent = '❌ Failed';
            buttonEl.style.borderColor = '#FF5252';
            buttonEl.style.color = '#FF5252';
        }
    } catch (err) {
        buttonEl.textContent = '⚠️ Error';
        console.error('Verify error:', err);
    }

    setTimeout(() => {
        buttonEl.textContent = originalText;
        buttonEl.disabled = false;
        buttonEl.style.borderColor = '';
        buttonEl.style.color = '';
    }, 5000);
}


// ══════════════════════════════════════════════════════════════════════════════
// BATCH ANCHORING
// ══════════════════════════════════════════════════════════════════════════════

async function anchorEvidence() {
    const btn = document.getElementById('anchorBtn');
    const resultDiv = document.getElementById('anchorResult');
    const originalText = btn.textContent;

    btn.textContent = '⏳ Anchoring to Polygon...';
    btn.disabled = true;

    try {
        const resp = await fetch('/api/anchor', { method: 'POST' });
        const data = await resp.json();

        if (data.success) {
            resultDiv.className = 'alert alert-success';
            resultDiv.innerHTML = `
                <strong>✅ Batch Anchored to Polygon!</strong><br>
                Batch ID: <strong>${data.batch_id}</strong> | 
                Evidence: <strong>${data.evidence_count}</strong> records |
                Gas Used: <strong>${data.gas_used || 'pending'}</strong><br>
                TX: <a href="${data.explorer_url}" target="_blank" style="color: #FFD700;">
                    ${data.tx_hash}
                </a><br>
                Merkle Root: <code>${data.merkle_root}</code>
            `;
            resultDiv.style.display = 'block';
            btn.textContent = '✅ Anchored!';

            setTimeout(() => location.reload(), 3000);
        } else {
            resultDiv.className = 'alert alert-error';
            resultDiv.innerHTML = `<strong>⚠️ ${data.message || data.detail || 'Anchoring failed'}</strong>`;
            resultDiv.style.display = 'block';
            btn.textContent = originalText;
            btn.disabled = false;
        }
    } catch (err) {
        resultDiv.className = 'alert alert-error';
        resultDiv.innerHTML = `<strong>❌ Error:</strong> ${err.message}`;
        resultDiv.style.display = 'block';
        btn.textContent = originalText;
        btn.disabled = false;
    }
}
