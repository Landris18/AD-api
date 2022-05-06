# New-ADUser `
# -Name "Rasendranirina Manankoraisina Daniel" `
# -GivenName "Rasendranirina" `
# -Surname "Daniel" `
# -SamAccountName "Daniel(507)" `
# -AccountPassword (ConvertTo-SecureString -AsPlainText "**" -Force) `
# -UserPrincipalName "daniel@server-ad.map" `
# -ChangePasswordAtLogon $True `
# -Enabled $True

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
# }

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

# Création de la variable d'environnement SECRET pour la création de JWT
# $value = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
# $env:SECRET = $value


# Get-Variable -Exclude PWD, *Preference | Remove-Variable -EA 0
 
# $keyList = @()
# $keyList = , @("erpa", "pol1234+")
# $keyList += , @("info", "blabala")


# $keyOwner = $null
 
# #Cheking key
 
# function getKeyOwner($key) {
#     $keyOwner = $null

#     foreach ($keyName in $keyList) {	
#         if ($keyName[1] -eq $key ) {
#             $keyOwner = $keyName[0]
#         }	
#     }
#     return $keyOwner

# }

 
# function isFoldersOk($templateDir, $template, $projectDest, $projectName) {

#     $result = ""

#     write-host "testing if folders exit"
#     $templatePath = $templateDir + "\" + $template


#     $projectPath = $projectDest + "\" + "$projectName"

#     if (test-path $templateDir) {

#         #template dir ok
#         if (test-path $templatePath) {

#             #template exist
#             if (test-path $projectDest) {

#                 #destination exit
#                 if (-not ([string]::IsNullOrEmpty($projectName))) {     

#                     #impunt correct
#                     $projectpath = $projectDest + "\" + $projectName

#                     if (Test-Path $projectpath)
#                     {
                    
#                         Write-Error "Project already exist"
#                         $result = "705"

                                
#                         $msg = “Dossier de projet existe déja:" + $projectName
#                         $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#                         $msg = $msg + $add
#                         Write-EventLog -LogName Application -EventId 705 -EntryType Error -Source "ProjectCreator" -Message $msg
                            
#                     }
#                     else {

#                         write-host "imput correct"
#                         $result = "0"
#                         #if project already exist    
#                     }



                                                                                        

#                 }
#                 else {
#                     #no Project name
#                     write-host "Project name not valid: " +$projectName

#                     $msg = “Nom de projet non valide:" + $projectName
#                     $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#                     $msg = $msg + $add
#                     Write-EventLog -LogName Application -EventId 704 -EntryType Error -Source "ProjectCreator" -Message $msg
#                     $result = "704"
#                 }
                        


#             }
#             else {
                

#                 #project destination not found
#                 write-host "Project destination not found " + $projectDest

#                 $result = "703"
#                 $msg = “Destination non trouvé :" + $projectDest
#                 $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#                 $msg = $msg + $add

#                 Write-EventLog -LogName Application -EventId 703 -EntryType Error -Source "ProjectCreator" -Message $msg
#             }





#         }
#         else {
#             write-host "Template folder not found : $templatePath"

#             #template folder not found
#             $msg = “Template non trouvé :" + $template
#             $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#             $msg = $msg + $add
#             Write-EventLog -LogName Application -EventId 702 -EntryType Error -Source "ProjectCreator" -Message $msg

#             $result = "702"
#         }

#     }else {

#         #template dir not ok

#         write-host   "TemplateDir not found : " +$templateDir
#         $result = "701"

                
#         $result = "702"
#         $msg = “Emplacement des templates non trouvé :" + $templateDir
#         $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#         $msg = $msg + $add
#         Write-EventLog -LogName Application -EventId 701 -EntryType Error -Source "ProjectCreator" -Message $msg
	
#     }



#     write-host $result

#     return $result
# }
   
   
#     function isPortUsed($port) {




#     }

  

#     $codeblock = {

#         param($templateDir, $template, $projectDest, $projectName, $request)


#         function copyWithAcl($templateDir, $template, $projectDest, $projectName) {	

#             $templatePath = $templateDir + "\" + $template


#             $projectPath = $projectDest + "\" + "$projectName"


         
#             $contentList = New-Object System.Collections.ArrayList
	
#             $contentList = Get-ChildItem -Path $templatePath -Recurse | select -ExpandProperty fullname

#             #copy
#             Write-Host "copying folder"
#             Write-Error "a"
#             Copy-Item $templatePath -Destination $projectPath -Recurse   


#             Write-Error "b"     
#             #Acl assignation 
   
#             #set acl of the project dir
#             Write-Host "applying ACL"
   
   
#             get-acl $templatePath | Set-Acl $projectPath
#             Write-Error "c"
#             #set acl of content

#             foreach ($citem in $contentList) {
              
#                 $pre = $citem
#                 $mirror = ($pre -replace [regex]::Escape($templatePath), $projectPath)

      
#                 get-acl $citem | Set-Acl $mirror
#             }
 
#             Write-error "Copy done"	

 

#             $rst = "0"
#             return $rst
#         }
#         $projectPath = $projectDest + "\" + "$projectName"
#         if (Test-Path $projectpath)
#         {
#             Write-Error "Project already exist"
#             $message = "705"
#         }
#         else {


#             $message = copyWithAcl -templateDir $templateDir -template $template -projectDest $projectDest -projectName $projectName
#             $msg = “Projet : " + $projectName + " créé dans " + $projectDest + " à partir de " + $template 
#             $add = " requette: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()
#             $msg = $msg + $add
#             Write-Error "c"
#             Write-EventLog -LogName Application -EventId 0 -EntryType Information -Source "ProjectCreator" -Message $msg

#         }

#     }



#     function processRequest($request) {

#         # Break from loop if GET request sent to /end
	
   
#         $addi = " requette recu: " + $request.Url.ToString() + "     source:" + $request.RemoteEndPoint.ToString()

#         Write-EventLog -LogName Application -EventId 1 -EntryType Information -Source "ProjectCreator" -Message $addi

	
#         Write-Host "processing request"
	
#         if ($request.Url -match '/end$') {
#             $message = "quitting service";
#             $response.ContentType = 'text/html' ; 
#             break 
#         } 
#         else {
 
#             # Split request URL to get command and options
#             $requestvars = ([String]$request.Url).split("?");        
#             $param1 = $requestvars[0].split("/")
#             $param2 = $requestvars[1].split("&")
		
#             $app = $param1[3]
#             $action = $param1[4]
		
#             Write-Host "app=" $app
#             Write-Host "action=" $action
#             Write-Host "param2=" $param2
		
		    
#             if ( $request.HttpMethod -eq "GET") {
#                 switch ( $app ) { 
           
#                     "erp" {		   	         			 
				
#                         if ($action -eq "create") {				
#                             Write-Host "creating project"
#                             $parameters = [ordered]@{}
					
#                             foreach ($ligne in $param2 ) {
					
#                                 $po = $ligne.Split("=")					
#                                 $parameters.add($po[0], $po[1])
					 
#                             }
										
#                             $templateDir = $parameters["templateDir"]
#                             $template = $parameters["template"]
#                             $projectDest = $parameters["projectDest"]
#                             $projectName = $parameters["projectName"]
					
#                             $templateDir = $templateDir -replace "%5C", "\"
#                             $template = $template -replace "%5C", "\"
#                             $projectDest = $projectDest -replace "%5C", "\"
#                             $projectName = $projectName -replace "%5C", "\"

#                             Write-Host "templateDir=" $templateDir
#                             Write-Host "template="     $template
#                             Write-Host "projectDest="  $projectDest
#                             Write-Host "projectName="  $projectName
                    
#                             #----------------------------
					
#                             #$message=copyWithAcl -templateDir $templateDir -template $template -projectDest $projectDest -projectName $projectName	


#                             $message = isFoldersOk -templateDir $templateDir -template $template -projectDest $projectDest -projectName $projectName
   
#                             write-host "test if ok"
#                             if ($message -eq "0") {
  
#                                 write-host "ok continue"
#                                 Start-Job -ScriptBlock $codeblock -Name $projectName -ArgumentList $templateDir, $template, $projectDest, $projectName, $request
#                             }
                       
				 

#                         }
#                         else {
									
#                             $message = "erreur:Action inconne"					
#                             $response.ContentType = 'application/json';
        					   			  					
#                             default {
 
#                                 # If no matching subdirectory/route is found generate a 404 message
#                                 $message = "-";
#                                 $response.ContentType = 'text/html' ;
#                             }
			
			
			
			
#                         } 
	     
		 

       
#                     }
#                 }

        
#             }
#             else {
        
#                 $message = ""
#                 write-host "not GET" + $response.HttpMethod
        
#             }             





#             # If a request is sent to http:// :8888/erp
       
#         }

#         write-host "message = " $message
#         # Convert the data to UTF8 bytes
#         [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
       
#         # Set length of response
#         $response.ContentLength64 = $buffer.length
       
#         # Write response out and close
#         $output = $response.OutputStream
#         $output.Write($buffer, 0, $buffer.length)
#         $output.Close()

#     }


#     # Create a listener on port 8000

#     $listener = New-Object System.Net.HttpListener
#     $listener.Prefixes.Add('http://+:8888/') 
#     $listener.Start()
#     Write-Host "litenening...."
  
  
#     # Run until you send a GET request to /end
#     while ($true) {

#         $context = $listener.GetContext() 
 
#         # Capture the details about the request
#         $request = $context.Request
 
#         # Setup a place to deliver a response
#         $response = $context.Response
   
#         $response.AddHeader("Access-Control-Allow-Origin", '*'); 
#         $response.AddHeader("Access-Control-Allow-Headers", '*'); 
   	

#         $response.AddHeader("Access-Control-Allow-Methods", '*');
	
#         #$key = $request.Headers['x-api-key']
	
	
#         #$keyOwner = getKeyOwner($key)
  
  
#         #if ($keyOwner -eq $null){
#         #Key not valid
#         #	Write-Host "warning: key not valid"		
				
#         #}else{
#         #Key valid 
#         #	Write-Host "info: key owner is"  $keyOwner
		
#         #	processRequest($request)
		
		
				
	
#         #}
#         processRequest($request) 
#     }

#     #Terminate the listener
#     $listener.Stop()
#     Write-Host "listner closed"