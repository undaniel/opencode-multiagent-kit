#Requires -Version 5.1
<#
.SYNOPSIS
  Instala el kit multiagente (orchestrator + superpowers) en Windows nativo.
.DESCRIPTION
  Copia agentes y skills a %USERPROFILE%\.config\opencode, instala superpowers
  y fusiona opencode.json. No toca ningun proyecto.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
.EXAMPLE
  $env:MODEL_PRIMARY="deepseek/deepseek-v4-pro"; .\install-windows.ps1
#>
[CmdletBinding()]
param(
  [string]$ModelPrimary = $env:MODEL_PRIMARY,
  [string]$ModelSub = $env:MODEL_SUB,
  [string]$ModelReview = $env:MODEL_REVIEW
)

$ErrorActionPreference = "Stop"

if (-not $ModelPrimary) { $ModelPrimary = "deepseek/deepseek-v4-pro" }
if (-not $ModelSub) { $ModelSub = "deepseek/deepseek-flash" }
if (-not $ModelReview) { $ModelReview = $ModelPrimary }
$KeepDefaultAgent = $env:KEEP_DEFAULT_AGENT -eq "1"
$KitDir = $PSScriptRoot

$OrchRepo = "https://github.com/fxcl/opencode-orchestrator.git"
$OrchRef = if ($env:ORCH_REF) { $env:ORCH_REF } else { "7ca5ca771367e583692887452bf161bde4fc5ee9" }
$SpRepo = "https://github.com/obra/superpowers.git"
$SpRef = if ($env:SP_REF) { $env:SP_REF } else { "v7.0.2" }

$Target = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".config\opencode" }
$Cache = Join-Path $env:LOCALAPPDATA "opencode-multiagent"
$Stamp = Get-Date -Format "yyyyMMddHHmmss"

foreach ($bin in @("opencode", "git", "npm")) {
  if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) {
    throw "Falta '$bin' en PATH."
  }
}

if (-not (Test-Path (Join-Path $KitDir "agents"))) { throw "Falta la carpeta agents/ junto al instalador." }
if (-not (Test-Path (Join-Path $KitDir "templates\global-AGENTS.md"))) { throw "Falta templates/global-AGENTS.md." }

function Sync-Repo {
  param([string]$Repo, [string]$Ref, [string]$Dir)
  if (Test-Path (Join-Path $Dir ".git")) {
    & git -C $Dir fetch --tags --quiet origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch fallo en $Dir" }
    & git -C $Dir checkout --quiet $Ref
  } else {
    & git clone --quiet $Repo $Dir
    if ($LASTEXITCODE -ne 0) { throw "git clone fallo: $Repo" }
    & git -C $Dir checkout --quiet $Ref
  }
  if ($LASTEXITCODE -ne 0) { throw "No se pudo usar la ref '$Ref' en $Dir" }
}

function ConvertTo-Hashtable {
  param($Object)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    $h = @{}
    foreach ($key in $Object.Keys) { $h[$key] = ConvertTo-Hashtable $Object[$key] }
    return $h
  }
  if ($Object -is [System.Management.Automation.PSCustomObject]) {
    $h = @{}
    foreach ($prop in $Object.PSObject.Properties) { $h[$prop.Name] = ConvertTo-Hashtable $prop.Value }
    return $h
  }
  if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
    return @($Object | ForEach-Object { ConvertTo-Hashtable $_ })
  }
  return $Object
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Text)
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding -ArgumentList $false))
}

Write-Host "==> Preparando $Target"
New-Item -ItemType Directory -Force -Path $Target | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Target "agents") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Target "skills") | Out-Null
New-Item -ItemType Directory -Force -Path $Cache | Out-Null

$orchDir = Join-Path $Cache "orchestrator"
$spDir = Join-Path $Cache "superpowers"
Write-Host "==> Descargando versiones fijas"
Sync-Repo -Repo $OrchRepo -Ref $OrchRef -Dir $orchDir
Sync-Repo -Repo $SpRepo -Ref $SpRef -Dir $spDir

Write-Host "==> Copiando agentes y skills"
Get-ChildItem -Path (Join-Path $orchDir "agents\*.md") | ForEach-Object {
  $dest = Join-Path (Join-Path $Target "agents") $_.Name
  if (Test-Path $dest) { Copy-Item -Path $dest -Destination "$dest.bak.$Stamp" -Force }
  Copy-Item -Path $_.FullName -Destination $dest -Force
}
Copy-Item -Path (Join-Path $orchDir "skills\*") -Destination (Join-Path $Target "skills") -Recurse -Force

Write-Host "==> Aplicando agentes endurecidos del kit"
Get-ChildItem -Path (Join-Path $KitDir "agents\*.md") | ForEach-Object {
  Copy-Item -Path $_.FullName -Destination (Join-Path (Join-Path $Target "agents") $_.Name) -Force
}

$agentsDest = Join-Path $Target "AGENTS.md"
if (-not (Test-Path $agentsDest)) {
  Copy-Item -Path (Join-Path $orchDir "AGENTS.md") -Destination $agentsDest -Force
}
$agentsText = [System.IO.File]::ReadAllText($agentsDest)
$agentsText = $agentsText.Replace("- User communication in English.", "- User communication in the user's language.")
$blockPath = Join-Path $KitDir "templates\global-AGENTS.md"
$block = [System.IO.File]::ReadAllText($blockPath).Trim()
$markerPattern = '(?s)<!-- opencode-multiagent-kit:start -->.*?<!-- opencode-multiagent-kit:end -->'
$match = [regex]::Match($agentsText, $markerPattern)
if ($match.Success) {
  $agentsText = $agentsText.Substring(0, $match.Index) + $block + $agentsText.Substring($match.Index + $match.Length)
} else {
  $agentsText = $agentsText.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
}
Write-Utf8NoBom -Path $agentsDest -Text $agentsText
Write-Host "    reglas del kit fusionadas en AGENTS.md"

Write-Host "==> Ajustando modelos a $ModelPrimary / $ModelSub (reviews: $ModelReview)"
$reviewAgents = @("plan-runner.md", "code-reviewer.md", "security-reviewer.md", "spec-critic.md")
Get-ChildItem -Path (Join-Path $Target "agents\*.md") | ForEach-Object {
  $model = if ($reviewAgents -contains $_.Name) { $ModelReview } else { $ModelSub }
  $text = [System.IO.File]::ReadAllText($_.FullName)
  $new = $text.Replace("opencode-go/deepseek-v4-pro", $ModelPrimary).Replace("opencode-go/deepseek-v4-flash", $model)
  if ($new -ne $text) { Write-Utf8NoBom -Path $_.FullName -Text $new }
}

$spPath = Join-Path $Target "node_modules\superpowers"
Write-Host "==> Instalando superpowers"
if (-not (Test-Path $spPath)) {
  & npm install --prefix $Target --no-audit --no-fund "superpowers@git+$SpRepo#$SpRef"
  if ($LASTEXITCODE -ne 0) { throw "npm install de superpowers fallo" }
} else {
  Write-Host "    ya estaba instalado"
}

Write-Host "==> Fusionando opencode.json (backup previo)"
$configPath = Join-Path $Target "opencode.json"
if (Test-Path $configPath) { Copy-Item -Path $configPath -Destination "$configPath.bak.$Stamp" -Force }

$cfg = @{}
if (Test-Path $configPath) {
  $raw = [System.IO.File]::ReadAllText($configPath)
  if ($raw.Trim().Length -gt 0) {
    try {
      $cfg = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
    } catch {
      throw "opencode.json no es JSON valido. Fusiona el ejemplo del README a mano. Detalle: $_"
    }
  }
}
if ($cfg -isnot [hashtable]) { throw "opencode.json debe ser un objeto JSON." }

$plugins = @()
if ($cfg.ContainsKey("plugins")) { $plugins = @($cfg["plugins"]) }
elseif ($cfg.ContainsKey("plugin")) { $plugins = @($cfg["plugin"]); $cfg.Remove("plugin") }
$plugins = @($plugins | Where-Object { "$_" -notmatch "superpowers" })
$plugins += $spPath.Replace("\", "/")
$cfg["plugins"] = @($plugins)

if (-not $cfg.ContainsKey("model")) { $cfg["model"] = $ModelSub }
if (-not $KeepDefaultAgent) { $cfg["default_agent"] = "build" }

if (-not $cfg.ContainsKey("agent") -or $cfg["agent"] -isnot [hashtable]) {
  $cfg["agent"] = @{}
}
$agents = $cfg["agent"]

function Set-AgentModel {
  param([string]$Name, [string]$Model, [string]$Effort)
  if (-not $agents.ContainsKey($Name) -or $agents[$Name] -isnot [hashtable]) {
    $agents[$Name] = @{}
  }
  $agents[$Name]["model"] = $Model
  if ($Effort) {
    $agents[$Name]["reasoningEffort"] = $Effort
  } else {
    $null = $agents[$Name].Remove("reasoningEffort")
  }
}

# Rapido por defecto; pro solo donde el juicio importa.
Set-AgentModel -Name "orchestrator" -Model $ModelPrimary -Effort "max"
$agents["orchestrator"]["plan_post_approval_handoff_agent"] = "orchestrator"
Set-AgentModel -Name "plan" -Model $ModelPrimary -Effort "max"
Set-AgentModel -Name "plan-runner" -Model $ModelReview -Effort "max"
Set-AgentModel -Name "code-reviewer" -Model $ModelReview -Effort "max"
Set-AgentModel -Name "security-reviewer" -Model $ModelReview -Effort "max"
Set-AgentModel -Name "spec-critic" -Model $ModelReview -Effort "max"
Set-AgentModel -Name "build" -Model $ModelSub
foreach ($name in @("code-explorer", "code-executor", "test-verifier", "docs-reviewer", "api-docs-researcher", "host-security-investigator")) {
  Set-AgentModel -Name $name -Model $ModelSub
}

$json = $cfg | ConvertTo-Json -Depth 20
Write-Utf8NoBom -Path $configPath -Text ($json + [Environment]::NewLine)
$check = [System.IO.File]::ReadAllText($configPath)
$null = $check | ConvertFrom-Json

Write-Host ""
Write-Host "==> Listo. Config: $configPath"
Write-Host "    Reinicia OpenCode y verifica:"
Write-Host "      opencode debug agents"
Write-Host "      opencode plugin list"
Write-Host ""
Write-Host "    Por defecto:  opencode                    # agente build (rapido)"
Write-Host "    Con equipo:   opencode --agent orchestrator"
