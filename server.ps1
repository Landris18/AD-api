Start-PodeServer {

    $address = "*"
    $port = 6010
    $protocol = "Http"
    $endpointname = "AD-api"
    $domain = "server-ad.map"
    
    Function encodeToken{
        # Encoder des données pour avoir un token jwt

        param($username)

        $header = @{
            alg = 'hs256'
            typ = 'JWT'
        }
        
        $payload = @{
            sub = $username
            name = $username
            exp = ([System.DateTimeOffset]::Now.AddDays(1).ToUnixTimeSeconds())
        }

        return ConvertTo-PodeJwt -Header $header -Payload $payload -Secret "SECRET"
    }

    Function decodeToken{
        # Decoder un token pour avoir des données

        param($token)

        try{
            return ConvertFrom-PodeJwt -Token $token -Secret "SECRET"
        }
        catch{
            return @{sub = 0}
        }
    }


    # Session expiration in hours
    Enable-PodeSessionMiddleware -Duration 0

    # Creating an endpoint for routes
    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname

    # Active directory authentication
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn $domain -Domain 'SERVER-AD'

    # Bearer authorization with a jwt token
    New-PodeAuthScheme -Bearer -AsJWT -Secret "SECRET" | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($payload)

        if ($payload) {
            return @{
                User = @{
                    user = $payload
                }
            }
        }

        return $null
    }


    # Authentification par un compte AD pour récupérer un token
    Add-PodeRoute -Method Get -Path '/api/login' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {
        $username = $WebEvent.Auth.User.Username

        try {
            $token = encodeToken($username)
    
            Write-PodeJsonResponse -Value @{
                message = "$username connected" 
                AccessToken = $token
            }
        }
        catch{
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                message = "Authentication Failed" 
            }
        }
    }


    # La route principale du serveur
    Add-PodeRoute -Method Get -Path "/" -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Welcome = "This is an AD-Server"}
    }


	# Création d'un utilisateur
    Add-PodeRoute -Method Post -Path '/api/create_user' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        try{
            $nom = (Get-Culture).TextInfo.ToTitleCase($WebEvent.Data.nom.ToLower())
            $prenoms = $WebEvent.Data.prenoms
            $name = "$nom $prenoms"

            $surnom = $WebEvent.Data.surnom
            $surnomLower = $surnom.ToLower()
            $domain = "server-ad.map"
            $UserPrincipalName = "$surnomLower@$domain"
            $description = $WebEvent.Data.commentaire

            $poste = $WebEvent.Data.poste.replace(' ','')

            New-ADUser `
            -Name $name `
            -GivenName $nom `
            -Surname $surnom `
            -SamAccountName $surnomLower `
            -Path "OU=Futurmap DATA,DC=server-ad,DC=map" `
            -AccountPassword (ConvertTo-SecureString -AsPlainText "****" -Force) `
            -UserPrincipalName $UserPrincipalName `
            -ChangePasswordAtLogon $True `
            -Enabled $True `
            -Description $description

            Add-ADGroupMember -Identity $poste -Members $surnomLower
        }
        catch{
            Write-Host $_
        }
    } 


    # Création d'un groupe
    Add-PodeRoute -Method Post -Path '/api/create_groupe' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        try{
            $name = $WebEvent.Data.nom
            $description = $WebEvent.Data.commentaire

            New-ADGroup `
            -Name $name `
            -SamAccountName $name.replace(' ','') `
            -Path "OU=Futurmap DATA,DC=server-ad,DC=map" `
            -GroupCategory Security `
            -GroupScope Global `
            -Description $description
        }
        catch{
            Write-Host $_
        }
    }

}

# Response
# Comprendre les variables globales
# Mettre le secret dans une variable d'environnement