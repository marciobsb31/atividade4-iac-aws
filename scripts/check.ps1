# Diagnóstico somente leitura. Rode na raiz do repositório:  .\scripts\check.ps1
$root  = Split-Path $PSScriptRoot -Parent
$tfdir = Join-Path $root "terraform"
$ip    = (terraform -chdir="$tfdir" output -raw public_ip).Trim()
$myIp  = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
$tfvars = Get-Content (Join-Path $tfdir "terraform.tfvars") -Raw
$admin = [regex]::Match($tfvars, 'admin_cidr\s*=\s*"([^"]+)"').Groups[1].Value

Write-Host "IP da VM (Terraform)      : $ip"
Write-Host "Seu IP publico agora      : $myIp"
Write-Host "admin_cidr no tfvars      : $admin"
if ($admin -ne "$myIp/32") {
  Write-Host "ATENCAO: seu IP mudou. Edite terraform\terraform.tfvars (admin_cidr = `"$myIp/32`") e rode: terraform -chdir=terraform apply" -ForegroundColor Yellow
}
foreach ($port in 80, 3389, 5986) {
  $r = Test-NetConnection -ComputerName $ip -Port $port -WarningAction SilentlyContinue
  "{0,5}  {1}" -f $port, $(if ($r.TcpTestSucceeded) { "ABERTA" } else { "FECHADA/SEM RESPOSTA" })
}
