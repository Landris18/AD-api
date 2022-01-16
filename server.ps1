Start-PodeServer {

    # Récupération des variables de configuration depuis le fichier server.psd1
    $address = (Get-PodeConfig).Address
    $port = (Get-PodeConfig).Port
    $protocol = (Get-PodeConfig).Protocol
    $endpointname = (Get-PodeConfig).EndpointName
    $domain = (Get-PodeConfig).Domain
    $ou = (Get-PodeConfig).OU

    $domainName = (Get-PodeConfig).Domain.split(".")[0]
    $domainExtension = (Get-PodeConfig).Domain.split(".")[1]
    $authAdDomain = (Get-PodeConfig).Domain.split(".")[0].ToUpper()

    # Récupération de la variable d'environnement SECRET 
    # Cette variable doit être créer avant le lancement du serveur avec la commande $env:SECRET="La clé secrète"
    $secret = $env:SECRET

    Function encodeToken{
        """
            DESC : Fonction permettant d'encoder les données pour avoir un token JWT
        """

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

        return ConvertTo-PodeJwt -Header $header -Payload $payload -Secret $using:secret
    }

    Function decodeToken{
        """
            DESC : Fonction permettant de décoder un token JWT pour avoir les données
        """
        # Decoder un token pour avoir des données

        param($token)

        try{
            return ConvertFrom-PodeJwt -Token $token -Secret $using:secret
        }
        catch{
            return @{sub = 0}
        }
    }


    # Activation d'une session
    Enable-PodeSessionMiddleware


    # Création d'un endpoint pour accèder aux routes
    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname


    # Authentification sur l'active directory
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn $domain -Domain $authAdDomain


    # Authentification Bearer utilisant un token JWT
    New-PodeAuthScheme -Bearer -AsJWT -Secret $secret | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        """
            DESC : Authentification Bearer utilisant un token JWT
        """

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


    Add-PodeRoute -Method Get -Path "/api" -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        """
            DESC : La route principale du serveur
        """
        Write-PodeJsonResponse -Value @{ Bienvenu = "Vous êtes sur un serveur active directory"}
    }
    

    Add-PodeRoute -Method Get -Path '/api/login' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {
        """
            DESC : Authentification sur l'active directory pour récupérer un token JWT
        """

        # Récupération du nom d'utilisateur lors de la connexion
        $username = $WebEvent.Auth.User.Username

        try {
            # Création d'un token JWT à partir du nom d'utilisateur
            $token = encodeToken($username)
    
            Write-PodeJsonResponse -Value @{
                response = "$username est connecté" 
                access_token = $token
            }
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                message = "Echec de l'authentification" 
            }
            Set-PodeResponseStatus -Code 401 -ContentType 'application/json' -NoErrorPage
        }
    }


    Add-PodeRoute -Method Post -Path '/api/create_user' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        """
            DESC : Création d'un utilisateur dans l'annuaire active directory et ajout de celui-ci dans un groupe
        """

        try{
            # Récupération des informations sur l'utilisateur à créer
            $nom = (Get-Culture).TextInfo.ToTitleCase($WebEvent.Data.nom.ToLower())
            $prenoms = $WebEvent.Data.prenoms
            $name = "$nom $prenoms"

            $surnom = $WebEvent.Data.surnom
            $surnomLower = $surnom.ToLower()
            $UserPrincipalName = "$surnomLower@$using:domain"
            $description = $WebEvent.Data.commentaire

            $poste = $WebEvent.Data.poste.replace(' ','')

            # Création de l'utilisateur
            New-ADUser `
            -Name $name `
            -GivenName $nom `
            -Surname $surnom `
            -SamAccountName $surnomLower `
            -Path "OU=$using:ou,DC=$using:domainName,DC=$using:domainExtension" `
            -AccountPassword (ConvertTo-SecureString -AsPlainText "****" -Force) `
            -UserPrincipalName $UserPrincipalName `
            -ChangePasswordAtLogon $True `
            -Enabled $True `
            -Description $description

            Add-ADGroupMember -Identity $poste -Members $surnomLower

            Write-PodeJsonResponse -Value @{
                message = "Utilisateur créé avec succès" 
            }
            Set-PodeResponseStatus -Code 201 -ContentType 'application/json'
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                message = "Echec de la création de l'utilisateur" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }
    } 


    # Création d'un groupe
    Add-PodeRoute -Method Post -Path '/api/create_groupe' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        """
            DESC : Création d'un gropupe dans l'annuaire active directory
        """

        try{
            # Récupération des informations sur le groupe à créer
            $name = $WebEvent.Data.nom
            $description = $WebEvent.Data.commentaire

            # Création du groupe
            New-ADGroup `
            -Name $name `
            -SamAccountName $name.replace(' ','') `
            -Path "OU=$using:ou,DC=$using:domainName,DC=$using:domainExtension" `
            -GroupCategory Security `
            -GroupScope Global `
            -Description $description

            Write-PodeJsonResponse -Value @{
                message = "Groupe créé avec succès" 
            }
            Set-PodeResponseStatus -Code 201 -ContentType 'application/json'
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de la création du groupe" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }
    }

}

# Folder structure and structure
# $env:VARIABLE="variable" (Creating and editing)
# Remove-Item env:variable (Removing)
# dir env: (Listing)