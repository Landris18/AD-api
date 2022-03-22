@{
    Server = @{
        FileMonitor = @{
            Enable = $true
            Include = @("*.ps1")
            ShowFiles = $true
        }
    }
    #Web = @{
        #ErrorPages = @{
            #ShowExceptions = $true
        #}
    #}

    Address = "*"
    Port = 6010
    Protocol = "Http"
    EndpointName = "AD-api"
    Domain = "server-ad.map"
    OU = "Futurmap DATA"
    Secret = "THE_SECRET_KEY"
}
