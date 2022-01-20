' En cas d'erreur le script continue
On error resume next 
' Déclaration des variables 
Dim WshNetwork 
' Déclaration des objets 
Set WshNetwork = WScript.CreateObject("WScript.Network") 
' Mappage du lecteur P 
WshNetwork.MapNetworkDrive "P:", "\\LAPTOP\partage", true
