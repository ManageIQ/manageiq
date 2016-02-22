import-module virtualmachinemanager
$diskvols = @{}

function get_vms($vms){
  $results = @{}

  $vms | ForEach {
    $vm_hash = @{}
    $id = $_.ID

    $vm_hash["Properties"] = $_
    $vm_hash["Networks"] = $_.VirtualNetworkAdapters.IPv4Addresses
    $vm_hash["DVDs"] = $_.VirtualDVDDrives | Select -Expand ISO
    $vm_hash["vmnet"] = $_.VirtualNetworkAdapters | Select VMNetwork
    $results[$id]= $vm_hash
  }

  return $results
}

function get_images($ims){
  $results = @{}

  $ims | ForEach {
    $i_hash = @{}
    $id = $_.ID
    $i_hash["Properties"] = $_
    $i_hash["DVDs"] = $_.VirtualDVDDrives | Select -Expand ISO
    $i_hash["vmnet"] = $_.VirtualNetworkAdapters | Select VMNetwork
    $results[$id]= $i_hash
  }

  return $results
}

function get_host_inventory($hosts) {
  $results = @{}

  $hosts | ForEach {
    $h_hash = @{}
    $h_hash["NetworkAdapters"] = @(Get-VMHostNetworkAdapter -VMHost $_)
    $h_hash["VirtualSwitch"] = @(Get-SCVirtualNetwork -VMHost $_)
    $h_hash["Properties"] = $_
    $results[$_.ID] = $h_hash
    $_.DiskVolumes | where-object VolumeLabel -ne "System Reserved" | ForEach {
      $diskvols[$_.ID]=$_
    }
  }

  return $results
}

function get_clusters($clusters) {
  $results = @{}

  $clusters | ForEach {
    $c_hash = @{}
    $c_hash["Properties"] = $_
    $results[$_.ID] = $c_hash
  }

  return $results
}

$r = @{}
$v = Get-SCVirtualMachine -VMMServer "localhost"

$r["vms"] = get_vms($v)

$i = Get-SCVMTemplate -VMMServer "localhost"
$r["images"] = get_images($i)

$h = Get-SCVMHost -VMMServer "localhost"
$r["hosts"] = get_host_inventory($h)
$r["datastores"] = $diskvols

$c = Get-SCVMHostCluster -VMMServer "localhost"
$r["clusters"] = get_clusters($c)

$e = Get-SCVMMServer -ComputerName "localhost"
$r["ems"] = $e

$inFile = [System.IO.Path]::GetTempFileName()
$outFile = $inFile + '.gz'

Export-CLIXML -Input $r -Path $inFile -Encoding UTF8

$in = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
$buf = New-Object byte[]($in.Length)
$x = $in.Read($buf, 0, $in.Length)
$in.Dispose()

$out = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)

$gStream = New-Object System.IO.Compression.GzipStream $out, ([IO.Compression.CompressionMode]::Compress)
$x = $gStream.Write($buf, 0, $buf.Length)
$gStream.Dispose()
$out.Dispose()

[System.convert]::ToBase64String([System.IO.File]::ReadAllBytes($outFile))

Remove-Item -Force $inFile
Remove-Item -Force $outFile
