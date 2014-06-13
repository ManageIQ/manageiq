Add-PSSnapin Microsoft.SystemCenter.VirtualMachineManager
$ErrorActionPreference = "stop"
$server, $userid, $pwd, $out_file = $args[0], $args[1], $args[2], $args[3]
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pwd))
$cred = New-Object System.Management.Automation.PsCredential $userid, (convertto-securestring $decoded -asplaintext -force)
$d = @{}
$d['vmm_server'] = Get-VMMServer $server -credential $cred
$d['vm_host'] = Get-VmHost
$d['vm'] = Get-VM
$d | export-clixml -Encoding UTF8 -Path $out_file
