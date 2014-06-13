
class TaskInfoState
	Error	= "error".freeze
	Queued	= "queued".freeze
	Running	= "running".freeze
	Success	= "success".freeze
end

class StateAlarmOperator
	IsEqual		= "isEqual".freeze
	IsUnequal	= "isUnequal".freeze
end

class VirtualDeviceConfigSpecOperation
	Add	= "add".freeze
	Edit	= "edit".freeze
	Remove	= "remove".freeze
end

class VirtualDeviceConfigSpecFileOperation
	Create	= "create".freeze
	Destroy	= "destroy".freeze
	Replace	= "replace".freeze
end

class VirtualDiskMode
	Append						= "append".freeze
	Independent_nonpersistent	= "independent_nonpersistent".freeze
	Independent_persistent		= "independent_persistent".freeze
	Nonpersistent				= "nonpersistent".freeze
	Persistent					= "persistent".freeze
	Undoable					= "undoable".freeze
end

class ObjectUpdateKind
	Enter	= "enter".freeze
	Leave	= "leave".freeze
	Modify	= "modify".freeze
end

class PerfFormat
	Csv		= "csv".freeze
	Normal	= "normal".freeze
end

class VirtualMachineRelocateDiskMoveOptions
	CreateNewChildDiskBacking				= "createNewChildDiskBacking".freeze
	MoveAllDiskBackingsAndAllowSharing		= "moveAllDiskBackingsAndAllowSharing".freeze
	MoveAllDiskBackingsAndDisallowSharing	= "moveAllDiskBackingsAndDisallowSharing".freeze
	MoveChildMostDiskBacking				= "moveChildMostDiskBacking".freeze
end