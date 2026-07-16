<#
    setup.ps1 — Install digi agent skills into Claude Code (Windows / PowerShell)
    Run this once after cloning the repo:  pwsh ./setup.ps1 [profile]

    The optional first argument is a profile name (see profiles/<name>.txt).
    Omit it to install every agent (the "work" profile is the default).
        pwsh ./setup.ps1            # full install (all agents)
        pwsh ./setup.ps1 personal   # install only the agents in profiles/personal.txt

    Install method is COPY (same as setup.sh), so Windows users do NOT need
    symlinks or Developer Mode.
#>

[CmdletBinding()]
param(
    [string]$Profile = "work"
)

$ErrorActionPreference = "Stop"

# -- Output helpers ------------------------------------------------------------
function Write-Ok   { param([string]$Msg) Write-Host "  " -NoNewline; Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host "  $Msg" }
function Write-Info { param([string]$Msg) Write-Host "  $Msg" }
function Write-Warn { param([string]$Msg) Write-Host "  " -NoNewline; Write-Host "!"  -ForegroundColor Yellow -NoNewline; Write-Host "  $Msg" }
function Write-Fail { param([string]$Msg) Write-Host "  " -NoNewline; Write-Host "x"  -ForegroundColor Red    -NoNewline; Write-Host "  $Msg" }

# -- Resolve the profile -------------------------------------------------------
$RepoDir     = $PSScriptRoot
$ProfilesDir = Join-Path $RepoDir "profiles"
$ProfileFile = Join-Path $ProfilesDir "$Profile.txt"

# -- Banner --------------------------------------------------------------------
Write-Host ""
Write-Host "digi - Agent Setup " -NoNewline -ForegroundColor White
Write-Host "(profile: $Profile)" -ForegroundColor Yellow
Write-Host "------------------------------------"
Write-Host ""

if (-not (Test-Path -LiteralPath $ProfileFile)) {
    Write-Fail "No profile named '$Profile' found at $ProfileFile"
    Write-Host ""
    Write-Info "Available profiles:"
    Get-ChildItem -Path $ProfilesDir -Filter "*.txt" -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Info ("  * " + $_.BaseName) }
    Write-Host ""
    exit 1
}

# -- Find / create the target skills directory ---------------------------------
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$SkillsDir = Join-Path $ClaudeDir "skills"

if (Test-Path -LiteralPath $ClaudeDir) {
    Write-Ok "Found Claude Code at $ClaudeDir"
} else {
    Write-Warn "Could not find Claude Code at $ClaudeDir"
    Write-Info "Creating it now — if Claude Code is installed elsewhere, move the skills folder afterwards."
}

if (-not (Test-Path -LiteralPath $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
    Write-Ok "Created skills folder at $SkillsDir"
} else {
    Write-Info "Installing into $SkillsDir"
}

# -- Copy each skill in the profile --------------------------------------------
$RepoSkills = Join-Path $RepoDir "skills"

Write-Host ""
Write-Info "Installing skills..."
Write-Host ""

$Installed = 0
$Failed    = 0
$Missing   = 0

foreach ($rawLine in Get-Content -LiteralPath $ProfileFile) {
    # Strip inline comments and surrounding whitespace
    $skillName = ($rawLine -replace '#.*$', '').Trim()
    if ([string]::IsNullOrWhiteSpace($skillName)) { continue }

    $skillDir = Join-Path $RepoSkills $skillName
    $target   = Join-Path $SkillsDir  $skillName

    if (-not (Test-Path -LiteralPath $skillDir)) {
        Write-Warn "$skillName - listed in profile but no such folder in skills/ (skipping)"
        $Missing++
        continue
    }

    try {
        # Remove then copy — avoids nesting the source folder inside an existing target on re-runs
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $skillDir -Destination $target -Recurse -Force
        Write-Ok $skillName
        $Installed++
    } catch {
        Write-Fail "$skillName - could not copy (check permissions on $SkillsDir)"
        $Failed++
    }
}

# -- Summary -------------------------------------------------------------------
Write-Host ""
Write-Host "------------------------------------"

if ($Failed -gt 0 -or $Missing -gt 0) {
    Write-Warn "$Installed skills installed, $Failed failed, $Missing missing from skills/."
} else {
    Write-Ok "$Installed skills installed successfully."
}

# -- Third-party skill dependencies --------------------------------------------
# The crew (especially Tai and Sora) invoke external, non-crew skills that live
# in OTHER GitHub repos - they're described in skills-deps.lock.json. We re-fetch
# them here by shallow-cloning each unique repo once and copying the folder that
# contains the skill's SKILL.md into %USERPROFILE%\.claude\skills\<name>.
#
# Gating:
#   * Needs `git` on PATH. If it's missing we warn and skip - the crew install
#     above still succeeded. (JSON parsing uses PowerShell's built-in
#     ConvertFrom-Json, so no Python dependency on Windows.)
#   * Profile-driven: only fetches deps whose owning persona is active for this
#     profile (see the "profiles" map in the lock file). So `personal` pulls
#     Tai + Sora deps; `work` pulls everything.
#   * Warn-and-continue: a failed clone/copy for one skill never aborts the rest.
#
# NOTE: MCP-backed skills (e.g. Figma design skills) are NOT fully wired by this
# step. Cloning the SKILL.md files does not configure their MCP server - that has
# to be set up separately in Claude Code.
$DepsLock = Join-Path $RepoDir "skills-deps.lock.json"

Write-Host ""
Write-Host "------------------------------------"
Write-Info "Third-party skill dependencies..."
Write-Host ""

if (-not (Test-Path -LiteralPath $DepsLock)) {
    Write-Warn "No skills-deps.lock.json found - skipping third-party skills."
} elseif (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "git not found on PATH - skipping third-party skills."
    Write-Info "  Install git, then re-run this script to fetch Tai's & Sora's external skills."
} else {
    $lock = Get-Content -LiteralPath $DepsLock -Raw | ConvertFrom-Json

    # Which personas are active for this profile? Unknown profile => fetch everything.
    $personas = @()
    if ($lock.profiles.PSObject.Properties.Name -contains $Profile) {
        $personas = @($lock.profiles.$Profile)
    }

    # Build the list of skills this profile needs.
    $needed = @()
    foreach ($prop in $lock.skills.PSObject.Properties) {
        $name  = $prop.Name
        $entry = $prop.Value
        $neededBy = @($entry.neededBy)
        $isNeeded = $true
        if ($personas.Count -gt 0) {
            $isNeeded = ($neededBy | Where-Object { $personas -contains $_ }).Count -gt 0
        }
        if ($isNeeded -and $entry.sourceUrl -and $entry.skillPath) {
            $needed += [PSCustomObject]@{ Name = $name; Url = $entry.sourceUrl; SkillPath = $entry.skillPath }
        }
    }

    if ($needed.Count -eq 0) {
        Write-Info "No third-party skills needed for profile '$Profile'."
    } else {
        $TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("digi-deps-" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $TmpRoot -Force | Out-Null
        $Fetched      = 0
        $FetchFailed  = 0
        $ClonedRepos  = @{}   # url -> local clone dir (dedupe per run)

        foreach ($dep in $needed) {
            $slug = ($dep.Url -replace '[^A-Za-z0-9]', '_')
            $repoDir = Join-Path $TmpRoot $slug

            if (-not $ClonedRepos.ContainsKey($dep.Url)) {
                git clone --quiet --depth 1 $dep.Url $repoDir 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $repoDir)) {
                    $ClonedRepos[$dep.Url] = $repoDir
                } else {
                    if (Test-Path -LiteralPath $repoDir) { Remove-Item -LiteralPath $repoDir -Recurse -Force }
                    Write-Warn "$($dep.Name) - could not clone $($dep.Url) (skipping)"
                    $FetchFailed++
                    continue
                }
            }

            # skillPath uses forward slashes in the lock; normalise for Windows.
            $relPath   = $dep.SkillPath -replace '/', '\'
            $skillFile = Join-Path $repoDir $relPath
            if (-not (Test-Path -LiteralPath $skillFile)) {
                Write-Warn "$($dep.Name) - $($dep.SkillPath) not found in repo (skipping)"
                $FetchFailed++
                continue
            }

            $srcDir = Split-Path -Parent $skillFile
            $target = Join-Path $SkillsDir $dep.Name
            try {
                if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
                Copy-Item -LiteralPath $srcDir -Destination $target -Recurse -Force
                Write-Ok "$($dep.Name)  (from $($dep.Url))"
                $Fetched++
            } catch {
                Write-Warn "$($dep.Name) - could not copy into $SkillsDir (skipping)"
                $FetchFailed++
            }
        }

        Remove-Item -LiteralPath $TmpRoot -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host ""
        if ($FetchFailed -gt 0) {
            Write-Warn "$Fetched third-party skills fetched, $FetchFailed failed (see warnings above)."
        } else {
            Write-Ok "$Fetched third-party skills fetched."
        }
        Write-Info "Note: MCP-backed skills (e.g. Figma) still need their MCP server configured in Claude Code."
    }
}

Write-Host ""
Write-Host "You're all set. Here's what to do next:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Open Claude Code (the desktop app, or run 'claude' in a terminal)"
Write-Host "  2. Start a new conversation"
Write-Host "  3. Type one of these to activate an agent:"
Write-Host ""
Write-Host "       /joe    - notes and knowledge (asks for your Obsidian vault on first use)"
Write-Host "       /matt   - web research and documentation"
Write-Host "       /tai    - coding, code review, architecture"
Write-Host "       /sora   - design, UI components, visual direction"
Write-Host "       /mimi   - career, 1:1 prep, goal tracking"
Write-Host "       /agumon - meeting briefings from transcripts"
Write-Host ""
