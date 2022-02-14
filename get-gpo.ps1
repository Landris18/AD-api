$Reports = Get-GPO -All | Get-GPOReport -ReportType Xml
$DriveMappings = @()
ForEach ($Report In $Reports) {
  $GPO = ([xml]$Report).GPO
  ForEach ($ExtensionData In $GPO.User.ExtensionData) {
    If ($ExtensionData.Name -eq "Drive Maps") {
      $Mappings = $ExtensionData.Extension.DriveMapSettings.Drive
      ForEach ($Mapping In $Mappings) {
        $DriveMapping = New-Object PSObject -Property @{
          letter = $Mapping.Properties.Letter
          label = $Mapping.Properties.label
          path = $Mapping.Properties.Path
        }
        $DriveMappings += $DriveMapping
      }
    }
  }
}
Write-Output $DriveMappings
