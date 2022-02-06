'En cas erreur le script continue
 On error resume next
 
 ' Declaration des variables
 Dim WshNetwork,oShell
 
 ' Declaration des objets
 Set WshNetwork = WScript.CreateObject("WScript.Network")
 Set oShell = CreateObject("WScript.Shell")
 
 
 ' Mappage du lecteur P 
 If isMember("Grp_Partage_RW") Then
      WshNetwork.MapNetworkDrive "P:", "\\LAB-AD1\partage", true
 End If

 
 Function IsMember(groupName)
     If IsEmpty(groupListD) then
         Set groupListD = CreateObject("Scripting.Dictionary")
         groupListD.CompareMode = 1
         ADSPath = EnvString("userdomain") & "/" & EnvString("username")
         Set userPath = GetObject("WinNT://" & ADSPath & ",user")
         For Each listGroup in userPath.Groups
             groupListD.Add listGroup.Name, "-"
         Next
     End if
     IsMember = CBool(groupListD.Exists(groupName))
 End Function
 
 
 Function EnvString(variable)     
     variable = "%" & variable & "%"
     EnvString = oShell.ExpandEnvironmentStrings(variable)
 End Function
