Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 6010 -Protocol Http

    Add-PodeRoute -Method Get -Path "/" -ScriptBlock {
        Write-PodeJsonResponse -Value @{ "value" = "Data"}
    }
}
