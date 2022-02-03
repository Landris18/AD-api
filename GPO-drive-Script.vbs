' En cas erreur le script continue
On error resume next 

' Declaration des variables 
Dim WshNetwork 

' Declaration des objets 
Set WshNetwork = WScript.CreateObject("WScript.Network") 

' Mappage du lecteur P 
WshNetwork.MapNetworkDrive "P:", "\\LAB-AD1\partage", true
