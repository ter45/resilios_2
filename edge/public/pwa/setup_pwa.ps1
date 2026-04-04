# ══════════════════════════════════════════════════════════════════
#  ResiliOS PWA — Setup script
#  Ejecutar desde: E:\resilios\edge\public\pwa\
#  Uso: powershell -ExecutionPolicy Bypass -File .\setup_pwa.ps1
# ══════════════════════════════════════════════════════════════════

Write-Host "Configurando PWA ResiliOS..." -ForegroundColor Cyan

# Crear directorios
New-Item -ItemType Directory -Force -Path "src\screens"  | Out-Null
New-Item -ItemType Directory -Force -Path "src\context"  | Out-Null
New-Item -ItemType Directory -Force -Path "src\api"      | Out-Null

Write-Host "[OK] Directorios creados" -ForegroundColor Green

# Separar TablesScreen en su propio archivo
$tablesScreen = Get-Content "src\screens\TablesAndOrderScreens.jsx" -Raw
$splitPoint = $tablesScreen.IndexOf("// ══════════════════════════════════════════════════════════════════`r`n//  src/screens/OrderScreen.jsx")
if ($splitPoint -eq -1) {
  $splitPoint = $tablesScreen.IndexOf("// ══════════════════════════════════════════════════════════════════`n//  src/screens/OrderScreen.jsx")
}

if ($splitPoint -gt 0) {
  $tablesOnly = $tablesScreen.Substring(0, $splitPoint).Trim()
  $orderOnly  = $tablesScreen.Substring($splitPoint).Trim()
  Set-Content -Path "src\screens\TablesScreen.jsx" -Value $tablesOnly -Encoding UTF8
  Set-Content -Path "src\screens\OrderScreen.jsx"  -Value $orderOnly  -Encoding UTF8
  Write-Host "[OK] TablesScreen.jsx y OrderScreen.jsx" -ForegroundColor Green
} else {
  Copy-Item "src\screens\TablesAndOrderScreens.jsx" "src\screens\TablesScreen.jsx"
  Write-Host "[WARN] No se pudo separar automaticamente — usa TablesAndOrderScreens.jsx" -ForegroundColor Yellow
}

# Separar StatusScreen y KdsScreen
$statusKds = Get-Content "src\screens\StatusAndKdsScreens.jsx" -Raw
$splitPoint2 = $statusKds.IndexOf("// ══════════════════════════════════════════════════════════════════`r`n//  src/screens/KdsScreen.jsx")
if ($splitPoint2 -eq -1) {
  $splitPoint2 = $statusKds.IndexOf("// ══════════════════════════════════════════════════════════════════`n//  src/screens/KdsScreen.jsx")
}

if ($splitPoint2 -gt 0) {
  $statusOnly = $statusKds.Substring(0, $splitPoint2).Trim()
  $kdsOnly    = $statusKds.Substring($splitPoint2).Trim()
  Set-Content -Path "src\screens\StatusScreen.jsx" -Value $statusOnly -Encoding UTF8
  Set-Content -Path "src\screens\KdsScreen.jsx"    -Value $kdsOnly    -Encoding UTF8
  Write-Host "[OK] StatusScreen.jsx y KdsScreen.jsx" -ForegroundColor Green
} else {
  Copy-Item "src\screens\StatusAndKdsScreens.jsx" "src\screens\StatusScreen.jsx"
  Write-Host "[WARN] No se pudo separar automaticamente" -ForegroundColor Yellow
}

# Crear .env.local
$env = "VITE_DEVICE_TOKEN=dev-token-change-in-production`nVITE_API_BASE=http://localhost:3000"
Set-Content -Path ".env.local" -Value $env -Encoding UTF8
Write-Host "[OK] .env.local" -ForegroundColor Green

# Instalar dependencias
Write-Host "`nInstalando dependencias npm..." -ForegroundColor Cyan
npm install

Write-Host "`nSetup completo. Para iniciar la PWA:" -ForegroundColor Cyan
Write-Host "  npm run dev" -ForegroundColor White
Write-Host "`nLa PWA estara disponible en http://localhost:5173" -ForegroundColor White
Write-Host "Asegurate de que el servidor Rails este corriendo en localhost:3000" -ForegroundColor White
