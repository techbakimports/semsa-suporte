try {
    $null = [scriptblock]::Create((Get-Content 'suporte.ps1' -Raw))
    Write-Host 'PARSED_OK'
} catch {
    Write-Host "FAILED: $($_.Exception.Message)"
}
