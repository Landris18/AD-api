' En cas d'erreur le script continue
On error resume next 
' Declaration des variables 
Dim WshNetwork 
' Declaration des objets 
Set WshNetwork = WScript.CreateObject("WScript.Network") 
' Mappage du lecteur P 
WshNetwork.MapNetworkDrive "P:", "\\LAPTOP\partage", true
