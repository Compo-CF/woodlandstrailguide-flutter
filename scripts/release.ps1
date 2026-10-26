# Build, verify and publish The Woodlands Trail Guide to Google Play.
#
#   scripts\release.ps1                      build, check, upload to internal
#   scripts\release.ps1 -Track closed        upload to the closed testing track
#   scripts\release.ps1 -CheckOnly           build and check, upload nothing
#   scripts\release.ps1 -SkipBuild           check and upload the existing .aab
#   scripts\release.ps1 -Track production -Rollout 0.2 -Notes "Fixes."
#
# The iOS half of this is scripts/testflight.sh in the WoodlandsTrailGuide
# repo, which runs on the Mac under zsh. This one is PowerShell on purpose:
# Android needs no macOS, bash is not on PATH here, and the signing material
# (woodlandstrailguide-upload.jks + android/key.properties) lives on this
# machine and not on the Mac. Building on the Mac is the slow path AND the one
# where signing silently falls back to the debug keystore.
#
# Windows CAN run Gradle. It fails from a sandboxed shell -- Selector.open()
# cannot create its AF_UNIX pipe, which surfaces as Gradle's misleading
# "Unable to establish loopback connection" -- but an ordinary PowerShell
# prompt builds fine. Run this from a real terminal.
#
# Upload is keyless: play_publish.py impersonates the publisher service
# account using your gcloud ADC, because the org blocks downloadable SA keys.
# Prereqs are documented at the top of ~/appstoreconnect/play_publish.py.
#
# ASCII only, no && / || / ternary -- Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [string] $Track = 'internal',
    [double] $Rollout = 1.0,
    [string] $Notes = '',
    [string] $Package = 'com.compofelice.woodlandstrailguide_flutter',
    [switch] $SkipBuild,
    [switch] $CheckOnly
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Aab = Join-Path $RepoRoot 'build\app\outputs\bundle\release\app-release.aab'
$Verify = Join-Path $PSScriptRoot 'verify_aab.py'
$Publisher = Join-Path $HOME 'appstoreconnect\play_publish.py'

function Step($text) {
    Write-Host ''
    Write-Host ('==> ' + $text) -ForegroundColor Magenta
}

function Fail($text) {
    Write-Host ''
    Write-Host ('FAILED: ' + $text) -ForegroundColor Red
    exit 1
}

Set-Location $RepoRoot

# --- 1. What are we shipping -------------------------------------------------
$versionLine = Select-String -Path (Join-Path $RepoRoot 'pubspec.yaml') -Pattern '^version:' | Select-Object -First 1
if ($null -eq $versionLine) { Fail 'no version: line in pubspec.yaml' }
$version = $versionLine.Line -replace '^version:\s*', ''
Write-Host ('The Woodlands Trail Guide ' + $version + '  ->  ' + $Track) -ForegroundColor Cyan
Write-Host ('package ' + $Package)

# Play rejects a version code it has already seen, and the rebuild-to-find-out
# loop is the expensive one. Nudge rather than block: only the Console knows
# for certain which codes have been consumed.
if ($version -notmatch '\+\d+$') {
    Write-Host 'WARNING: pubspec version has no +buildNumber suffix' -ForegroundColor Yellow
}

# --- 2. Build ----------------------------------------------------------------
if ($SkipBuild) {
    Step 'Skipping build, using the existing bundle'
    if (-not (Test-Path $Aab)) { Fail ('no bundle at ' + $Aab + ' -- run without -SkipBuild') }
} else {
    Step 'Building release bundle (slow; lintVitalRelease is the long tail)'
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) {
        Fail 'flutter build. If this said "Unable to establish loopback connection", you are in a sandboxed shell -- run from a real PowerShell prompt.'
    }
}

if (-not (Test-Path $Aab)) { Fail ('build reported success but no bundle at ' + $Aab) }

# --- 3. Verify ---------------------------------------------------------------
# Never skippable. Each check is here because Play rejected a real upload for
# it, and two of the three fail silently at build time.
Step 'Verifying the bundle'
python $Verify $Aab --package $Package
if ($LASTEXITCODE -ne 0) { Fail 'pre-upload checks -- see PLAY_SUBMISSION.md' }

if ($CheckOnly) {
    Step 'Done (check only)'
    Write-Host ('Bundle is at ' + $Aab)
    exit 0
}

# --- 4. Publish --------------------------------------------------------------
if (-not (Test-Path $Publisher)) {
    Fail ('publisher script not found at ' + $Publisher)
}

Step ('Uploading to the ' + $Track + ' track')
$publishArgs = @($Publisher, '--aab', $Aab, '--package', $Package, '--track', $Track)
if ($Rollout -lt 1.0) { $publishArgs += @('--rollout', $Rollout) }
if ($Notes -ne '') { $publishArgs += @('--notes', $Notes) }

python @publishArgs
if ($LASTEXITCODE -ne 0) {
    Fail @'
upload. Read the error above:
  "Package not found"             -> the SA has no access to this app in Play
                                     Console > Users and permissions
  "Version code ... already used" -> bump the +N in pubspec.yaml and rebuild
  "Track ... is not active"       -> that track has no prior release; create
                                     the first one in the Console, then use this
  403 / impersonation errors      -> see the prereqs at the top of
                                     ~/appstoreconnect/play_publish.py
'@
}

Step 'Done'
Write-Host ('Published ' + $version + ' to ' + $Track + '.')
Write-Host 'Play processes the bundle for a few minutes before testers see it.'
