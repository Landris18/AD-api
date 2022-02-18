# Récupération du nom de la machine (Le serveur) 
$hostname = hostname.exe

# Importation des modules dans la session su serveur
$s = New-PSSession -ComputerName $hostname
Invoke-Command -ScriptBlock {Import-Module -Name ActiveDirectory} -Session $s
Invoke-Command -ScriptBlock {Import-Module -Name NTFSSecurity} -Session $s


# Démarrer le serveur api
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

        return ConvertTo-PodeJwt -Header $header -Payload $payload -Secret (Get-PodeConfig).Secret
    }


    # Fonction permettant de décoder un token JWT pour avoir les données
    Function decodeToken{

        param($token)

        try{
            return ConvertFrom-PodeJwt -Token $token -Secret (Get-PodeConfig).Secret
        }
        catch{
            return @{sub = 0}
        }
    }


    # Fonction permettant de récupérer tous les lecteurs
    Function get_all_drives {
        $Reports = Get-GPO -All | Get-GPOReport -ReportType Xml
        $DriveMappings = @()
        ForEach ($Report In $Reports) {
            $GPO = ([xml]$Report).GPO
            ForEach ($ExtensionData In $GPO.User.ExtensionData) {
                If ($ExtensionData.Name -eq "Drive Maps") {
                    $Mappings = $ExtensionData.Extension.DriveMapSettings.Drive
                    ForEach ($Mapping In $Mappings) {
                        $DriveMapping = New-Object PSObject -Property @{
                            letter = $Mapping.Properties.Letter;
                            label = $Mapping.Properties.label;
                            path = $Mapping.Properties.Path;
                        }
                        $DriveMappings += $DriveMapping
                    }
                }
            }
        }
        return $DriveMappings
    }


    # Fonction permettant de convertir les droits hérités en droit explicites
    Function convertRight {
        param($path)
        Disable-NTFSAccessInheritance -Path $path -RemoveInheritedAccessRules
    }


    # Fonction permettant de récupérer tous les dossiers des lecteurs et leurs accès
    Function get_all_folders_access {

        # Récupération des groupes dans l'annuaire dans l'OU Futurmap DATA
        $groupList = Get-ADGroup -Filter * -SearchBase "OU=Futurmap DATA,DC=server-ad,DC=map" | Select-Object Name, SamAccountName
        $drives = get_all_drives

        $toor = @()

        foreach($d in $drives) {
          $root = @()
          foreach($group in $groupList){
      
            $account = $group.SamAccountName
      
            # Récupération des accès sur les dossiers
            $access_eff = Get-ChildItem -Path $d.path | Get-NTFSEffectiveAccess -Account "SERVER-AD\$account" | Select-Object Account,Fullname,AccessRights
      
            foreach ($doss in $access_eff){

                convertRight($doss.FullName)
                
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
          $toor = $toor + @{
              $d.label = $root
          }
         
        }
        return $toor
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

    
    # Authentification sur l'active directory pour récupérer un token JWT
    Add-PodeRoute -Method Post -Path '/api/login' -EndpointName $endpointname -Authentication 'Login' -ScriptBlock {

        # Récupération du nom d'utilisateur lors de la connexion
        $username = $WebEvent.Auth.User.Username

        try {
            # Création d'un token JWT à partir du nom d'utilisateur
            $token = encodeToken($username)
    
            Write-PodeJsonResponse -Value @{
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


    # La route principale du serveur
    Add-PodeRoute -Method Get -Path "/api" -EndpointName $endpointname -Authentication 'Authenticate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Bienvenu = "Vous êtes sur un serveur active directory"}
    }
    

    # Création d'un utilisateur dans l'annuaire active directory et ajout de celui-ci dans un groupe
    Add-PodeRoute -Method Post -Path '/api/create_user' -EndpointName $endpointname -ScriptBlock {
        
        try{
            # Récupération des informations sur l'utilisateur à créer
            $nom = (Get-Culture).TextInfo.ToTitleCase($WebEvent.Data.nom.ToLower())
            $prenoms = $WebEvent.Data.prenoms
            $name = "$nom $prenoms"

            $matricule = $WebEvent.Data.matricule

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
            -SamAccountName "$surnom($matricule)" `
            -Path "OU=$using:ou,DC=$using:domainName,DC=$using:domainExtension" `
            -AccountPassword (ConvertTo-SecureString -AsPlainText "win10**10" -Force) `
            -UserPrincipalName $UserPrincipalName `
            -ChangePasswordAtLogon $False `
            -Enabled $True `
            -Description $description

            # Ajouter l'utilisateur dans son groupe
            Add-ADGroupMember -Identity $poste -Members "$surnom($matricule)"

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
    Add-PodeRoute -Method Post -Path '/api/create_group' -EndpointName $endpointname -ScriptBlock {

        try{
            # Récupération des informations sur le groupe à créer
            $name = $WebEvent.Data.nom
            $access = $WebEvent.Data.access
            $description = $WebEvent.Data.commentaire

            $account = $name.replace(' ','')

            # Création du groupe
            New-ADGroup `
            -Name $name `
            -SamAccountName $account `
            -Path "OU=$using:ou,DC=$using:domainName,DC=$using:domainExtension" `
            -GroupCategory Security `
            -GroupScope Global `
            -Description $description
           
            $drives = get_all_drives

            # Ajouter les permissions de groupe aux dossiers et permettre au groupe de voir et lire les tous les lecteurs
            foreach ($ac in $access) {
                Add-NTFSAccess -Path $ac.dossier -Account "SERVER-AD\$account" -AccessRights $ac.permission -AppliesTo ThisFolderSubfoldersAndFiles
                foreach ($dr in $drives) {
                    Add-NTFSAccess -Path $dr.path -Account "SERVER-AD\$account" -AccessRights "ReadAndExecute" -AppliesTo ThisFolderOnly
                }
            }

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
    Add-PodeRoute -Method Put -Path '/api/change_user_group' -EndpointName $endpointname -ScriptBlock {

        try{
            # Récupération des informations pour changer le groupe de l'utilisateur
            $surnom = $WebEvent.Data.surnom
            $matricule = $WebEvent.Data.matricule

            $poste = $WebEvent.Data.poste
            $poste = $poste.replace(' ', '')

            # Récupération de l'ancien groupe de l'utilisateur
            $oldGroupUser = (Get-ADuser -Identity "$surnom($matricule)" -Properties memberof).memberof | Get-ADGroup | Select-Object name | Sort-Object name
            $oldGroupUser = $oldGroupUser.Name.replace(' ','')
            
            # Supprimer l'utilisateur de son ancien groupe
            Remove-ADGroupMember -Identity $oldGroupUser -Members "$surnom($matricule)" -confirm:$false

            # Ajouter l'utilisateur dans son nouveau groupe
            Add-ADGroupMember -Identity $poste -Members "$surnom($matricule)"

            Write-PodeJsonResponse -Value @{
                message = "Changement de groupe effectué avec succès" 
            }
            Set-PodeResponseStatus -Code 204 -ContentType 'application/json' -NoErrorPage
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


    # Récupération des lecteurs
    Add-PodeRoute -Method Get -Path "/api/get_all_drives" -EndpointName $endpointname -ScriptBlock {
        try {
            $drives = get_all_drives
            Write-PodeJsonResponse -Value $drives
            Set-PodeResponseStatus -Code 200 -ContentType 'application/json'
        }
        catch {
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de récupération des lecteurs" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }
    }   


    # Récupération des dossiers dans un lecteur (niveau 1)
    Add-PodeRoute -Method Get -Path "/api/get_all_drive_folders/" -EndpointName $endpointname -ScriptBlock {
        try {
            $folders = @()

            if ($WebEvent.Query['drive']) {
                $drives = get_all_drives
                if ($drives.Where({$_.label -eq $WebEvent.Query['drive'] })) {
                    $drive = $drives.Where({$_.label -eq $WebEvent.Query['drive']})
                    $dossiers = Get-ChildItem -Path $drive.path
                    foreach ($doss in $dossiers) {
                        $folders = $folders + @{
                            dossier = $doss.toString().split('\')[-1]
                            path = $doss.toString()
                        }
                    }
                }
            }

            Write-PodeJsonResponse -Value $folders
            Set-PodeResponseStatus -Code 200 -ContentType 'application/json'
        }
        catch {
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de récupération des dossiers du lecteur " 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }
    }  


    # Récupération de tous les dossiers avec leurs accès
    Add-PodeRoute -Method Get -Path "/api/get_all_folders_access" -EndpointName $endpointname -ScriptBlock {

        try {
            $folders_access = get_all_folders_access
            Write-PodeJsonResponse -Value $folders_access
            Set-PodeResponseStatus -Code 200 -ContentType 'application/json'
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


    # Donner un ou plusieurs accès à un groupe
    Add-PodeRoute -Method Post -Path "/api/grant_access" -EndpointName $endpointname -ScriptBlock {

        try {
            $poste = $WebEvent.Data.poste
            $poste = $poste.replace(' ', '')

            $dossierPath = $WebEvent.Data.dossier

            $droits =  $WebEvent.Data.droits

            # Supprimer les anciennes permissions
            Remove-NTFSAccess -Path $dossierPath -Account "SERVER-AD\$poste" -AccessRights "FullControl,Modify,ReadAndExecute,Read,Write,ListDirectory" -AppliesTo ThisFolderSubfoldersAndFiles

            # Ajouter les droits de poste sur le dossier et sous-dossiers et fichiers
            Add-NTFSAccess -Path $dossierPath -Account "SERVER-AD\$poste" -AccessRights $droits -AppliesTo ThisFolderSubfoldersAndFiles

            Set-PodeResponseStatus -Code 200 -ContentType 'application/json'
        }
        catch{
            # En cas d'erreur
            Write-Host $_
            Write-PodeJsonResponse -Value @{
                response = "Echec de changement des permissions" 
            }
            Set-PodeResponseStatus -Code 400 -ContentType 'application/json' -NoErrorPage
        }

    }


}
