#New-ADUser `
#-Name "Rasendranirina Manankoraisina Daniel" `
#-GivenName "Rasendranirina" `
#-Surname "Daniel" `
#-SamAccountName "daniel" `
#-AccountPassword (ConvertTo-SecureString -AsPlainText "**" -Force) `
#-UserPrincipalName "daniel@server-ad.map" `
#-ChangePasswordAtLogon $True `
#-Enabled $True

# # Récupération d'un query (http://localhost:6010/users/?userId=12345)
# Add-PodeRoute -Method Get -Path '/users/' -EndpointName $endpointname -ScriptBlock {
#     Write-PodeJsonResponse -Value @{
#         Id = $WebEvent.Query['userId']
#     }
# }

# # Récupération d'un paramètre
# Add-PodeRoute -Method Get -Path '/api/users/:userId' -EndpointName $endpointname -ScriptBlock {
#     Write-PodeJsonResponse -Value @{
#         Name = 'Landry'
#         UserId = $WebEvent.Parameters['userId']
#     }
# } -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Received a user object' -ContentSchemas @{
#     'application/json' = (New-PodeOAObjectProperty -Properties @(
#         (New-PodeOAStringProperty -Name 'Name'),
#         (New-PodeOAIntProperty -Name 'UserId')
#     ))
# } -PassThru | Add-PodeOAResponse -StatusCode 404 -Description 'User not found'

# # Affichage des services qui se tournent sur le serveur
# Add-PodePage -Name 'processes' -ScriptBlock {
#     Get-Process
# }

# $thePath = "C:\Users\Landry LD\Music"
# $dossiers = Get-ChildItem $thePath -Recurse 
# $groupList = ("LANDRIS18\Landry LD","BUILTIN\Administrateurs" )
# $access_eff = Get-ChildItem -Path $thePath | Get-NTFSEffectiveAccess -Account $group | Select-Object Account,Fullname,AccessRights 

# $env:VARIABLE="variable" (Creating and editing)
# Remove-Item env:variable (Removing)
# dir env: (Listing)

# $s = New-PSSession -ComputerName "WIN-IP4ACBPGSOO"

# Création de la variable d'environnement SECRET pour la création de JWT
# $value = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
# $env:SECRET = $value
