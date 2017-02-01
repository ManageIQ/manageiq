import-module virtualmachinemanager

$hash = @{}

$ems = Get-SCVMMServer -ComputerName localhost |
  Select @{name='Guid';expression={$_.ManagedComputer.ID -As [string]}},
    @{name='Version';expression={$_.ServerInterfaceVersion -As [string]}}

$vms = Get-SCVirtualMachine -VMMServer localhost -All |
  Select -Property BackupEnabled,BiosGuid,ComputerName,CPUCount,CPUType,DataExchangeEnabled,
    HeartbeatEnabled,HostName,ID,LastRestoredCheckpointID,Memory,Name,OperatingSystem,
    OperatingSystemShutdownEnabled,ServerConnection,TimeSynchronizationEnabled,
    VirtualDVDDrives,VirtualHardDisks,VirtualNetworkAdapters,VMCheckpoints,VMCPath,
    @{name='StatusString';expression={$_.Status -As [string]}},
    @{name='VirtualMachineStateString';expression={$_.VirtualMachineState -As [string]}},
    @{name='DVDISO';expression={ $_.VirtualDVDDrives.ISO | Select -Property Name, ID, SharePath, Size }} |
    % {
      if($_.DVDISO){ $_.DVDISO = @($_.DVDISO); $_ } # Force array context
      else{ $_ }
    }

$hosts = Get-SCVMHost -VMMServer localhost |
  Select -Property CommunicationStateString,CoresPerCPU,DiskVolumes,DVDDriveList,
    HyperVStateString,ID,LogicalProcessorCount,Name,OperatingSystem,PhysicalCPUCount,
    ProcessorFamily,ProcessorManufacturer,ProcessorModel,ProcessorSpeed,TotalMemory,
    @{name='HyperVVersionString';expression={$_.HyperVVersion -As [string]}},
    @{name='OperatingSystemVersionString';expression={$_.OperatingSystemVersion -As [string]}},
    @{name='VirtualizationPlatformString';expression={$_.VirtualizationPlatform -As [string]}}

$vnets = Get-SCVirtualNetwork -VMMServer localhost |
  Select -Property ID,Name,LogicalNetworks,VMHostNetworkAdapters,
    @{name='VMHostName';expression={$_.VMHost.Name -As [string]}}

$images = Get-SCVMTemplate -VMMServer localhost -All |
  Select -Property CPUCount,Memory,Name,ID,VirtualHardDisks,VirtualDVDDrives,
    @{name="CPUTypeString";expression={$_.CPUType.Name}},
    @{name="OperatingSystemString";expression={$_.OperatingSystem.Name}},
    @{name='DVDISO';expression={ $_.VirtualDVDDrives.ISO | Select -Property Name, ID, SharePath, Size }} |
    % {
      if($_.DVDISO){ $_.DVDISO = @($_.DVDISO); $_ } # Force array context
      else{ $_ }
    }

$clusters = @(Get-SCVMHostCluster -VMMServer localhost | Select -Property ClusterName,ID,Nodes)

$hash["ems"] = $ems
$hash["hosts"] = $hosts
$hash["vnets"] = $vnets
$hash["clusters"] = $clusters
$hash["images"] = $images
$hash["vms"] = $vms

# Maximum depth is 4 due to VMHostNetworkAdapters
ConvertTo-Json -InputObject $hash -Depth 4 -Compress
