#requires -Version 5.1
<#
.SYNOPSIS
  Minimal, dependency-free check of an Anthropic API key + request shape.

.DESCRIPTION
  "No final response was produced" from a wrapper like hermes is NOT an auth
  rejection. This script makes one bare /v1/messages call so you can see the
  REAL outcome (HTTP status + body) and tell apart:

    - a genuine key problem  (rotate the key)        -> 401
    - a model-id / params / billing problem          -> 404 / 400 / 403
    - a perfectly valid key + a bug in the wrapper    -> 200

  It never prints your key.

.EXAMPLE
  $env:ANTHROPIC_API_KEY = "sk-ant-..."
  ./tools/diagnose-anthropic.ps1

.EXAMPLE
  ./tools/diagnose-anthropic.ps1 -Model claude-sonnet-4-6
#>
[CmdletBinding()]
param(
    [string]$Model  = "claude-opus-4-8",
    [string]$ApiKey = $env:ANTHROPIC_API_KEY
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "No API key found in `$env:ANTHROPIC_API_KEY." -ForegroundColor Yellow
    Write-Host 'Set it first, e.g.:  $env:ANTHROPIC_API_KEY = "sk-ant-..."'
    exit 2
}
if (($env:ANTHROPIC_API_KEY) -and ($env:ANTHROPIC_AUTH_TOKEN)) {
    Write-Host "WARNING: both ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are set." -ForegroundColor Yellow
    Write-Host "The SDK sends both headers and the API rejects that with 401. Unset one." -ForegroundColor Yellow
    Write-Host ""
}

$body = @{
    model      = $Model
    max_tokens = 64
    messages   = @(@{ role = "user"; content = "Reply with exactly: bootstrap ok" })
} | ConvertTo-Json -Depth 6

$headers = @{
    "x-api-key"         = $ApiKey
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
}

Write-Host "POST https://api.anthropic.com/v1/messages   (model=$Model)" -ForegroundColor Cyan
try {
    $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
        -Method Post -Headers $headers -Body $body -ErrorAction Stop

    $text = ($resp.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
    Write-Host "HTTP 200 OK" -ForegroundColor Green
    Write-Host "  served-by model : $($resp.model)"
    Write-Host "  stop_reason     : $($resp.stop_reason)"
    Write-Host "  text            : $text"
    if ($resp.stop_reason -eq "refusal") {
        Write-Host "  -> Classifier refusal. category: $($resp.stop_details.category)" -ForegroundColor Yellow
        Write-Host "     The KEY is fine; this specific request was declined by a safety classifier." -ForegroundColor Yellow
    }
    elseif ([string]::IsNullOrWhiteSpace($text)) {
        Write-Host "  -> 200 but no text block. The model likely stopped on tool_use, or the only" -ForegroundColor Yellow
        Write-Host "     blocks are (empty) thinking blocks. A wrapper that reads content[0].text" -ForegroundColor Yellow
        Write-Host "     would report 'no final response'. Fix the wrapper's response parsing." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "KEY IS VALID. If hermes still fails, the bug is in how hermes BUILDS the request" -ForegroundColor Green
    Write-Host "or READS the response (model id, removed params, or text-first content parsing) --" -ForegroundColor Green
    Write-Host "not the key. Rotating the key again will not change this." -ForegroundColor Green
}
catch {
    $r = $_.Exception.Response
    if ($null -ne $r) {
        $code = [int]$r.StatusCode
        $raw  = ""
        try {
            $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
            $raw = $reader.ReadToEnd()
        } catch { }
        Write-Host "HTTP $code" -ForegroundColor Red
        if ($raw) { Write-Host $raw }
        switch ($code) {
            401 { Write-Host "-> AUTHENTICATION. Key is invalid/revoked, OR both ANTHROPIC_API_KEY and" -ForegroundColor Yellow
                  Write-Host "   ANTHROPIC_AUTH_TOKEN are set. THIS is the only case where a new key helps." -ForegroundColor Yellow }
            403 { Write-Host "-> PERMISSION / BILLING. Key can't access '$Model', or a workspace/billing limit." -ForegroundColor Yellow
                  Write-Host "   Check console.anthropic.com billing + workspace model access." -ForegroundColor Yellow }
            404 { Write-Host "-> NOT FOUND. '$Model' is not a valid model id (typo or retired model)." -ForegroundColor Yellow
                  Write-Host "   Use an exact current id, e.g. claude-opus-4-8 / claude-sonnet-4-6." -ForegroundColor Yellow }
            400 { Write-Host "-> BAD REQUEST. The payload is invalid for this model. On current models," -ForegroundColor Yellow
                  Write-Host "   temperature/top_p/top_k and thinking.budget_tokens are REJECTED, and a" -ForegroundColor Yellow
                  Write-Host "   trailing assistant 'prefill' message 400s. This is very likely what hermes" -ForegroundColor Yellow
                  Write-Host "   sends. A new key will NOT fix it -- fix the request body." -ForegroundColor Yellow }
            429 { Write-Host "-> RATE LIMITED. Back off and retry; honor the retry-after header." -ForegroundColor Yellow }
            default { Write-Host "-> Server/other error; see body above. 5xx/529 are retryable." -ForegroundColor Yellow }
        }
    }
    else {
        Write-Host "Network/TLS error (no HTTP response): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "-> Check connectivity / proxy / corporate TLS interception." -ForegroundColor Yellow
    }
    exit 1
}
