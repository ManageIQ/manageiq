import-module virtualmachinemanager
$diskvols = @{}

function get_vms{
 $vms = $args[0]
 $results = @{}

 $vms | ForEach-Object {
  $vm_hash = @{}
  $id = $_.ID
  
  $vm_hash["Properties"] = $_
  if ($_.StatusString -eq "Running"){
   $networks = Read-SCGuestInfo -VM $_ -Key "NetworkAddressIPv4"
   if ($networks -ne $null){
    $vm_hash["Networks"] = $networks.KvpMap["NetworkAddressIPv4"]
   }
  }
  $dvds = Get-SCVirtualDVDDrive -VM $_ | Select-Object -ExpandProperty "ISO"
  $vm_hash["DVDs"] = $dvds
  $results[$id]= $vm_hash
 }
 return $results
}

function get_images{
 $ims = $args[0]
 $results = @{}

 $ims | ForEach-Object {
  $i_hash = @{}
  $id = $_.ID
  $i_hash["Properties"] = $_
  $dvds = Get-SCVirtualDVDDrive -VMTemplate $_ | Select-Object -ExpandProperty "ISO"
  $i_hash["DVDs"] = $dvds
  $results[$id]= $i_hash
 }
 return $results
}

function get_host_inventory {
 $results = @{}
 $hosts = $args[0]
 $hosts | ForEach-Object {
  $host_hash = @{}
  $host_hash["NetworkAdapters"] = @(Get-VMHostNetworkAdapter -VMHost $_)
  $host_hash["Properties"] = $_
  $results[$_.ID] = $host_hash
  $_.DiskVolumes | where-object VolumeLabel -ne "System Reserved" | ForEach-Object {
    $diskvols[$_.ID]=$_
  }
 }
 return $results
}

function get_clusters {
 $results = @{}

 $clusters = $args[0]
 $clusters | ForEach-Object {
  $cluster_hash = @{}
  $cluster_hash["Properties"] = $_
  $results[$_.ID] = $cluster_hash

 }
 return $results
}

$file = [System.IO.Path]::GetTempFileName()
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

$e = Get-VMMServer -ComputerName "localhost"
$r["ems"] = $e

$r | Export-CLIXML -path $file -encoding UTF8
get-content $file
$file.close


