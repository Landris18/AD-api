$Reports = Get-GPO -All | Get-GPOReport -ReportType Xml
$DriveMappings = @()
ForEach ($Report In $Reports) {
  $GPO = ([xml]$Report).GPO
  $LinkCount = ([string[]]([xml]$Report).GPO.LinksTo).Count
  $Enabled = $GPO.User.Enabled
  ForEach ($ExtensionData In $GPO.User.ExtensionData) {
    If ($ExtensionData.Name -eq "Drive Maps") {
      $Mappings = $ExtensionData.Extension.DriveMapSettings.Drive
      ForEach ($Mapping In $Mappings) {
        $DriveMapping = New-Object PSObject -Property @{
          GPO         = $GPO.Name
          LinkCount   = $LinkCount
          Enabled     = $Enabled
          DriveLetter = $Mapping.Properties.Letter + ":"
          Label       = $Mapping.Properties.label
          Path        = $Mapping.Properties.Path
        }
        $DriveMappings += $DriveMapping
      }
    }
  }
}
Write-Output $DriveMappings | ft GPO, LinkCount, Enabled, DriveLetter, Label, Path -AutoSize
