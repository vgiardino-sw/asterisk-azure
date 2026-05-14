param(
  [string]$TerraformDir = "terraform",
  [string]$OutputInventory = "ansible/inventory/hosts.yml",
  [string]$OutputVars = "ansible/group_vars/vars.generated.yml"
)

# Resolve paths relative to repo root (parent of this script directory),
# so the script works no matter where it is executed from.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

if ([System.IO.Path]::IsPathRooted($TerraformDir)) {
  $resolvedTerraformDir = $TerraformDir
} else {
  $resolvedTerraformDir = Join-Path $repoRoot $TerraformDir
}

if ([System.IO.Path]::IsPathRooted($OutputInventory)) {
  $resolvedOutputInventory = $OutputInventory
} else {
  $resolvedOutputInventory = Join-Path $repoRoot $OutputInventory
}

if ([System.IO.Path]::IsPathRooted($OutputVars)) {
  $resolvedOutputVars = $OutputVars
} else {
  $resolvedOutputVars = Join-Path $repoRoot $OutputVars
}

if (-not (Test-Path -LiteralPath $resolvedTerraformDir)) {
  throw "Terraform directory not found: $resolvedTerraformDir"
}

$tfOutputRaw = terraform -chdir="$resolvedTerraformDir" output -json | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "terraform output failed for directory: $resolvedTerraformDir"
}

$tfJson = $tfOutputRaw | ConvertFrom-Json

$target = $tfJson.ansible_target.value
$runtime = $tfJson.ansible_runtime_vars.value

if ($null -eq $target -or $null -eq $runtime) {
  throw "Required Terraform outputs (ansible_target / ansible_runtime_vars) are missing. Run terraform apply first."
}

if ([string]::IsNullOrWhiteSpace([string]$target.host) -or [string]::IsNullOrWhiteSpace([string]$target.ssh_user)) {
  throw "Terraform output values are empty (host/user). Ensure terraform state contains applied outputs."
}

# Terraform output can be null if the value is unset; default to false for YAML rendering.
$enableHttpChallenge = if ($null -ne $runtime.enable_http_challenge) {
  $runtime.enable_http_challenge.ToString().ToLower()
} else {
  "false"
}

$inventory = @"
all:
  hosts:
    $($target.host_alias):
      ansible_host: $($target.host)
      ansible_user: $($target.ssh_user)
      ansible_port: $($target.ssh_port)
      ansible_connection: ssh
      ansible_python_interpreter: /usr/bin/python3
      ansible_ssh_private_key_file: <replace_with_path_to_your_private_key>
"@

$vars = @"
---
sip_tls_port: $($runtime.sip_tls_port)
rtp_udp_start: $($runtime.rtp_udp_start)
rtp_udp_end: $($runtime.rtp_udp_end)
enable_http_challenge: $enableHttpChallenge
letsencrypt_email: "$($runtime.letsencrypt_email)"
fqdn: "$($runtime.fqdn)"
domain_name: "$($runtime.domain_name)"
wa_business_phone_number: "$($runtime.wa_business_phone_number)"
sip_ua_password: "$($runtime.sip_ua_password)"
meta_sip_user_password: "$($runtime.meta_sip_user_password)"
local_net: "$($runtime.local_net)"
external_ip: "$($runtime.external_ip)"
poc_scenario: "$($runtime.poc_scenario)"
livekit_domain: "$($runtime.livekit_domain)"
wa_consumer_phone_number: "$($runtime.wa_consumer_phone_number)"
livekit_auth_password: "$($runtime.livekit_auth_password)"
"@

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputInventory) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputInventory) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputVars) | Out-Null

Set-Content -Path $resolvedOutputInventory -Value $inventory
Set-Content -Path $resolvedOutputVars -Value $vars

Write-Host "Generated $resolvedOutputInventory and $resolvedOutputVars from Terraform outputs."
