Start-PodeServer {

    $address = "*"
    $port = 6010
    $protocol = "Http"
    $endpointname = "AD-api"
    $domain = "server-ad.map"
    $secret = "SECRET"
    
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn $domain -Domain 'SERVER-AD'

    # JWT with signature, signed with secret :
    New-PodeAuthScheme -Bearer -AsJWT -Secret $secret | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($payload)
    }
    

    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname


    Function encodeToken{
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

        return ConvertTo-PodeJwt -Header $header -Payload $payload -Secret $secret
    }

    Function verifToken{
        param($token)

        try{
            return ConvertFrom-PodeJwt -Token $token -Secret $secret
        }
        catch{
            return @{sub = 0}
        }
    }


    # Authentification pour récupérer un token
    Add-PodeRoute -Method Get -Path '/api/login' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        $username = $WebEvent.Auth.User.Username
        if ($username -ne $null) {
            $token = encodeToken($username)
            Write-PodeJsonResponse -Value @{ token = $token}
        }
        else {
            Write-PodeJsonResponse -Value @{ status = "Echec de l'authentification"}
        }
    }


    # La route principale du serveur
    Add-PodeRoute -Method Get -Path "/" -EndpointName $endpointname -ScriptBlock {
        $token = $WebEvent.Data.token
        $username = $WebEvent.Data.username

        if (verifToken($token).sub -ne $username){
            Write-PodeJsonResponse -Value @{ Erreur = "Erreur token"}
        }

        Write-PodeJsonResponse -Value @{ Welcoming = "Hello world"}
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
    Add-PodeRoute -Method Post -Path '/api/create_groupe' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {
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


# Response
# Token on login

#New-ADUser `
#-Name "Rasendranirina Manankoraisina Daniel" `
#-GivenName "Rasendranirina" `
#-Surname "Daniel" `
#-SamAccountName "daniel" `
#-AccountPassword (ConvertTo-SecureString -AsPlainText "****" -Force) `
#-UserPrincipalName "daniel@server-ad.map" `
#-ChangePasswordAtLogon $True `
#-Enabled $True