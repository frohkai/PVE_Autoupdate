# Fake Windows Update API (Microsoft.Update.*) and CIM for tests/run-ps-tests.sh.
# Functions win over cmdlets, so New-Object / Get-CimInstance are replaced here.
function U($t, $kb, $cat = 'Security Updates', $ask = $false, $fail = $false) {
  $u = [pscustomobject]@{ Title = $t; KBArticleIDs = $kb; EulaAccepted = $false; IsDownloaded = $false; Fail = $fail
        InstallationBehavior = [pscustomobject]@{ CanRequestUserInput = $ask }; Categories = @([pscustomobject]@{ Name = $cat }) }
  $u | Add-Member ScriptMethod AcceptEula { $this.EulaAccepted = $true }
  $u
}
$global:UPD = @(
  (U '2026-10 Cumulative Update for Windows 11 (KB5044284)' @('5044284')),
  (U 'Defender | Security Intelligence' @('2267602')),
  (U 'Windows 11, version 25H2' @('5050000') 'Upgrades'),
  (U 'Needs a click' @('1') 'Updates' $true),
  (U 'Broken .NET update' @('5044999') 'Updates' $false $true),
  (U 'Store app without KB' @())
)
function New-Object { param([string]$ComObject, [Parameter(Position = 0)]$TypeName, [Parameter(Position = 1)]$A)
  switch ($ComObject) {
    'Microsoft.Update.UpdateColl' { return , ([System.Collections.ArrayList]::new()) }
    'Microsoft.Update.Session' {
      $s = [pscustomobject]@{ ClientApplicationID = '' }
      $s | Add-Member ScriptMethod CreateUpdateSearcher { $o = [pscustomobject]@{}; $o | Add-Member ScriptMethod Search { param($q) $global:Q = $q; if ($env:WUFAIL) { throw 'Exception from HRESULT: 0x8024402C' }; [pscustomobject]@{ Updates = $global:UPD } }; $o }
      $s | Add-Member ScriptMethod CreateUpdateDownloader { $o = [pscustomobject]@{ Updates = $null }; $o | Add-Member ScriptMethod Download { foreach ($u in $this.Updates) { $u.IsDownloaded = $true } }; $o }
      $s | Add-Member ScriptMethod CreateUpdateInstaller { $o = [pscustomobject]@{ Updates = $null }
        $o | Add-Member ScriptMethod Install { $ups = $this.Updates; $r = [pscustomobject]@{ RebootRequired = $true; U = $ups }
          $r | Add-Member ScriptMethod GetUpdateResult { param($k) [pscustomobject]@{ ResultCode = $(if ($this.U[$k].Fail) { 4 } else { 2 }) } }; $r }; $o }
      return $s }
    default { return $null }
  }
}
function Get-CimInstance { param([Parameter(Position = 0)]$Class, $Filter)
  if ($Class -eq 'Win32_OperatingSystem') { return [pscustomobject]@{ Caption = 'Microsoft Windows 11 Pro'; Version = '10.0.26100'; LastBootUpTime = [datetime]'2026-10-20T03:00:00' } }
  $global:F = $Filter
  @('Spooler', 'sppsvc', 'W32Time') | ForEach-Object { [pscustomobject]@{ Name = $_ } }
}
