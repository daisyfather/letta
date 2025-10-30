# setup_proxy.ps1

# === CONFIG ===
$proxyUrl = "http://dc2-proxyuat.seauat.com.vn:8080"
#"swg-url-proxy-https-sse.sigproxy.qq.opendns.com:443"
$noProxyList = "localhost,127.0.0.1,*.seabank.com.vn,gitlab-internal.seabank.com.vn,*.seauat.com.vn"

Write-Host "Setting environment variables..." -ForegroundColor Cyan
setx HTTP_PROXY  $proxyUrl
setx HTTPS_PROXY $proxyUrl
setx NO_PROXY    $noProxyList
setx no_proxy    $noProxyList

Write-Host "Setting environment variables for current session..." -ForegroundColor Cyan
$Env:HTTP_PROXY = $proxyUrl
$Env:HTTPS_PROXY = $proxyUrl
$Env:NO_PROXY = $noProxyList
$Env:no_proxy = $noProxyList

Write-Host "Setting Git config (global)..." -ForegroundColor Cyan
git config --global http.proxy  $proxyUrl
git config --global https.proxy $proxyUrl

Write-Host "✅ Done! Open new terminal if needed to reload environment variables." -ForegroundColor Green

# Kiểm tra kết quả
Write-Host "Current environment variables:" -ForegroundColor Yellow
Get-ChildItem Env: | Where-Object { $_.Name -match 'proxy' }
Write-Host "Git global config:" -ForegroundColor Yellow
git config --global --list | Select-String "proxy"
