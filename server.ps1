Start-PodeServer {

    $address = "*"
    $port = 6010
    $protocol = "Http"
    $endpointname = "AD-api"


    Add-PodeEndpoint -Address $address -Port $port -Protocol $protocol -Name $endpointname

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


# Authentication active directory
# Try except and response
# Connect to a database for training (PostgreSQL)