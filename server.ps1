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

    # Création de la variable d'environnement SECRET pour la création de JWT
    $value = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
    $env:SECRET = $value

    # Récupération de la variable d'environnement SECRET 
    $secret = $env:SECRET

    # Déclaration de la GPO
    $thePath = "C:\Users\Administrateur\Documents\SHARED"

    # Récupération des groupes dans l'annuaire dans l'OU Futurmap DATA
    $groupList = Get-ADGroup -Filter * -SearchBase "OU=Futurmap DATA,DC=server-ad,DC=map" | Select-Object Name, SamAccountName
    
    # Lister les dossiers dans la GPO
    $dossiers = Get-ChildItem $thePath | Select-Object FullName


    # Fonction permettant de convertir les droits hérités en droit explicites
    Function convertRight {
        param($none)
        foreach($doss in $dossiers){
            # Convertir les droits hérités en droits explicites sur les dossiers
            icacls $doss.FullName /inheritance:d
        }
    }
    convertRight("none")
    

    # Fonction permettant d'encoder les données pour avoir un token JWT
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

        return ConvertTo-PodeJwt -Header $header -Payload $payload -Secret $env:SECRET
    }


    # Fonction permettant de décoder un token JWT pour avoir les données
    Function decodeToken{

        param($token)

        try{
            return ConvertFrom-PodeJwt -Token $token -Secret $env:SECRET
        }
        catch{
            return @{sub = 0}
        }
    }


    # Activation session
    Enable-PodeSessionMiddleware


    # Création d'un endpoint pour accèder aux routes
    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname


    # Authentification sur l'active directory
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Users @('Administrateur') -Fqdn $domain -Domain $authAdDomain


    # Authentification Bearer utilisant un token JWT
    New-PodeAuthScheme -Bearer -AsJWT -Secret $secret | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {

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


    # La route principale du serveur
    Add-PodeRoute -Method Get -Path "/api" -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Bienvenu = "Vous êtes sur un serveur active directory"}
    }

    
    # Authentification sur l'active directory pour récupérer un token JWT
    Add-PodeRoute -Method Post -Path '/api/login' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {

        # Récupération du nom d'utilisateur lors de la connexion
        $username = $WebEvent.Auth.User.Username

        try {
            # Création d'un token JWT à partir du nom d'utilisateur
            $token = encodeToken($username)
    
            Write-PodeJsonResponse -Value @{
                message = "$username est connecté" 
                token = $token
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


    # Création d'un utilisateur dans l'annuaire active directory et ajout de celui-ci dans un groupe
    Add-PodeRoute -Method Post -Path '/api/create_user' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        
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
            -AccountPassword (ConvertTo-SecureString -AsPlainText "win10**10" -Force) `
            -UserPrincipalName $UserPrincipalName `
            -ChangePasswordAtLogon $False `
            -Enabled $True `
            -Description $description

            # Ajouter l'utilisateur dans son groupe
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


    # Création d'un groupe dans l'annuaire active directory
    Add-PodeRoute -Method Post -Path '/api/create_group' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {

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

            $account = $name.replace(' ','')

            # Ajouter les droits minimum pour voir et lire le GPO
            Add-NTFSAccess -Path $using:thePath -Account "SERVER-AD\$account" -AccessRights Synchronize Read -AppliesTo ThisFolderOnly

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


    # Changement de groupe d'un utilisateur dans l'annuaire active directory
    Add-PodeRoute -Method Put -Path '/api/change_user_group' -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {

        try{
            # Récupération des informations pour changer le groupe de l'utilisateur
            $surnom = $WebEvent.Data.surnom
            $surnomLower = $surnom.ToLower()

            $poste = $WebEvent.Data.poste
            $poste = $poste.replace(' ', '')

            $oldGroupUser = (Get-ADuser -Identity $surnomLower -Properties memberof).memberof | Get-ADGroup | Select-Object name | Sort-Object name
            $oldGroupUser = $oldGroupUser.Name.replace(' ','')
            
            # Supprimer l'utilisateur de son ancien groupe
            Remove-ADGroupMember -Identity $oldGroupUser -Members $surnomLower -confirm:$false

            # Ajouter l'utilisateur dans son nouveau groupe
            Add-ADGroupMember -Identity $poste -Members $surnomLower

            Write-PodeJsonResponse -Value @{
                message = "Changement de groupe effectué avec succès" 
            }
            Set-PodeResponseStatus -Code 204 -ContentType 'application/json'
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de changement de groupe" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }
    }


    # Récupération des dossiers et des accès
    Add-PodeRoute -Method Get -Path "/api/folders" -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {

        try {

            # Initialisation des dossiers et accès
            $root = @()

            foreach($group in $using:groupList){

                $account = $group.SamAccountName

                # Récupération des accès sur les dossiers
                $access_eff = Get-ChildItem -Path $using:thePath | Get-NTFSEffectiveAccess -Account "SERVER-AD\$account" | Select-Object Account,Fullname,AccessRights

                foreach ($doss in $access_eff){
                    
                    if ($root.Count -gt 0){
                        $pare = $true
                        foreach($r in $root){
                            if ($r.dossier -eq $doss.Fullname){
                                $r.Access = $r.Access + @{
                                    account = $group.Name;
                                    permission = $doss.AccessRights.ToString();
                                }
                                $pare = $false
                                break
                            }
                        }
                        if ($pare -eq $true){
                            $root = $root + 
                            @{
                                Dossier = $doss.Fullname;
                                Access = @(
                                    @{
                                        account = $group.Name;
                                        permission = $doss.AccessRights.ToString();
                                    }
                                )
                            }
                        }
                    }
                    else{
                        $root = $root + @{
                            Dossier = $doss.Fullname;
                            Access = @(
                                @{
                                    account = $group.Name;
                                    permission = $doss.AccessRights.ToString();
                                }
                            )
                        }
                    }
                }
            }

            Write-PodeJsonResponse -Value $root
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de la récupération des dossiers et des accès" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }

    }
}
