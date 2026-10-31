param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("patch", "minor", "major")]
    [string]$Part
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".git")) {
    throw "Run this script from the KeyCase repository."
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") {
    throw "Releases must be cut from main (current: $branch)."
}

$dirty = git status --porcelain
if ($dirty) {
    throw "Working tree is not clean. Commit or stash changes before releasing.`n$dirty"
}

$gradleFile = Join-Path $root "app/build.gradle.kts"
$content = [IO.File]::ReadAllText($gradleFile)
$versionMatch = [regex]::Match($content, 'versionName\s*=\s*"(\d+)\.(\d+)\.(\d+)"')
$codeMatch = [regex]::Match($content, 'versionCode\s*=\s*(\d+)')
if (-not $versionMatch.Success -or -not $codeMatch.Success) {
    throw "Could not read versionCode/versionName from app/build.gradle.kts."
}

$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value
$versionCode = [int]$codeMatch.Groups[1].Value

switch ($Part) {
    "patch" {
        $patch++
    }
    "minor" {
        $minor++
        $patch = 0
    }
    "major" {
        $major++
        $minor = 0
        $patch = 0
    }
}

$newVersion = "$major.$minor.$patch"
$newCode = $versionCode + 1
$tag = "v$newVersion"

git fetch --tags --quiet
$existing = git tag --list $tag
if ($existing) {
    throw "Tag $tag already exists."
}

$content = $content -replace 'versionCode\s*=\s*\d+', "versionCode = $newCode"
$content = $content -replace 'versionName\s*=\s*"[^"]+"', "versionName = `"$newVersion`""
[IO.File]::WriteAllText($gradleFile, $content, [Text.UTF8Encoding]::new($false))

git add app/build.gradle.kts
git commit -m "chore(release): $tag"
git tag -a $tag -m "KeyCase $newVersion"
git push origin main
git push origin $tag

Write-Host "Released $tag. GitHub Actions is building and publishing it now."
Write-Host "Release page: https://github.com/LumiDesk/key-case/releases/tag/$tag"
