Start-PodeServer {

    $address = "*"
    $port = 6010
    $protocol = "Http"
    $endpointname = "AD-api"
    $domain = "server-ad.map"
    
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn $domain -Domain 'SERVER-AD'

    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname


    # Récupérer les informations lors d'un login
    Add-PodeRoute -Method Get -Path '/info' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {
        Write-Host $WebEvent.Auth.User.Username
    }

    # La route principale du serveur
    Add-PodeRoute -Method Get -Path "/" -EndpointName $endpointname -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Welcoming = "Hello Visitor !"}
    }


    # Récupération d'un paramètre
    Add-PodeRoute -Method Get -Path '/api/users/:userId' -EndpointName $endpointname -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Name = 'Landry'
            UserId = $WebEvent.Parameters['userId']
        }
    } -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Received a user object' -ContentSchemas @{
        'application/json' = (New-PodeOAObjectProperty -Properties @(
            (New-PodeOAStringProperty -Name 'Name'),
            (New-PodeOAIntProperty -Name 'UserId')
        ))
    } -PassThru | Add-PodeOAResponse -StatusCode 404 -Description 'User not found'


    # Récupération depuis un JSON
    Add-PodeRoute -Method Post -Path '/api/users' -EndpointName $endpointname -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Name = $WebEvent.Data.name
            UserId = $WebEvent.Data.userId
        }
    } -PassThru | Set-PodeOARequest -RequestBody (
        New-PodeOARequestBody -Required -ContentSchemas @{
            'application/json' = (New-PodeOAObjectProperty -Properties @(
                (New-PodeOAStringProperty -Name 'name'),
                (New-PodeOAIntProperty -Name 'userId')
            ))
        }
    )


    # Création d'un utilisateur
    Add-PodeRoute -Method Post -Path '/api/create_user' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {
        try{
            New-ADUser `
            -Name (Get-Culture).TextInfo.ToTitleCase($WebEvent.Data.nom.ToLower())+" "+$WebEvent.Data.prenoms `
            -GivenName (Get-Culture).TextInfo.ToTitleCase($WebEvent.Data.nom.ToLower()) `
            -Surname $WebEvent.Data.surnom `
            -SamAccountName $WebEvent.Data.surnom.ToLower() `
            -AccountPassword (ConvertTo-SecureString -AsPlainText "****" -Force) `
            -UserPrincipalName $WebEvent.Data.surnom+"@"+$domain `
            -ChangePasswordAtLogon $True `
            -Enabled $True
        }
        catch{
            Write-Host $_
        }
    } 


    # Récupération d'un query (http://localhost:6010/users/?userId=12345)
    Add-PodeRoute -Method Get -Path '/users/' -EndpointName $endpointname -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Id = $WebEvent.Query['userId']
        }
    }

    # Affichage des services qui se tournent sur le serveur
    Add-PodePage -Name 'processes' -ScriptBlock {
        Get-Process
    }

}


# Try except and response

#New-ADUser `
#-Name "Rasendranirina Manankoraisina Daniel" `
#-GivenName "Rasendranirina" `
#-Surname "Daniel" `
#-SamAccountName "daniel" `
#-AccountPassword (ConvertTo-SecureString -AsPlainText "win10**18" -Force) `
#-UserPrincipalName "daniel@server-ad.map" `
#-ChangePasswordAtLogon $True `
#-Enabled $True