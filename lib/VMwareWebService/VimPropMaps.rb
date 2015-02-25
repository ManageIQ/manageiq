module VimPropMaps
	FullPropMap = {
	    :VirtualMachine            => {
	        :baseName   => "@virtualMachines",
	        :keyPath    => "['summary']['config']['vmPathName']",
			:keyPath2	=> "['summary']['config']['vmLocalPathName']",
	        :props      => ["summary","config","guest","resourceConfig","parent","snapshot","datastore","resourcePool","availableField"]
	    },
	    :ComputeResource           => {
	        :baseName   => "@computeResources",
	        :keyPath    => "['name']",
	        :props      => ["name","summary","parent","host","resourcePool"]
	    },
	    :ClusterComputeResource    => {
	        :baseName   => "@clusterComputeResources",
	        :keyPath    => "['name']",
	        :props      => ["name","summary","parent","host","resourcePool","configuration"]
	    },
	    :ResourcePool              => {
	        :baseName   => "@resourcePools",
	        :keyPath    => nil, # by mor only
	        :props      => ["name","summary.config","resourcePool","owner","parent","vm"] # childConfiguration currently has a problem updating.  See FB3269
	    },
	    :Folder                    => {
	        :baseName   => "@folders",
	        :keyPath    => "['name']",
	        :props      => nil
	    },
	    :Datacenter                => {
	        :baseName   => "@datacenters",
	        :keyPath    => "['name']",
	        :props      => nil
	    },
	    :HostSystem                => {
	        :baseName   => "@hostSystems",
	        :keyPath    => "['summary']['config']['name']",
	        :props      => [
					"summary",
					"datastore",
					"capability.maintenanceModeSupported",
					"capability.nfsSupported",
					"capability.rebootSupported",
					"capability.sanSupported",
					"capability.shutdownSupported",
					"capability.standbySupported",
					"capability.storageVMotionSupported",
					"capability.vmotionSupported",
					"capability.vmotionWithStorageVMotionSupported",
					"config.adminDisabled",
					"config.hyperThread",
					"config.network",
					"config.service",
					"config.dateTimeInfo",
					"config.consoleReservation",
					"hardware.systemInfo",
					"runtime.powerState",
					"runtime.inMaintenanceMode"
			]
	    },
	    :Datastore                 => {
	        :baseName   => "@dataStores",
	        :keyPath    => "['summary']['name']",
	        :props      => ["summary", "info", "capability"]
	    }
	}

	PropMap4 = {
		:VirtualApp				=> {
            :baseName   => "@virtualApps",
            :keyPath    => nil, # by mor only
            :props      => ["name","summary.config","resourcePool","owner","parent","vm"] # childConfiguration currently has a problem updating.  See FB3269
        }
	}

	UpdatePropMapsByType = [
		{
			:VirtualMachine            => {
		        :baseName   => "@virtualMachines",
		        :keyPath    => "['summary']['config']['vmPathName']",
				:keyPath2	=> "['summary']['config']['vmLocalPathName']",
		        :props      => ["summary","config","guest","resourceConfig","parent","snapshot","datastore","resourcePool","availableField"]
		    }
		},
		{
			:HostSystem                => {
		        :baseName   => "@hostSystems",
		        :keyPath    => "['summary']['config']['name']",
		        :props      => [
						"summary",
						"datastore",
						"capability.maintenanceModeSupported",
						"capability.nfsSupported",
						"capability.rebootSupported",
						"capability.sanSupported",
						"capability.shutdownSupported",
						"capability.standbySupported",
						"capability.storageVMotionSupported",
						"capability.vmotionSupported",
						"capability.vmotionWithStorageVMotionSupported",
						"config.adminDisabled",
						"config.hyperThread",
						"config.network",
						"config.service",
						"config.dateTimeInfo",
						"config.consoleReservation",
						"hardware.systemInfo",
						"runtime.powerState",
						"runtime.inMaintenanceMode"
				]
		    },
			:ComputeResource           => {
		        :baseName   => "@computeResources",
		        :keyPath    => "['name']",
		        :props      => ["name","summary","parent","host","resourcePool"]
		    },
		    :ClusterComputeResource    => {
		        :baseName   => "@clusterComputeResources",
		        :keyPath    => "['name']",
		        :props      => ["name","summary","parent","host","resourcePool","configuration"]
		    }
		},
		{
		    :ResourcePool              => {
		        :baseName   => "@resourcePools",
		        :keyPath    => nil, # by mor only
		        :props      => ["name","summary.config","resourcePool","owner","parent","vm"] # childConfiguration currently has a problem updating.  See FB3269
		    },
		    :Folder                    => {
		        :baseName   => "@folders",
		        :keyPath    => "['name']",
		        :props      => nil
		    },
		    :Datacenter                => {
		        :baseName   => "@datacenters",
		        :keyPath    => "['name']",
		        :props      => nil
		    },
		    :Datastore                 => {
		        :baseName   => "@dataStores",
		        :keyPath    => "['summary']['name']",
		        :props      => ["summary", "info", "capability"]
		    }
		}
	]

	EmsRefreshPropMap = {
	    :VirtualMachine            => {
	        :baseName   => "@virtualMachines",
	        :keyPath    => "['summary']['config']['vmPathName']",
			:keyPath2	=> "['summary']['config']['vmLocalPathName']",
	        :props      => [
					"availableField",
					"config.cpuAffinity.affinitySet",
					"config.defaultPowerOps.standbyAction",
					"config.hardware.device",
					"config.hardware.numCoresPerSocket",
					"config.version",
					"datastore",
					"guest.net",
					"resourceConfig.cpuAllocation.expandableReservation",
					"resourceConfig.cpuAllocation.limit",
					"resourceConfig.cpuAllocation.reservation",
					"resourceConfig.cpuAllocation.shares.level",
					"resourceConfig.cpuAllocation.shares.shares",
					"resourceConfig.memoryAllocation.expandableReservation",
					"resourceConfig.memoryAllocation.limit",
					"resourceConfig.memoryAllocation.reservation",
					"resourceConfig.memoryAllocation.shares.level",
					"resourceConfig.memoryAllocation.shares.shares",
					"snapshot",
					"summary.vm",
					"summary.config.annotation",
					"summary.config.ftInfo.instanceUuids",
					"summary.config.guestFullName",
					"summary.config.guestId",
					"summary.config.memorySizeMB",
					"summary.config.name",
					"summary.config.numCpu",
					"summary.config.template",
					"summary.config.uuid",
					"summary.config.vmPathName",
					"summary.customValue",
					"summary.guest.hostName",
					"summary.guest.ipAddress",
					"summary.guest.toolsStatus",
					"summary.runtime.bootTime",
					"summary.runtime.connectionState",
					"summary.runtime.host",
					"summary.runtime.powerState",
					"summary.storage.unshared",
					"summary.storage.committed"
			]
	    },
	    :ComputeResource           => {
	        :baseName   => "@computeResources",
	        :keyPath    => "['name']",
	        :props      => [
					"name",
					"host",
					"parent",
					"resourcePool"
			]
	    },
	    :ClusterComputeResource    => {
	        :baseName   => "@clusterComputeResources",
	        :keyPath    => "['name']",
	        :props      => [
					"configuration.dasConfig.admissionControlPolicy",
					"configuration.dasConfig.admissionControlEnabled",
					"configuration.dasConfig.enabled",
					"configuration.dasConfig.failoverLevel",
					"configuration.drsConfig.defaultVmBehavior",
					"configuration.drsConfig.enabled",
					"configuration.drsConfig.vmotionRate",
					"summary.effectiveCpu",
					"summary.effectiveMemory",
					"host",
					"name",
					"parent",
					"resourcePool"
			]
	    },
	    :ResourcePool              => {
	        :baseName   => "@resourcePools",
	        :keyPath    => nil, # by mor only
	        :props      => [
					"name",
					"parent",
					"resourcePool",
					"summary.config.cpuAllocation.expandableReservation",
					"summary.config.cpuAllocation.limit",
					"summary.config.cpuAllocation.reservation",
					"summary.config.cpuAllocation.shares.level",
					"summary.config.cpuAllocation.shares.shares",
					"summary.config.memoryAllocation.expandableReservation",
					"summary.config.memoryAllocation.limit",
					"summary.config.memoryAllocation.reservation",
					"summary.config.memoryAllocation.shares.level",
					"summary.config.memoryAllocation.shares.shares",
					"vm"
			] # childConfiguration currently has a problem updating.  See FB3269
	    },
	    :Folder                    => {
	        :baseName   => "@folders",
	        :keyPath    => "['name']",
	        :props      => [
					"childEntity",
					"name",
					"parent"
			]
	    },
	    :Datacenter                => {
	        :baseName   => "@datacenters",
	        :keyPath    => "['name']",
	        :props      => [
					"hostFolder",
					"name",
					"parent",
					"vmFolder"
			]
	    },
	    :HostSystem                => {
	        :baseName   => "@hostSystems",
	        :keyPath    => "['summary']['config']['name']",
	        :props      => [
					"config.adminDisabled",
					"config.consoleReservation.serviceConsoleReserved",
					"config.hyperThread.active",
					"config.network.consoleVnic",
					"config.network.dnsConfig.domainName",
					"config.network.dnsConfig.hostName",
					"config.network.ipRouteConfig.defaultGateway",
					"config.network.pnic",
					"config.network.portgroup",
					"config.network.vnic",
					"config.network.vswitch",
					"config.service.service",
					"datastore",
					"hardware.systemInfo.otherIdentifyingInfo",
					"name",
					"summary.host",
					"summary.config.name",
					"summary.config.product.build",
					"summary.config.product.name",
					"summary.config.product.osType",
					"summary.config.product.vendor",
					"summary.config.product.version",
					"summary.config.vmotionEnabled",
					"summary.hardware.cpuMhz",
					"summary.hardware.cpuModel",
					"summary.hardware.memorySize",
					"summary.hardware.model",
					"summary.hardware.numCpuCores",
					"summary.hardware.numCpuPkgs",
					"summary.hardware.numNics",
					"summary.hardware.vendor",
					"summary.quickStats.overallCpuUsage",
					"summary.quickStats.overallMemoryUsage",
					"summary.runtime.connectionState",
					"summary.runtime.inMaintenanceMode"
			]
	    },
	    :Datastore                 => {
	        :baseName   => "@dataStores",
	        :keyPath    => "['summary']['name']",
	        :props      => [
					"info",
					"capability.directoryHierarchySupported",
					"capability.perFileThinProvisioningSupported",
					"capability.rawDiskMappingsSupported",
					"summary.accessible",
					"summary.capacity",
					"summary.datastore",
					"summary.freeSpace",
					"summary.multipleHostAccess",
					"summary.name",
					"summary.type",
					"summary.uncommitted",
					"summary.url"
			]
	    }
	}

	CorePropMap = {
	    :VirtualMachine            => {
	        :baseName   => "@virtualMachines",
	        :keyPath    => "['summary']['config']['vmPathName']",
			:keyPath2	=> "['summary']['config']['vmLocalPathName']",
	        :props      => [
					"availableField",
					"snapshot",
					"summary.config.name",
					"summary.config.uuid",
					"summary.vm",
					"summary.config.vmPathName",
					"summary.runtime.host",
					"config.hardware.device",
					"config.annotation",
					"summary.customValue"
			]
	    },
	    :ComputeResource           => {
	        :baseName   => "@computeResources",
	        :keyPath    => "['name']",
	        :props      => [
					"name",
					"host",
					"parent",
					"resourcePool"
			]
	    },
	    :ClusterComputeResource    => {
	        :baseName   => "@clusterComputeResources",
	        :keyPath    => "['name']",
	        :props      => [
					"configuration.dasConfig.admissionControlEnabled",
					"configuration.dasConfig.enabled",
					"configuration.dasConfig.failoverLevel",
					"configuration.drsConfig.defaultVmBehavior",
					"configuration.drsConfig.enabled",
					"configuration.drsConfig.vmotionRate",
					"host",
					"name",
					"parent",
					"resourcePool"
			]
	    },
	    :ResourcePool              => {
	        :baseName   => "@resourcePools",
	        :keyPath    => nil, # by mor only
	        :props      => [
					"name",
					"parent",
					"resourcePool",
					"summary.config.cpuAllocation.expandableReservation",
					"summary.config.cpuAllocation.limit",
					"summary.config.cpuAllocation.reservation",
					"summary.config.cpuAllocation.shares.level",
					"summary.config.cpuAllocation.shares.shares",
					"summary.config.memoryAllocation.expandableReservation",
					"summary.config.memoryAllocation.limit",
					"summary.config.memoryAllocation.reservation",
					"summary.config.memoryAllocation.shares.level",
					"summary.config.memoryAllocation.shares.shares",
					"vm"
			] # childConfiguration currently has a problem updating.  See FB3269
	    },
	    :Folder                    => {
	        :baseName   => "@folders",
	        :keyPath    => "['name']",
	        :props      => [
					"childEntity",
					"name",
					"parent"
			]
	    },
	    :Datacenter                => {
	        :baseName   => "@datacenters",
	        :keyPath    => "['name']",
	        :props      => [
					"hostFolder",
					"name",
					"parent",
					"vmFolder"
			]
	    },
	    :HostSystem                => {
	        :baseName   => "@hostSystems",
	        :keyPath    => "['summary']['config']['name']",
	        :props      => [
					"capability",
					"summary.config.name",
					"summary.host",
					"config.datastorePrincipal"
			]
	    },
	    :Datastore                 => {
	        :baseName   => "@dataStores",
	        :keyPath    => "['summary']['name']",
	        :props      => [
					"info",
					"summary.accessible",
					"summary.multipleHostAccess",
					"summary.name",
					"summary.type",
					"summary.url",
					"summary.capacity",
					"summary.datastore",
					"summary.freeSpace",
					"summary.uncommitted"
			]
	    }
	}

	EventMonitorPropMap = {
		:VirtualMachine			=> {
            :baseName   => "@virtualMachines",
            :keyPath    => "['summary']['config']['vmPathName']",
            :props      => [
					"summary.config.vmPathName",
					"summary.runtime.host"
			]
        },
        :HostSystem				=> {
            :baseName   => "@hostSystems",
            :keyPath    => "['summary']['config']['name']",
            :props      => [ "summary.config.name" ]
        }
    }

	VimCoreUpdaterPropMap = {
		:VirtualMachine => {
			:props => [
				"config.template",
				"guest.net",
				"runtime.powerState"
			]
		}
	}

	def dupProps(pmap)
		raise "#{self.class.name}.dupProps: property map is not a Hash (#{pmap.class.name})" unless pmap.kind_of?(Hash)
		npmap = pmap.dup
		npmap.each do |k, v|
			raise "#{self.class.name}.dupProps: #{k} map is not a Hash (#{v.class.name})" unless v.kind_of?(Hash)
			nv = v.dup
			nv[:props] = nv[:props].dup unless nv[:props].nil?
			npmap[k] = nv
		end
		return npmap
	end

end
