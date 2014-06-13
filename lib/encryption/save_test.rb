require 'xsd/qname'

# {urn:vim2}DestroyPropertyFilter
class DestroyPropertyFilter
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DestroyPropertyFilterResponse
class DestroyPropertyFilterResponse
  def initialize
  end
end

# {urn:vim2}CreateFilter
class CreateFilter
  attr_accessor :spec
  attr_accessor :partialUpdates

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil, partialUpdates = nil)
    @v__this = v__this
    @spec = spec
    @partialUpdates = partialUpdates
  end
end

# {urn:vim2}CreateFilterResponse
class CreateFilterResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RetrieveProperties
class RetrieveProperties
  attr_accessor :specSet

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, specSet = [])
    @v__this = v__this
    @specSet = specSet
  end
end

# {urn:vim2}RetrievePropertiesResponse
class RetrievePropertiesResponse < ::Array
end

# {urn:vim2}CheckForUpdates
class CheckForUpdates
  attr_accessor :version

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, version = nil)
    @v__this = v__this
    @version = version
  end
end

# {urn:vim2}CheckForUpdatesResponse
class CheckForUpdatesResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}WaitForUpdates
class WaitForUpdates
  attr_accessor :version

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, version = nil)
    @v__this = v__this
    @version = version
  end
end

# {urn:vim2}WaitForUpdatesResponse
class WaitForUpdatesResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CancelWaitForUpdates
class CancelWaitForUpdates
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}CancelWaitForUpdatesResponse
class CancelWaitForUpdatesResponse
  def initialize
  end
end

# {urn:vim2}AddAuthorizationRole
class AddAuthorizationRole
  attr_accessor :name
  attr_accessor :privIds

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, privIds = [])
    @v__this = v__this
    @name = name
    @privIds = privIds
  end
end

# {urn:vim2}AddAuthorizationRoleResponse
class AddAuthorizationRoleResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveAuthorizationRole
class RemoveAuthorizationRole
  attr_accessor :roleId
  attr_accessor :failIfUsed

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, roleId = nil, failIfUsed = nil)
    @v__this = v__this
    @roleId = roleId
    @failIfUsed = failIfUsed
  end
end

# {urn:vim2}RemoveAuthorizationRoleResponse
class RemoveAuthorizationRoleResponse
  def initialize
  end
end

# {urn:vim2}UpdateAuthorizationRole
class UpdateAuthorizationRole
  attr_accessor :roleId
  attr_accessor :newName
  attr_accessor :privIds

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, roleId = nil, newName = nil, privIds = [])
    @v__this = v__this
    @roleId = roleId
    @newName = newName
    @privIds = privIds
  end
end

# {urn:vim2}UpdateAuthorizationRoleResponse
class UpdateAuthorizationRoleResponse
  def initialize
  end
end

# {urn:vim2}MergePermissions
class MergePermissions
  attr_accessor :srcRoleId
  attr_accessor :dstRoleId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, srcRoleId = nil, dstRoleId = nil)
    @v__this = v__this
    @srcRoleId = srcRoleId
    @dstRoleId = dstRoleId
  end
end

# {urn:vim2}MergePermissionsResponse
class MergePermissionsResponse
  def initialize
  end
end

# {urn:vim2}RetrieveRolePermissions
class RetrieveRolePermissions
  attr_accessor :roleId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, roleId = nil)
    @v__this = v__this
    @roleId = roleId
  end
end

# {urn:vim2}RetrieveRolePermissionsResponse
class RetrieveRolePermissionsResponse < ::Array
end

# {urn:vim2}RetrieveEntityPermissions
class RetrieveEntityPermissions
  attr_accessor :entity
  attr_accessor :inherited

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, inherited = nil)
    @v__this = v__this
    @entity = entity
    @inherited = inherited
  end
end

# {urn:vim2}RetrieveEntityPermissionsResponse
class RetrieveEntityPermissionsResponse < ::Array
end

# {urn:vim2}RetrieveAllPermissions
class RetrieveAllPermissions
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RetrieveAllPermissionsResponse
class RetrieveAllPermissionsResponse < ::Array
end

# {urn:vim2}SetEntityPermissions
class SetEntityPermissions
  attr_accessor :entity
  attr_accessor :permission

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, permission = [])
    @v__this = v__this
    @entity = entity
    @permission = permission
  end
end

# {urn:vim2}SetEntityPermissionsResponse
class SetEntityPermissionsResponse
  def initialize
  end
end

# {urn:vim2}ResetEntityPermissions
class ResetEntityPermissions
  attr_accessor :entity
  attr_accessor :permission

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, permission = [])
    @v__this = v__this
    @entity = entity
    @permission = permission
  end
end

# {urn:vim2}ResetEntityPermissionsResponse
class ResetEntityPermissionsResponse
  def initialize
  end
end

# {urn:vim2}RemoveEntityPermission
class RemoveEntityPermission
  attr_accessor :entity
  attr_accessor :user
  attr_accessor :isGroup

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, user = nil, isGroup = nil)
    @v__this = v__this
    @entity = entity
    @user = user
    @isGroup = isGroup
  end
end

# {urn:vim2}RemoveEntityPermissionResponse
class RemoveEntityPermissionResponse
  def initialize
  end
end

# {urn:vim2}ReconfigureCluster_Task
class ReconfigureCluster_Task
  attr_accessor :spec
  attr_accessor :modify

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil, modify = nil)
    @v__this = v__this
    @spec = spec
    @modify = modify
  end
end

# {urn:vim2}ReconfigureCluster_TaskResponse
class ReconfigureCluster_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ApplyRecommendation
class ApplyRecommendation
  attr_accessor :key

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, key = nil)
    @v__this = v__this
    @key = key
  end
end

# {urn:vim2}ApplyRecommendationResponse
class ApplyRecommendationResponse
  def initialize
  end
end

# {urn:vim2}RecommendHostsForVm
class RecommendHostsForVm
  attr_accessor :vm
  attr_accessor :pool

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vm = nil, pool = nil)
    @v__this = v__this
    @vm = vm
    @pool = pool
  end
end

# {urn:vim2}RecommendHostsForVmResponse
class RecommendHostsForVmResponse < ::Array
end

# {urn:vim2}AddHost_Task
class AddHost_Task
  attr_accessor :spec
  attr_accessor :asConnected
  attr_accessor :resourcePool

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil, asConnected = nil, resourcePool = nil)
    @v__this = v__this
    @spec = spec
    @asConnected = asConnected
    @resourcePool = resourcePool
  end
end

# {urn:vim2}AddHost_TaskResponse
class AddHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}MoveInto_Task
class MoveInto_Task
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = [])
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}MoveInto_TaskResponse
class MoveInto_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}MoveHostInto_Task
class MoveHostInto_Task
  attr_accessor :host
  attr_accessor :resourcePool

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, resourcePool = nil)
    @v__this = v__this
    @host = host
    @resourcePool = resourcePool
  end
end

# {urn:vim2}MoveHostInto_TaskResponse
class MoveHostInto_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}AddCustomFieldDef
class AddCustomFieldDef
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}AddCustomFieldDefResponse
class AddCustomFieldDefResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveCustomFieldDef
class RemoveCustomFieldDef
  attr_accessor :key

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, key = nil)
    @v__this = v__this
    @key = key
  end
end

# {urn:vim2}RemoveCustomFieldDefResponse
class RemoveCustomFieldDefResponse
  def initialize
  end
end

# {urn:vim2}RenameCustomFieldDef
class RenameCustomFieldDef
  attr_accessor :key
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, key = nil, name = nil)
    @v__this = v__this
    @key = key
    @name = name
  end
end

# {urn:vim2}RenameCustomFieldDefResponse
class RenameCustomFieldDefResponse
  def initialize
  end
end

# {urn:vim2}SetField
class SetField
  attr_accessor :entity
  attr_accessor :key
  attr_accessor :value

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, key = nil, value = nil)
    @v__this = v__this
    @entity = entity
    @key = key
    @value = value
  end
end

# {urn:vim2}SetFieldResponse
class SetFieldResponse
  def initialize
  end
end

# {urn:vim2}DoesCustomizationSpecExist
class DoesCustomizationSpecExist
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}DoesCustomizationSpecExistResponse
class DoesCustomizationSpecExistResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}GetCustomizationSpec
class GetCustomizationSpec
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}GetCustomizationSpecResponse
class GetCustomizationSpecResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateCustomizationSpec
class CreateCustomizationSpec
  attr_accessor :item

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, item = nil)
    @v__this = v__this
    @item = item
  end
end

# {urn:vim2}CreateCustomizationSpecResponse
class CreateCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}OverwriteCustomizationSpec
class OverwriteCustomizationSpec
  attr_accessor :item

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, item = nil)
    @v__this = v__this
    @item = item
  end
end

# {urn:vim2}OverwriteCustomizationSpecResponse
class OverwriteCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}DeleteCustomizationSpec
class DeleteCustomizationSpec
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}DeleteCustomizationSpecResponse
class DeleteCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}DuplicateCustomizationSpec
class DuplicateCustomizationSpec
  attr_accessor :name
  attr_accessor :newName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, newName = nil)
    @v__this = v__this
    @name = name
    @newName = newName
  end
end

# {urn:vim2}DuplicateCustomizationSpecResponse
class DuplicateCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}RenameCustomizationSpec
class RenameCustomizationSpec
  attr_accessor :name
  attr_accessor :newName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, newName = nil)
    @v__this = v__this
    @name = name
    @newName = newName
  end
end

# {urn:vim2}RenameCustomizationSpecResponse
class RenameCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}CustomizationSpecItemToXml
class CustomizationSpecItemToXml
  attr_accessor :item

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, item = nil)
    @v__this = v__this
    @item = item
  end
end

# {urn:vim2}CustomizationSpecItemToXmlResponse
class CustomizationSpecItemToXmlResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}XmlToCustomizationSpecItem
class XmlToCustomizationSpecItem
  attr_accessor :specItemXml

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, specItemXml = nil)
    @v__this = v__this
    @specItemXml = specItemXml
  end
end

# {urn:vim2}XmlToCustomizationSpecItemResponse
class XmlToCustomizationSpecItemResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CheckCustomizationResources
class CheckCustomizationResources
  attr_accessor :guestOs

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, guestOs = nil)
    @v__this = v__this
    @guestOs = guestOs
  end
end

# {urn:vim2}CheckCustomizationResourcesResponse
class CheckCustomizationResourcesResponse
  def initialize
  end
end

# {urn:vim2}QueryConnectionInfo
class QueryConnectionInfo
  attr_accessor :hostname
  attr_accessor :port
  attr_accessor :username
  attr_accessor :password

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, hostname = nil, port = nil, username = nil, password = nil)
    @v__this = v__this
    @hostname = hostname
    @port = port
    @username = username
    @password = password
  end
end

# {urn:vim2}QueryConnectionInfoResponse
class QueryConnectionInfoResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RenameDatastore
class RenameDatastore
  attr_accessor :newName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, newName = nil)
    @v__this = v__this
    @newName = newName
  end
end

# {urn:vim2}RenameDatastoreResponse
class RenameDatastoreResponse
  def initialize
  end
end

# {urn:vim2}RefreshDatastore
class RefreshDatastore
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RefreshDatastoreResponse
class RefreshDatastoreResponse
  def initialize
  end
end

# {urn:vim2}DestroyDatastore
class DestroyDatastore
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DestroyDatastoreResponse
class DestroyDatastoreResponse
  def initialize
  end
end

# {urn:vim2}QueryDescriptions
class QueryDescriptions
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}QueryDescriptionsResponse
class QueryDescriptionsResponse < ::Array
end

# {urn:vim2}BrowseDiagnosticLog
class BrowseDiagnosticLog
  attr_accessor :host
  attr_accessor :key
  attr_accessor :start
  attr_accessor :lines

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, key = nil, start = nil, lines = nil)
    @v__this = v__this
    @host = host
    @key = key
    @start = start
    @lines = lines
  end
end

# {urn:vim2}BrowseDiagnosticLogResponse
class BrowseDiagnosticLogResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}GenerateLogBundles_Task
class GenerateLogBundles_Task
  attr_accessor :includeDefault
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, includeDefault = nil, host = [])
    @v__this = v__this
    @includeDefault = includeDefault
    @host = host
  end
end

# {urn:vim2}GenerateLogBundles_TaskResponse
class GenerateLogBundles_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryConfigOptionDescriptor
class QueryConfigOptionDescriptor
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}QueryConfigOptionDescriptorResponse
class QueryConfigOptionDescriptorResponse < ::Array
end

# {urn:vim2}QueryConfigOption
class QueryConfigOption
  attr_accessor :key
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, key = nil, host = nil)
    @v__this = v__this
    @key = key
    @host = host
  end
end

# {urn:vim2}QueryConfigOptionResponse
class QueryConfigOptionResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryConfigTarget
class QueryConfigTarget
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}QueryConfigTargetResponse
class QueryConfigTargetResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateFolder
class CreateFolder
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}CreateFolderResponse
class CreateFolderResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}MoveIntoFolder_Task
class MoveIntoFolder_Task
  attr_accessor :list

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, list = [])
    @v__this = v__this
    @list = list
  end
end

# {urn:vim2}MoveIntoFolder_TaskResponse
class MoveIntoFolder_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateVM_Task
class CreateVM_Task
  attr_accessor :config
  attr_accessor :pool
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil, pool = nil, host = nil)
    @v__this = v__this
    @config = config
    @pool = pool
    @host = host
  end
end

# {urn:vim2}CreateVM_TaskResponse
class CreateVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RegisterVM_Task
class RegisterVM_Task
  attr_accessor :path
  attr_accessor :name
  attr_accessor :asTemplate
  attr_accessor :pool
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, path = nil, name = nil, asTemplate = nil, pool = nil, host = nil)
    @v__this = v__this
    @path = path
    @name = name
    @asTemplate = asTemplate
    @pool = pool
    @host = host
  end
end

# {urn:vim2}RegisterVM_TaskResponse
class RegisterVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateCluster
class CreateCluster
  attr_accessor :name
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, spec = nil)
    @v__this = v__this
    @name = name
    @spec = spec
  end
end

# {urn:vim2}CreateClusterResponse
class CreateClusterResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}AddStandaloneHost_Task
class AddStandaloneHost_Task
  attr_accessor :spec
  attr_accessor :addConnected

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil, addConnected = nil)
    @v__this = v__this
    @spec = spec
    @addConnected = addConnected
  end
end

# {urn:vim2}AddStandaloneHost_TaskResponse
class AddStandaloneHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateDatacenter
class CreateDatacenter
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}CreateDatacenterResponse
class CreateDatacenterResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UnregisterAndDestroy_Task
class UnregisterAndDestroy_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}UnregisterAndDestroy_TaskResponse
class UnregisterAndDestroy_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}SetCollectorPageSize
class SetCollectorPageSize
  attr_accessor :maxCount

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, maxCount = nil)
    @v__this = v__this
    @maxCount = maxCount
  end
end

# {urn:vim2}SetCollectorPageSizeResponse
class SetCollectorPageSizeResponse
  def initialize
  end
end

# {urn:vim2}RewindCollector
class RewindCollector
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RewindCollectorResponse
class RewindCollectorResponse
  def initialize
  end
end

# {urn:vim2}ResetCollector
class ResetCollector
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ResetCollectorResponse
class ResetCollectorResponse
  def initialize
  end
end

# {urn:vim2}DestroyCollector
class DestroyCollector
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DestroyCollectorResponse
class DestroyCollectorResponse
  def initialize
  end
end

# {urn:vim2}QueryHostConnectionInfo
class QueryHostConnectionInfo
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}QueryHostConnectionInfoResponse
class QueryHostConnectionInfoResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UpdateSystemResources
class UpdateSystemResources
  attr_accessor :resourceInfo

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, resourceInfo = nil)
    @v__this = v__this
    @resourceInfo = resourceInfo
  end
end

# {urn:vim2}UpdateSystemResourcesResponse
class UpdateSystemResourcesResponse
  def initialize
  end
end

# {urn:vim2}ReconnectHost_Task
class ReconnectHost_Task
  attr_accessor :cnxSpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, cnxSpec = nil)
    @v__this = v__this
    @cnxSpec = cnxSpec
  end
end

# {urn:vim2}ReconnectHost_TaskResponse
class ReconnectHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}DisconnectHost_Task
class DisconnectHost_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DisconnectHost_TaskResponse
class DisconnectHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}EnterMaintenanceMode_Task
class EnterMaintenanceMode_Task
  attr_accessor :timeout

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, timeout = nil)
    @v__this = v__this
    @timeout = timeout
  end
end

# {urn:vim2}EnterMaintenanceMode_TaskResponse
class EnterMaintenanceMode_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ExitMaintenanceMode_Task
class ExitMaintenanceMode_Task
  attr_accessor :timeout

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, timeout = nil)
    @v__this = v__this
    @timeout = timeout
  end
end

# {urn:vim2}ExitMaintenanceMode_TaskResponse
class ExitMaintenanceMode_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RebootHost_Task
class RebootHost_Task
  attr_accessor :force

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, force = nil)
    @v__this = v__this
    @force = force
  end
end

# {urn:vim2}RebootHost_TaskResponse
class RebootHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ShutdownHost_Task
class ShutdownHost_Task
  attr_accessor :force

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, force = nil)
    @v__this = v__this
    @force = force
  end
end

# {urn:vim2}ShutdownHost_TaskResponse
class ShutdownHost_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryMemoryOverhead
class QueryMemoryOverhead
  attr_accessor :memorySize
  attr_accessor :videoRamSize
  attr_accessor :numVcpus

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, memorySize = nil, videoRamSize = nil, numVcpus = nil)
    @v__this = v__this
    @memorySize = memorySize
    @videoRamSize = videoRamSize
    @numVcpus = numVcpus
  end
end

# {urn:vim2}QueryMemoryOverheadResponse
class QueryMemoryOverheadResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ReconfigureHostForDAS_Task
class ReconfigureHostForDAS_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ReconfigureHostForDAS_TaskResponse
class ReconfigureHostForDAS_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryLicenseSourceAvailability
class QueryLicenseSourceAvailability
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}QueryLicenseSourceAvailabilityResponse
class QueryLicenseSourceAvailabilityResponse < ::Array
end

# {urn:vim2}QueryLicenseUsage
class QueryLicenseUsage
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}QueryLicenseUsageResponse
class QueryLicenseUsageResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}SetLicenseEdition
class SetLicenseEdition
  attr_accessor :host
  attr_accessor :featureKey

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, featureKey = nil)
    @v__this = v__this
    @host = host
    @featureKey = featureKey
  end
end

# {urn:vim2}SetLicenseEditionResponse
class SetLicenseEditionResponse
  def initialize
  end
end

# {urn:vim2}CheckLicenseFeature
class CheckLicenseFeature
  attr_accessor :host
  attr_accessor :featureKey

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, featureKey = nil)
    @v__this = v__this
    @host = host
    @featureKey = featureKey
  end
end

# {urn:vim2}CheckLicenseFeatureResponse
class CheckLicenseFeatureResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}EnableFeature
class EnableFeature
  attr_accessor :host
  attr_accessor :featureKey

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, featureKey = nil)
    @v__this = v__this
    @host = host
    @featureKey = featureKey
  end
end

# {urn:vim2}EnableFeatureResponse
class EnableFeatureResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}DisableFeature
class DisableFeature
  attr_accessor :host
  attr_accessor :featureKey

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, featureKey = nil)
    @v__this = v__this
    @host = host
    @featureKey = featureKey
  end
end

# {urn:vim2}DisableFeatureResponse
class DisableFeatureResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ConfigureLicenseSource
class ConfigureLicenseSource
  attr_accessor :host
  attr_accessor :licenseSource

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil, licenseSource = nil)
    @v__this = v__this
    @host = host
    @licenseSource = licenseSource
  end
end

# {urn:vim2}ConfigureLicenseSourceResponse
class ConfigureLicenseSourceResponse
  def initialize
  end
end

# {urn:vim2}Reload
class Reload
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ReloadResponse
class ReloadResponse
  def initialize
  end
end

# {urn:vim2}Rename_Task
class Rename_Task
  attr_accessor :newName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, newName = nil)
    @v__this = v__this
    @newName = newName
  end
end

# {urn:vim2}Rename_TaskResponse
class Rename_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}Destroy_Task
class Destroy_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}Destroy_TaskResponse
class Destroy_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}DestroyNetwork
class DestroyNetwork
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DestroyNetworkResponse
class DestroyNetworkResponse
  def initialize
  end
end

# {urn:vim2}QueryPerfProviderSummary
class QueryPerfProviderSummary
  attr_accessor :entity

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil)
    @v__this = v__this
    @entity = entity
  end
end

# {urn:vim2}QueryPerfProviderSummaryResponse
class QueryPerfProviderSummaryResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryAvailablePerfMetric
class QueryAvailablePerfMetric
  attr_accessor :entity
  attr_accessor :beginTime
  attr_accessor :endTime
  attr_accessor :intervalId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, beginTime = nil, endTime = nil, intervalId = nil)
    @v__this = v__this
    @entity = entity
    @beginTime = beginTime
    @endTime = endTime
    @intervalId = intervalId
  end
end

# {urn:vim2}QueryAvailablePerfMetricResponse
class QueryAvailablePerfMetricResponse < ::Array
end

# {urn:vim2}QueryPerfCounter
class QueryPerfCounter
  attr_accessor :counterId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, counterId = [])
    @v__this = v__this
    @counterId = counterId
  end
end

# {urn:vim2}QueryPerfCounterResponse
class QueryPerfCounterResponse < ::Array
end

# {urn:vim2}QueryPerf
class QueryPerf
  attr_accessor :querySpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, querySpec = [])
    @v__this = v__this
    @querySpec = querySpec
  end
end

# {urn:vim2}QueryPerfResponse
class QueryPerfResponse < ::Array
end

# {urn:vim2}QueryPerfComposite
class QueryPerfComposite
  attr_accessor :querySpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, querySpec = nil)
    @v__this = v__this
    @querySpec = querySpec
  end
end

# {urn:vim2}QueryPerfCompositeResponse
class QueryPerfCompositeResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreatePerfInterval
class CreatePerfInterval
  attr_accessor :intervalId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, intervalId = nil)
    @v__this = v__this
    @intervalId = intervalId
  end
end

# {urn:vim2}CreatePerfIntervalResponse
class CreatePerfIntervalResponse
  def initialize
  end
end

# {urn:vim2}RemovePerfInterval
class RemovePerfInterval
  attr_accessor :samplePeriod

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, samplePeriod = nil)
    @v__this = v__this
    @samplePeriod = samplePeriod
  end
end

# {urn:vim2}RemovePerfIntervalResponse
class RemovePerfIntervalResponse
  def initialize
  end
end

# {urn:vim2}UpdatePerfInterval
class UpdatePerfInterval
  attr_accessor :interval

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, interval = nil)
    @v__this = v__this
    @interval = interval
  end
end

# {urn:vim2}UpdatePerfIntervalResponse
class UpdatePerfIntervalResponse
  def initialize
  end
end

# {urn:vim2}UpdateConfig
class UpdateConfig
  attr_accessor :name
  attr_accessor :config

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, config = nil)
    @v__this = v__this
    @name = name
    @config = config
  end
end

# {urn:vim2}UpdateConfigResponse
class UpdateConfigResponse
  def initialize
  end
end

# {urn:vim2}MoveIntoResourcePool
class MoveIntoResourcePool
  attr_accessor :list

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, list = [])
    @v__this = v__this
    @list = list
  end
end

# {urn:vim2}MoveIntoResourcePoolResponse
class MoveIntoResourcePoolResponse
  def initialize
  end
end

# {urn:vim2}UpdateChildResourceConfiguration
class UpdateChildResourceConfiguration
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = [])
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}UpdateChildResourceConfigurationResponse
class UpdateChildResourceConfigurationResponse
  def initialize
  end
end

# {urn:vim2}CreateResourcePool
class CreateResourcePool
  attr_accessor :name
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, spec = nil)
    @v__this = v__this
    @name = name
    @spec = spec
  end
end

# {urn:vim2}CreateResourcePoolResponse
class CreateResourcePoolResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}DestroyChildren
class DestroyChildren
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DestroyChildrenResponse
class DestroyChildrenResponse
  def initialize
  end
end

# {urn:vim2}FindByUuid
class FindByUuid
  attr_accessor :datacenter
  attr_accessor :uuid
  attr_accessor :vmSearch

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datacenter = nil, uuid = nil, vmSearch = nil)
    @v__this = v__this
    @datacenter = datacenter
    @uuid = uuid
    @vmSearch = vmSearch
  end
end

# {urn:vim2}FindByUuidResponse
class FindByUuidResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}FindByDatastorePath
class FindByDatastorePath
  attr_accessor :datacenter
  attr_accessor :path

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datacenter = nil, path = nil)
    @v__this = v__this
    @datacenter = datacenter
    @path = path
  end
end

# {urn:vim2}FindByDatastorePathResponse
class FindByDatastorePathResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}FindByDnsName
class FindByDnsName
  attr_accessor :datacenter
  attr_accessor :dnsName
  attr_accessor :vmSearch

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datacenter = nil, dnsName = nil, vmSearch = nil)
    @v__this = v__this
    @datacenter = datacenter
    @dnsName = dnsName
    @vmSearch = vmSearch
  end
end

# {urn:vim2}FindByDnsNameResponse
class FindByDnsNameResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}FindByIp
class FindByIp
  attr_accessor :datacenter
  attr_accessor :ip
  attr_accessor :vmSearch

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datacenter = nil, ip = nil, vmSearch = nil)
    @v__this = v__this
    @datacenter = datacenter
    @ip = ip
    @vmSearch = vmSearch
  end
end

# {urn:vim2}FindByIpResponse
class FindByIpResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}FindByInventoryPath
class FindByInventoryPath
  attr_accessor :inventoryPath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, inventoryPath = nil)
    @v__this = v__this
    @inventoryPath = inventoryPath
  end
end

# {urn:vim2}FindByInventoryPathResponse
class FindByInventoryPathResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}FindChild
class FindChild
  attr_accessor :entity
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, name = nil)
    @v__this = v__this
    @entity = entity
    @name = name
  end
end

# {urn:vim2}FindChildResponse
class FindChildResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CurrentTime
class CurrentTime
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}CurrentTimeResponse
class CurrentTimeResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RetrieveServiceContent
class RetrieveServiceContent
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RetrieveServiceContentResponse
class RetrieveServiceContentResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ValidateMigration
class ValidateMigration
  attr_accessor :vm
  attr_accessor :state
  attr_accessor :testType
  attr_accessor :pool
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vm = [], state = nil, testType = [], pool = nil, host = nil)
    @v__this = v__this
    @vm = vm
    @state = state
    @testType = testType
    @pool = pool
    @host = host
  end
end

# {urn:vim2}ValidateMigrationResponse
class ValidateMigrationResponse < ::Array
end

# {urn:vim2}QueryVMotionCompatibility
class QueryVMotionCompatibility
  attr_accessor :vm
  attr_accessor :host
  attr_accessor :compatibility

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vm = nil, host = [], compatibility = [])
    @v__this = v__this
    @vm = vm
    @host = host
    @compatibility = compatibility
  end
end

# {urn:vim2}QueryVMotionCompatibilityResponse
class QueryVMotionCompatibilityResponse < ::Array
end

# {urn:vim2}UpdateServiceMessage
class UpdateServiceMessage
  attr_accessor :message

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, message = nil)
    @v__this = v__this
    @message = message
  end
end

# {urn:vim2}UpdateServiceMessageResponse
class UpdateServiceMessageResponse
  def initialize
  end
end

# {urn:vim2}Login
class Login
  attr_accessor :userName
  attr_accessor :password
  attr_accessor :locale

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, userName = nil, password = nil, locale = nil)
    @v__this = v__this
    @userName = userName
    @password = password
    @locale = locale
  end
end

# {urn:vim2}LoginResponse
class LoginResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}Logout
class Logout
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}LogoutResponse
class LogoutResponse
  def initialize
  end
end

# {urn:vim2}AcquireLocalTicket
class AcquireLocalTicket
  attr_accessor :userName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, userName = nil)
    @v__this = v__this
    @userName = userName
  end
end

# {urn:vim2}AcquireLocalTicketResponse
class AcquireLocalTicketResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}TerminateSession
class TerminateSession
  attr_accessor :sessionId

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, sessionId = [])
    @v__this = v__this
    @sessionId = sessionId
  end
end

# {urn:vim2}TerminateSessionResponse
class TerminateSessionResponse
  def initialize
  end
end

# {urn:vim2}SetLocale
class SetLocale
  attr_accessor :locale

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, locale = nil)
    @v__this = v__this
    @locale = locale
  end
end

# {urn:vim2}SetLocaleResponse
class SetLocaleResponse
  def initialize
  end
end

# {urn:vim2}CancelTask
class CancelTask
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}CancelTaskResponse
class CancelTaskResponse
  def initialize
  end
end

# {urn:vim2}ReadNextTasks
class ReadNextTasks
  attr_accessor :maxCount

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, maxCount = nil)
    @v__this = v__this
    @maxCount = maxCount
  end
end

# {urn:vim2}ReadNextTasksResponse
class ReadNextTasksResponse < ::Array
end

# {urn:vim2}ReadPreviousTasks
class ReadPreviousTasks
  attr_accessor :maxCount

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, maxCount = nil)
    @v__this = v__this
    @maxCount = maxCount
  end
end

# {urn:vim2}ReadPreviousTasksResponse
class ReadPreviousTasksResponse < ::Array
end

# {urn:vim2}CreateCollectorForTasks
class CreateCollectorForTasks
  attr_accessor :filter

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, filter = nil)
    @v__this = v__this
    @filter = filter
  end
end

# {urn:vim2}CreateCollectorForTasksResponse
class CreateCollectorForTasksResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RetrieveUserGroups
class RetrieveUserGroups
  attr_accessor :domain
  attr_accessor :searchStr
  attr_accessor :belongsToGroup
  attr_accessor :belongsToUser
  attr_accessor :exactMatch
  attr_accessor :findUsers
  attr_accessor :findGroups

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, domain = nil, searchStr = nil, belongsToGroup = nil, belongsToUser = nil, exactMatch = nil, findUsers = nil, findGroups = nil)
    @v__this = v__this
    @domain = domain
    @searchStr = searchStr
    @belongsToGroup = belongsToGroup
    @belongsToUser = belongsToUser
    @exactMatch = exactMatch
    @findUsers = findUsers
    @findGroups = findGroups
  end
end

# {urn:vim2}RetrieveUserGroupsResponse
class RetrieveUserGroupsResponse < ::Array
end

# {urn:vim2}CreateSnapshot_Task
class CreateSnapshot_Task
  attr_accessor :name
  attr_accessor :description
  attr_accessor :memory
  attr_accessor :quiesce

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, description = nil, memory = nil, quiesce = nil)
    @v__this = v__this
    @name = name
    @description = description
    @memory = memory
    @quiesce = quiesce
  end
end

# {urn:vim2}CreateSnapshot_TaskResponse
class CreateSnapshot_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RevertToCurrentSnapshot_Task
class RevertToCurrentSnapshot_Task
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}RevertToCurrentSnapshot_TaskResponse
class RevertToCurrentSnapshot_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveAllSnapshots_Task
class RemoveAllSnapshots_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RemoveAllSnapshots_TaskResponse
class RemoveAllSnapshots_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ReconfigVM_Task
class ReconfigVM_Task
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}ReconfigVM_TaskResponse
class ReconfigVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UpgradeVM_Task
class UpgradeVM_Task
  attr_accessor :version

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, version = nil)
    @v__this = v__this
    @version = version
  end
end

# {urn:vim2}UpgradeVM_TaskResponse
class UpgradeVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}PowerOnVM_Task
class PowerOnVM_Task
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}PowerOnVM_TaskResponse
class PowerOnVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}PowerOffVM_Task
class PowerOffVM_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}PowerOffVM_TaskResponse
class PowerOffVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}SuspendVM_Task
class SuspendVM_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}SuspendVM_TaskResponse
class SuspendVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ResetVM_Task
class ResetVM_Task
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ResetVM_TaskResponse
class ResetVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}ShutdownGuest
class ShutdownGuest
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ShutdownGuestResponse
class ShutdownGuestResponse
  def initialize
  end
end

# {urn:vim2}RebootGuest
class RebootGuest
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RebootGuestResponse
class RebootGuestResponse
  def initialize
  end
end

# {urn:vim2}StandbyGuest
class StandbyGuest
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}StandbyGuestResponse
class StandbyGuestResponse
  def initialize
  end
end

# {urn:vim2}AnswerVM
class AnswerVM
  attr_accessor :questionId
  attr_accessor :answerChoice

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, questionId = nil, answerChoice = nil)
    @v__this = v__this
    @questionId = questionId
    @answerChoice = answerChoice
  end
end

# {urn:vim2}AnswerVMResponse
class AnswerVMResponse
  def initialize
  end
end

# {urn:vim2}CustomizeVM_Task
class CustomizeVM_Task
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}CustomizeVM_TaskResponse
class CustomizeVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CheckCustomizationSpec
class CheckCustomizationSpec
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}CheckCustomizationSpecResponse
class CheckCustomizationSpecResponse
  def initialize
  end
end

# {urn:vim2}MigrateVM_Task
class MigrateVM_Task
  attr_accessor :pool
  attr_accessor :host
  attr_accessor :priority
  attr_accessor :state

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pool = nil, host = nil, priority = nil, state = nil)
    @v__this = v__this
    @pool = pool
    @host = host
    @priority = priority
    @state = state
  end
end

# {urn:vim2}MigrateVM_TaskResponse
class MigrateVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RelocateVM_Task
class RelocateVM_Task
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}RelocateVM_TaskResponse
class RelocateVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CloneVM_Task
class CloneVM_Task
  attr_accessor :folder
  attr_accessor :name
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, folder = nil, name = nil, spec = nil)
    @v__this = v__this
    @folder = folder
    @name = name
    @spec = spec
  end
end

# {urn:vim2}CloneVM_TaskResponse
class CloneVM_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}MarkAsTemplate
class MarkAsTemplate
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}MarkAsTemplateResponse
class MarkAsTemplateResponse
  def initialize
  end
end

# {urn:vim2}MarkAsVirtualMachine
class MarkAsVirtualMachine
  attr_accessor :pool
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pool = nil, host = nil)
    @v__this = v__this
    @pool = pool
    @host = host
  end
end

# {urn:vim2}MarkAsVirtualMachineResponse
class MarkAsVirtualMachineResponse
  def initialize
  end
end

# {urn:vim2}UnregisterVM
class UnregisterVM
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}UnregisterVMResponse
class UnregisterVMResponse
  def initialize
  end
end

# {urn:vim2}ResetGuestInformation
class ResetGuestInformation
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ResetGuestInformationResponse
class ResetGuestInformationResponse
  def initialize
  end
end

# {urn:vim2}MountToolsInstaller
class MountToolsInstaller
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}MountToolsInstallerResponse
class MountToolsInstallerResponse
  def initialize
  end
end

# {urn:vim2}UnmountToolsInstaller
class UnmountToolsInstaller
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}UnmountToolsInstallerResponse
class UnmountToolsInstallerResponse
  def initialize
  end
end

# {urn:vim2}UpgradeTools_Task
class UpgradeTools_Task
  attr_accessor :installerOptions

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, installerOptions = nil)
    @v__this = v__this
    @installerOptions = installerOptions
  end
end

# {urn:vim2}UpgradeTools_TaskResponse
class UpgradeTools_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}AcquireMksTicket
class AcquireMksTicket
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}AcquireMksTicketResponse
class AcquireMksTicketResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}SetScreenResolution
class SetScreenResolution
  attr_accessor :width
  attr_accessor :height

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, width = nil, height = nil)
    @v__this = v__this
    @width = width
    @height = height
  end
end

# {urn:vim2}SetScreenResolutionResponse
class SetScreenResolutionResponse
  def initialize
  end
end

# {urn:vim2}RemoveAlarm
class RemoveAlarm
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RemoveAlarmResponse
class RemoveAlarmResponse
  def initialize
  end
end

# {urn:vim2}ReconfigureAlarm
class ReconfigureAlarm
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}ReconfigureAlarmResponse
class ReconfigureAlarmResponse
  def initialize
  end
end

# {urn:vim2}CreateAlarm
class CreateAlarm
  attr_accessor :entity
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, spec = nil)
    @v__this = v__this
    @entity = entity
    @spec = spec
  end
end

# {urn:vim2}CreateAlarmResponse
class CreateAlarmResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}GetAlarm
class GetAlarm
  attr_accessor :entity

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil)
    @v__this = v__this
    @entity = entity
  end
end

# {urn:vim2}GetAlarmResponse
class GetAlarmResponse < ::Array
end

# {urn:vim2}GetAlarmState
class GetAlarmState
  attr_accessor :entity

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil)
    @v__this = v__this
    @entity = entity
  end
end

# {urn:vim2}GetAlarmStateResponse
class GetAlarmStateResponse < ::Array
end

# {urn:vim2}ReadNextEvents
class ReadNextEvents
  attr_accessor :maxCount

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, maxCount = nil)
    @v__this = v__this
    @maxCount = maxCount
  end
end

# {urn:vim2}ReadNextEventsResponse
class ReadNextEventsResponse < ::Array
end

# {urn:vim2}ReadPreviousEvents
class ReadPreviousEvents
  attr_accessor :maxCount

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, maxCount = nil)
    @v__this = v__this
    @maxCount = maxCount
  end
end

# {urn:vim2}ReadPreviousEventsResponse
class ReadPreviousEventsResponse < ::Array
end

# {urn:vim2}CreateCollectorForEvents
class CreateCollectorForEvents
  attr_accessor :filter

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, filter = nil)
    @v__this = v__this
    @filter = filter
  end
end

# {urn:vim2}CreateCollectorForEventsResponse
class CreateCollectorForEventsResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}LogUserEvent
class LogUserEvent
  attr_accessor :entity
  attr_accessor :msg

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, msg = nil)
    @v__this = v__this
    @entity = entity
    @msg = msg
  end
end

# {urn:vim2}LogUserEventResponse
class LogUserEventResponse
  def initialize
  end
end

# {urn:vim2}QueryEvents
class QueryEvents
  attr_accessor :filter

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, filter = nil)
    @v__this = v__this
    @filter = filter
  end
end

# {urn:vim2}QueryEventsResponse
class QueryEventsResponse < ::Array
end

# {urn:vim2}ReconfigureAutostart
class ReconfigureAutostart
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}ReconfigureAutostartResponse
class ReconfigureAutostartResponse
  def initialize
  end
end

# {urn:vim2}AutoStartPowerOn
class AutoStartPowerOn
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}AutoStartPowerOnResponse
class AutoStartPowerOnResponse
  def initialize
  end
end

# {urn:vim2}AutoStartPowerOff
class AutoStartPowerOff
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}AutoStartPowerOffResponse
class AutoStartPowerOffResponse
  def initialize
  end
end

# {urn:vim2}EnableHyperThreading
class EnableHyperThreading
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}EnableHyperThreadingResponse
class EnableHyperThreadingResponse
  def initialize
  end
end

# {urn:vim2}DisableHyperThreading
class DisableHyperThreading
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DisableHyperThreadingResponse
class DisableHyperThreadingResponse
  def initialize
  end
end

# {urn:vim2}SearchDatastore_Task
class SearchDatastore_Task
  attr_accessor :datastorePath
  attr_accessor :searchSpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastorePath = nil, searchSpec = nil)
    @v__this = v__this
    @datastorePath = datastorePath
    @searchSpec = searchSpec
  end
end

# {urn:vim2}SearchDatastore_TaskResponse
class SearchDatastore_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}SearchDatastoreSubFolders_Task
class SearchDatastoreSubFolders_Task
  attr_accessor :datastorePath
  attr_accessor :searchSpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastorePath = nil, searchSpec = nil)
    @v__this = v__this
    @datastorePath = datastorePath
    @searchSpec = searchSpec
  end
end

# {urn:vim2}SearchDatastoreSubFolders_TaskResponse
class SearchDatastoreSubFolders_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}DeleteFile
class DeleteFile
  attr_accessor :datastorePath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastorePath = nil)
    @v__this = v__this
    @datastorePath = datastorePath
  end
end

# {urn:vim2}DeleteFileResponse
class DeleteFileResponse
  def initialize
  end
end

# {urn:vim2}QueryAvailableDisksForVmfs
class QueryAvailableDisksForVmfs
  attr_accessor :datastore

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastore = nil)
    @v__this = v__this
    @datastore = datastore
  end
end

# {urn:vim2}QueryAvailableDisksForVmfsResponse
class QueryAvailableDisksForVmfsResponse < ::Array
end

# {urn:vim2}QueryVmfsDatastoreCreateOptions
class QueryVmfsDatastoreCreateOptions
  attr_accessor :devicePath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, devicePath = nil)
    @v__this = v__this
    @devicePath = devicePath
  end
end

# {urn:vim2}QueryVmfsDatastoreCreateOptionsResponse
class QueryVmfsDatastoreCreateOptionsResponse < ::Array
end

# {urn:vim2}CreateVmfsDatastore
class CreateVmfsDatastore
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}CreateVmfsDatastoreResponse
class CreateVmfsDatastoreResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}QueryVmfsDatastoreExtendOptions
class QueryVmfsDatastoreExtendOptions
  attr_accessor :datastore
  attr_accessor :devicePath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastore = nil, devicePath = nil)
    @v__this = v__this
    @datastore = datastore
    @devicePath = devicePath
  end
end

# {urn:vim2}QueryVmfsDatastoreExtendOptionsResponse
class QueryVmfsDatastoreExtendOptionsResponse < ::Array
end

# {urn:vim2}ExtendVmfsDatastore
class ExtendVmfsDatastore
  attr_accessor :datastore
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastore = nil, spec = nil)
    @v__this = v__this
    @datastore = datastore
    @spec = spec
  end
end

# {urn:vim2}ExtendVmfsDatastoreResponse
class ExtendVmfsDatastoreResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateNasDatastore
class CreateNasDatastore
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}CreateNasDatastoreResponse
class CreateNasDatastoreResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateLocalDatastore
class CreateLocalDatastore
  attr_accessor :name
  attr_accessor :path

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, path = nil)
    @v__this = v__this
    @name = name
    @path = path
  end
end

# {urn:vim2}CreateLocalDatastoreResponse
class CreateLocalDatastoreResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveDatastore
class RemoveDatastore
  attr_accessor :datastore

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, datastore = nil)
    @v__this = v__this
    @datastore = datastore
  end
end

# {urn:vim2}RemoveDatastoreResponse
class RemoveDatastoreResponse
  def initialize
  end
end

# {urn:vim2}ConfigureDatastorePrincipal
class ConfigureDatastorePrincipal
  attr_accessor :userName
  attr_accessor :password

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, userName = nil, password = nil)
    @v__this = v__this
    @userName = userName
    @password = password
  end
end

# {urn:vim2}ConfigureDatastorePrincipalResponse
class ConfigureDatastorePrincipalResponse
  def initialize
  end
end

# {urn:vim2}QueryAvailablePartition
class QueryAvailablePartition
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}QueryAvailablePartitionResponse
class QueryAvailablePartitionResponse < ::Array
end

# {urn:vim2}SelectActivePartition
class SelectActivePartition
  attr_accessor :partition

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, partition = nil)
    @v__this = v__this
    @partition = partition
  end
end

# {urn:vim2}SelectActivePartitionResponse
class SelectActivePartitionResponse
  def initialize
  end
end

# {urn:vim2}QueryPartitionCreateOptions
class QueryPartitionCreateOptions
  attr_accessor :storageType
  attr_accessor :diagnosticType

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, storageType = nil, diagnosticType = nil)
    @v__this = v__this
    @storageType = storageType
    @diagnosticType = diagnosticType
  end
end

# {urn:vim2}QueryPartitionCreateOptionsResponse
class QueryPartitionCreateOptionsResponse < ::Array
end

# {urn:vim2}QueryPartitionCreateDesc
class QueryPartitionCreateDesc
  attr_accessor :diskUuid
  attr_accessor :diagnosticType

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, diskUuid = nil, diagnosticType = nil)
    @v__this = v__this
    @diskUuid = diskUuid
    @diagnosticType = diagnosticType
  end
end

# {urn:vim2}QueryPartitionCreateDescResponse
class QueryPartitionCreateDescResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}CreateDiagnosticPartition
class CreateDiagnosticPartition
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}CreateDiagnosticPartitionResponse
class CreateDiagnosticPartitionResponse
  def initialize
  end
end

# {urn:vim2}RenewLease
class RenewLease
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RenewLeaseResponse
class RenewLeaseResponse
  def initialize
  end
end

# {urn:vim2}ReleaseLease
class ReleaseLease
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}ReleaseLeaseResponse
class ReleaseLeaseResponse
  def initialize
  end
end

# {urn:vim2}UpdateDefaultPolicy
class UpdateDefaultPolicy
  attr_accessor :defaultPolicy

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, defaultPolicy = nil)
    @v__this = v__this
    @defaultPolicy = defaultPolicy
  end
end

# {urn:vim2}UpdateDefaultPolicyResponse
class UpdateDefaultPolicyResponse
  def initialize
  end
end

# {urn:vim2}EnableRuleset
class EnableRuleset
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}EnableRulesetResponse
class EnableRulesetResponse
  def initialize
  end
end

# {urn:vim2}DisableRuleset
class DisableRuleset
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}DisableRulesetResponse
class DisableRulesetResponse
  def initialize
  end
end

# {urn:vim2}RefreshFirewall
class RefreshFirewall
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RefreshFirewallResponse
class RefreshFirewallResponse
  def initialize
  end
end

# {urn:vim2}CreateUser
class CreateUser
  attr_accessor :user

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, user = nil)
    @v__this = v__this
    @user = user
  end
end

# {urn:vim2}CreateUserResponse
class CreateUserResponse
  def initialize
  end
end

# {urn:vim2}UpdateUser
class UpdateUser
  attr_accessor :user

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, user = nil)
    @v__this = v__this
    @user = user
  end
end

# {urn:vim2}UpdateUserResponse
class UpdateUserResponse
  def initialize
  end
end

# {urn:vim2}CreateGroup
class CreateGroup
  attr_accessor :group

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, group = nil)
    @v__this = v__this
    @group = group
  end
end

# {urn:vim2}CreateGroupResponse
class CreateGroupResponse
  def initialize
  end
end

# {urn:vim2}RemoveUser
class RemoveUser
  attr_accessor :userName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, userName = nil)
    @v__this = v__this
    @userName = userName
  end
end

# {urn:vim2}RemoveUserResponse
class RemoveUserResponse
  def initialize
  end
end

# {urn:vim2}RemoveGroup
class RemoveGroup
  attr_accessor :groupName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, groupName = nil)
    @v__this = v__this
    @groupName = groupName
  end
end

# {urn:vim2}RemoveGroupResponse
class RemoveGroupResponse
  def initialize
  end
end

# {urn:vim2}AssignUserToGroup
class AssignUserToGroup
  attr_accessor :user
  attr_accessor :group

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, user = nil, group = nil)
    @v__this = v__this
    @user = user
    @group = group
  end
end

# {urn:vim2}AssignUserToGroupResponse
class AssignUserToGroupResponse
  def initialize
  end
end

# {urn:vim2}UnassignUserFromGroup
class UnassignUserFromGroup
  attr_accessor :user
  attr_accessor :group

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, user = nil, group = nil)
    @v__this = v__this
    @user = user
    @group = group
  end
end

# {urn:vim2}UnassignUserFromGroupResponse
class UnassignUserFromGroupResponse
  def initialize
  end
end

# {urn:vim2}ReconfigureServiceConsoleReservation
class ReconfigureServiceConsoleReservation
  attr_accessor :cfgBytes

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, cfgBytes = nil)
    @v__this = v__this
    @cfgBytes = cfgBytes
  end
end

# {urn:vim2}ReconfigureServiceConsoleReservationResponse
class ReconfigureServiceConsoleReservationResponse
  def initialize
  end
end

# {urn:vim2}UpdateNetworkConfig
class UpdateNetworkConfig
  attr_accessor :config
  attr_accessor :changeMode

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil, changeMode = nil)
    @v__this = v__this
    @config = config
    @changeMode = changeMode
  end
end

# {urn:vim2}UpdateNetworkConfigResponse
class UpdateNetworkConfigResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UpdateDnsConfig
class UpdateDnsConfig
  attr_accessor :config

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil)
    @v__this = v__this
    @config = config
  end
end

# {urn:vim2}UpdateDnsConfigResponse
class UpdateDnsConfigResponse
  def initialize
  end
end

# {urn:vim2}UpdateIpRouteConfig
class UpdateIpRouteConfig
  attr_accessor :config

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil)
    @v__this = v__this
    @config = config
  end
end

# {urn:vim2}UpdateIpRouteConfigResponse
class UpdateIpRouteConfigResponse
  def initialize
  end
end

# {urn:vim2}UpdateConsoleIpRouteConfig
class UpdateConsoleIpRouteConfig
  attr_accessor :config

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil)
    @v__this = v__this
    @config = config
  end
end

# {urn:vim2}UpdateConsoleIpRouteConfigResponse
class UpdateConsoleIpRouteConfigResponse
  def initialize
  end
end

# {urn:vim2}AddVirtualSwitch
class AddVirtualSwitch
  attr_accessor :vswitchName
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vswitchName = nil, spec = nil)
    @v__this = v__this
    @vswitchName = vswitchName
    @spec = spec
  end
end

# {urn:vim2}AddVirtualSwitchResponse
class AddVirtualSwitchResponse
  def initialize
  end
end

# {urn:vim2}RemoveVirtualSwitch
class RemoveVirtualSwitch
  attr_accessor :vswitchName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vswitchName = nil)
    @v__this = v__this
    @vswitchName = vswitchName
  end
end

# {urn:vim2}RemoveVirtualSwitchResponse
class RemoveVirtualSwitchResponse
  def initialize
  end
end

# {urn:vim2}UpdateVirtualSwitch
class UpdateVirtualSwitch
  attr_accessor :vswitchName
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vswitchName = nil, spec = nil)
    @v__this = v__this
    @vswitchName = vswitchName
    @spec = spec
  end
end

# {urn:vim2}UpdateVirtualSwitchResponse
class UpdateVirtualSwitchResponse
  def initialize
  end
end

# {urn:vim2}AddPortGroup
class AddPortGroup
  attr_accessor :portgrp

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, portgrp = nil)
    @v__this = v__this
    @portgrp = portgrp
  end
end

# {urn:vim2}AddPortGroupResponse
class AddPortGroupResponse
  def initialize
  end
end

# {urn:vim2}RemovePortGroup
class RemovePortGroup
  attr_accessor :pgName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pgName = nil)
    @v__this = v__this
    @pgName = pgName
  end
end

# {urn:vim2}RemovePortGroupResponse
class RemovePortGroupResponse
  def initialize
  end
end

# {urn:vim2}UpdatePortGroup
class UpdatePortGroup
  attr_accessor :pgName
  attr_accessor :portgrp

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pgName = nil, portgrp = nil)
    @v__this = v__this
    @pgName = pgName
    @portgrp = portgrp
  end
end

# {urn:vim2}UpdatePortGroupResponse
class UpdatePortGroupResponse
  def initialize
  end
end

# {urn:vim2}UpdatePhysicalNicLinkSpeed
class UpdatePhysicalNicLinkSpeed
  attr_accessor :device
  attr_accessor :linkSpeed

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil, linkSpeed = nil)
    @v__this = v__this
    @device = device
    @linkSpeed = linkSpeed
  end
end

# {urn:vim2}UpdatePhysicalNicLinkSpeedResponse
class UpdatePhysicalNicLinkSpeedResponse
  def initialize
  end
end

# {urn:vim2}QueryNetworkHint
class QueryNetworkHint
  attr_accessor :device

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = [])
    @v__this = v__this
    @device = device
  end
end

# {urn:vim2}QueryNetworkHintResponse
class QueryNetworkHintResponse < ::Array
end

# {urn:vim2}AddVirtualNic
class AddVirtualNic
  attr_accessor :portgroup
  attr_accessor :nic

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, portgroup = nil, nic = nil)
    @v__this = v__this
    @portgroup = portgroup
    @nic = nic
  end
end

# {urn:vim2}AddVirtualNicResponse
class AddVirtualNicResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveVirtualNic
class RemoveVirtualNic
  attr_accessor :device

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil)
    @v__this = v__this
    @device = device
  end
end

# {urn:vim2}RemoveVirtualNicResponse
class RemoveVirtualNicResponse
  def initialize
  end
end

# {urn:vim2}UpdateVirtualNic
class UpdateVirtualNic
  attr_accessor :device
  attr_accessor :nic

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil, nic = nil)
    @v__this = v__this
    @device = device
    @nic = nic
  end
end

# {urn:vim2}UpdateVirtualNicResponse
class UpdateVirtualNicResponse
  def initialize
  end
end

# {urn:vim2}AddServiceConsoleVirtualNic
class AddServiceConsoleVirtualNic
  attr_accessor :portgroup
  attr_accessor :nic

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, portgroup = nil, nic = nil)
    @v__this = v__this
    @portgroup = portgroup
    @nic = nic
  end
end

# {urn:vim2}AddServiceConsoleVirtualNicResponse
class AddServiceConsoleVirtualNicResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveServiceConsoleVirtualNic
class RemoveServiceConsoleVirtualNic
  attr_accessor :device

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil)
    @v__this = v__this
    @device = device
  end
end

# {urn:vim2}RemoveServiceConsoleVirtualNicResponse
class RemoveServiceConsoleVirtualNicResponse
  def initialize
  end
end

# {urn:vim2}UpdateServiceConsoleVirtualNic
class UpdateServiceConsoleVirtualNic
  attr_accessor :device
  attr_accessor :nic

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil, nic = nil)
    @v__this = v__this
    @device = device
    @nic = nic
  end
end

# {urn:vim2}UpdateServiceConsoleVirtualNicResponse
class UpdateServiceConsoleVirtualNicResponse
  def initialize
  end
end

# {urn:vim2}RestartServiceConsoleVirtualNic
class RestartServiceConsoleVirtualNic
  attr_accessor :device

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil)
    @v__this = v__this
    @device = device
  end
end

# {urn:vim2}RestartServiceConsoleVirtualNicResponse
class RestartServiceConsoleVirtualNicResponse
  def initialize
  end
end

# {urn:vim2}RefreshNetworkSystem
class RefreshNetworkSystem
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RefreshNetworkSystemResponse
class RefreshNetworkSystemResponse
  def initialize
  end
end

# {urn:vim2}UpdateServicePolicy
class UpdateServicePolicy
  attr_accessor :id
  attr_accessor :policy

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil, policy = nil)
    @v__this = v__this
    @id = id
    @policy = policy
  end
end

# {urn:vim2}UpdateServicePolicyResponse
class UpdateServicePolicyResponse
  def initialize
  end
end

# {urn:vim2}StartService
class StartService
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}StartServiceResponse
class StartServiceResponse
  def initialize
  end
end

# {urn:vim2}StopService
class StopService
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}StopServiceResponse
class StopServiceResponse
  def initialize
  end
end

# {urn:vim2}RestartService
class RestartService
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}RestartServiceResponse
class RestartServiceResponse
  def initialize
  end
end

# {urn:vim2}UninstallService
class UninstallService
  attr_accessor :id

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, id = nil)
    @v__this = v__this
    @id = id
  end
end

# {urn:vim2}UninstallServiceResponse
class UninstallServiceResponse
  def initialize
  end
end

# {urn:vim2}RefreshServices
class RefreshServices
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RefreshServicesResponse
class RefreshServicesResponse
  def initialize
  end
end

# {urn:vim2}CheckIfMasterSnmpAgentRunning
class CheckIfMasterSnmpAgentRunning
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}CheckIfMasterSnmpAgentRunningResponse
class CheckIfMasterSnmpAgentRunningResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UpdateSnmpConfig
class UpdateSnmpConfig
  attr_accessor :config

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, config = nil)
    @v__this = v__this
    @config = config
  end
end

# {urn:vim2}UpdateSnmpConfigResponse
class UpdateSnmpConfigResponse
  def initialize
  end
end

# {urn:vim2}RestartMasterSnmpAgent
class RestartMasterSnmpAgent
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RestartMasterSnmpAgentResponse
class RestartMasterSnmpAgentResponse
  def initialize
  end
end

# {urn:vim2}StopMasterSnmpAgent
class StopMasterSnmpAgent
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}StopMasterSnmpAgentResponse
class StopMasterSnmpAgentResponse
  def initialize
  end
end

# {urn:vim2}RetrieveDiskPartitionInfo
class RetrieveDiskPartitionInfo
  attr_accessor :devicePath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, devicePath = [])
    @v__this = v__this
    @devicePath = devicePath
  end
end

# {urn:vim2}RetrieveDiskPartitionInfoResponse
class RetrieveDiskPartitionInfoResponse < ::Array
end

# {urn:vim2}ComputeDiskPartitionInfo
class ComputeDiskPartitionInfo
  attr_accessor :devicePath
  attr_accessor :layout

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, devicePath = nil, layout = nil)
    @v__this = v__this
    @devicePath = devicePath
    @layout = layout
  end
end

# {urn:vim2}ComputeDiskPartitionInfoResponse
class ComputeDiskPartitionInfoResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}UpdateDiskPartitions
class UpdateDiskPartitions
  attr_accessor :devicePath
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, devicePath = nil, spec = nil)
    @v__this = v__this
    @devicePath = devicePath
    @spec = spec
  end
end

# {urn:vim2}UpdateDiskPartitionsResponse
class UpdateDiskPartitionsResponse
  def initialize
  end
end

# {urn:vim2}FormatVmfs
class FormatVmfs
  attr_accessor :createSpec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, createSpec = nil)
    @v__this = v__this
    @createSpec = createSpec
  end
end

# {urn:vim2}FormatVmfsResponse
class FormatVmfsResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RescanVmfs
class RescanVmfs
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RescanVmfsResponse
class RescanVmfsResponse
  def initialize
  end
end

# {urn:vim2}AttachVmfsExtent
class AttachVmfsExtent
  attr_accessor :vmfsPath
  attr_accessor :extent

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vmfsPath = nil, extent = nil)
    @v__this = v__this
    @vmfsPath = vmfsPath
    @extent = extent
  end
end

# {urn:vim2}AttachVmfsExtentResponse
class AttachVmfsExtentResponse
  def initialize
  end
end

# {urn:vim2}UpgradeVmfs
class UpgradeVmfs
  attr_accessor :vmfsPath

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, vmfsPath = nil)
    @v__this = v__this
    @vmfsPath = vmfsPath
  end
end

# {urn:vim2}UpgradeVmfsResponse
class UpgradeVmfsResponse
  def initialize
  end
end

# {urn:vim2}UpgradeVmLayout
class UpgradeVmLayout
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}UpgradeVmLayoutResponse
class UpgradeVmLayoutResponse
  def initialize
  end
end

# {urn:vim2}RescanHba
class RescanHba
  attr_accessor :hbaDevice

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, hbaDevice = nil)
    @v__this = v__this
    @hbaDevice = hbaDevice
  end
end

# {urn:vim2}RescanHbaResponse
class RescanHbaResponse
  def initialize
  end
end

# {urn:vim2}RescanAllHba
class RescanAllHba
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RescanAllHbaResponse
class RescanAllHbaResponse
  def initialize
  end
end

# {urn:vim2}UpdateSoftwareInternetScsiEnabled
class UpdateSoftwareInternetScsiEnabled
  attr_accessor :enabled

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, enabled = nil)
    @v__this = v__this
    @enabled = enabled
  end
end

# {urn:vim2}UpdateSoftwareInternetScsiEnabledResponse
class UpdateSoftwareInternetScsiEnabledResponse
  def initialize
  end
end

# {urn:vim2}UpdateInternetScsiDiscoveryProperties
class UpdateInternetScsiDiscoveryProperties
  attr_accessor :iScsiHbaDevice
  attr_accessor :discoveryProperties

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, discoveryProperties = nil)
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @discoveryProperties = discoveryProperties
  end
end

# {urn:vim2}UpdateInternetScsiDiscoveryPropertiesResponse
class UpdateInternetScsiDiscoveryPropertiesResponse
  def initialize
  end
end

# {urn:vim2}UpdateInternetScsiAuthenticationProperties
class UpdateInternetScsiAuthenticationProperties
  attr_accessor :iScsiHbaDevice
  attr_accessor :authenticationProperties

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, authenticationProperties = nil)
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @authenticationProperties = authenticationProperties
  end
end

# {urn:vim2}UpdateInternetScsiAuthenticationPropertiesResponse
class UpdateInternetScsiAuthenticationPropertiesResponse
  def initialize
  end
end

# {urn:vim2}UpdateInternetScsiIPProperties
class UpdateInternetScsiIPProperties
  attr_accessor :iScsiHbaDevice
  attr_accessor :ipProperties

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, ipProperties = nil)
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @ipProperties = ipProperties
  end
end

# {urn:vim2}UpdateInternetScsiIPPropertiesResponse
class UpdateInternetScsiIPPropertiesResponse
  def initialize
  end
end

# {urn:vim2}UpdateInternetScsiName
class UpdateInternetScsiName
  attr_accessor :iScsiHbaDevice
  attr_accessor :iScsiName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, iScsiName = nil)
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @iScsiName = iScsiName
  end
end

# {urn:vim2}UpdateInternetScsiNameResponse
class UpdateInternetScsiNameResponse
  def initialize
  end
end

# {urn:vim2}UpdateInternetScsiAlias
class UpdateInternetScsiAlias
  attr_accessor :iScsiHbaDevice
  attr_accessor :iScsiAlias

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, iScsiAlias = nil)
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @iScsiAlias = iScsiAlias
  end
end

# {urn:vim2}UpdateInternetScsiAliasResponse
class UpdateInternetScsiAliasResponse
  def initialize
  end
end

# {urn:vim2}AddInternetScsiSendTargets
class AddInternetScsiSendTargets
  attr_accessor :iScsiHbaDevice
  attr_accessor :targets

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, targets = [])
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @targets = targets
  end
end

# {urn:vim2}AddInternetScsiSendTargetsResponse
class AddInternetScsiSendTargetsResponse
  def initialize
  end
end

# {urn:vim2}RemoveInternetScsiSendTargets
class RemoveInternetScsiSendTargets
  attr_accessor :iScsiHbaDevice
  attr_accessor :targets

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, targets = [])
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @targets = targets
  end
end

# {urn:vim2}RemoveInternetScsiSendTargetsResponse
class RemoveInternetScsiSendTargetsResponse
  def initialize
  end
end

# {urn:vim2}AddInternetScsiStaticTargets
class AddInternetScsiStaticTargets
  attr_accessor :iScsiHbaDevice
  attr_accessor :targets

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, targets = [])
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @targets = targets
  end
end

# {urn:vim2}AddInternetScsiStaticTargetsResponse
class AddInternetScsiStaticTargetsResponse
  def initialize
  end
end

# {urn:vim2}RemoveInternetScsiStaticTargets
class RemoveInternetScsiStaticTargets
  attr_accessor :iScsiHbaDevice
  attr_accessor :targets

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, iScsiHbaDevice = nil, targets = [])
    @v__this = v__this
    @iScsiHbaDevice = iScsiHbaDevice
    @targets = targets
  end
end

# {urn:vim2}RemoveInternetScsiStaticTargetsResponse
class RemoveInternetScsiStaticTargetsResponse
  def initialize
  end
end

# {urn:vim2}EnableMultipathPath
class EnableMultipathPath
  attr_accessor :pathName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pathName = nil)
    @v__this = v__this
    @pathName = pathName
  end
end

# {urn:vim2}EnableMultipathPathResponse
class EnableMultipathPathResponse
  def initialize
  end
end

# {urn:vim2}DisableMultipathPath
class DisableMultipathPath
  attr_accessor :pathName

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, pathName = nil)
    @v__this = v__this
    @pathName = pathName
  end
end

# {urn:vim2}DisableMultipathPathResponse
class DisableMultipathPathResponse
  def initialize
  end
end

# {urn:vim2}SetMultipathLunPolicy
class SetMultipathLunPolicy
  attr_accessor :lunId
  attr_accessor :policy

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, lunId = nil, policy = nil)
    @v__this = v__this
    @lunId = lunId
    @policy = policy
  end
end

# {urn:vim2}SetMultipathLunPolicyResponse
class SetMultipathLunPolicyResponse
  def initialize
  end
end

# {urn:vim2}RefreshStorageSystem
class RefreshStorageSystem
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RefreshStorageSystemResponse
class RefreshStorageSystemResponse
  def initialize
  end
end

# {urn:vim2}UpdateIpConfig
class UpdateIpConfig
  attr_accessor :ipConfig

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, ipConfig = nil)
    @v__this = v__this
    @ipConfig = ipConfig
  end
end

# {urn:vim2}UpdateIpConfigResponse
class UpdateIpConfigResponse
  def initialize
  end
end

# {urn:vim2}SelectVnic
class SelectVnic
  attr_accessor :device

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, device = nil)
    @v__this = v__this
    @device = device
  end
end

# {urn:vim2}SelectVnicResponse
class SelectVnicResponse
  def initialize
  end
end

# {urn:vim2}DeselectVnic
class DeselectVnic
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}DeselectVnicResponse
class DeselectVnicResponse
  def initialize
  end
end

# {urn:vim2}QueryOptions
class QueryOptions
  attr_accessor :name

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil)
    @v__this = v__this
    @name = name
  end
end

# {urn:vim2}QueryOptionsResponse
class QueryOptionsResponse < ::Array
end

# {urn:vim2}UpdateOptions
class UpdateOptions
  attr_accessor :changedValue

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, changedValue = [])
    @v__this = v__this
    @changedValue = changedValue
  end
end

# {urn:vim2}UpdateOptionsResponse
class UpdateOptionsResponse
  def initialize
  end
end

# {urn:vim2}RemoveScheduledTask
class RemoveScheduledTask
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RemoveScheduledTaskResponse
class RemoveScheduledTaskResponse
  def initialize
  end
end

# {urn:vim2}ReconfigureScheduledTask
class ReconfigureScheduledTask
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, spec = nil)
    @v__this = v__this
    @spec = spec
  end
end

# {urn:vim2}ReconfigureScheduledTaskResponse
class ReconfigureScheduledTaskResponse
  def initialize
  end
end

# {urn:vim2}RunScheduledTask
class RunScheduledTask
  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil)
    @v__this = v__this
  end
end

# {urn:vim2}RunScheduledTaskResponse
class RunScheduledTaskResponse
  def initialize
  end
end

# {urn:vim2}CreateScheduledTask
class CreateScheduledTask
  attr_accessor :entity
  attr_accessor :spec

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil, spec = nil)
    @v__this = v__this
    @entity = entity
    @spec = spec
  end
end

# {urn:vim2}CreateScheduledTaskResponse
class CreateScheduledTaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RetrieveEntityScheduledTask
class RetrieveEntityScheduledTask
  attr_accessor :entity

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, entity = nil)
    @v__this = v__this
    @entity = entity
  end
end

# {urn:vim2}RetrieveEntityScheduledTaskResponse
class RetrieveEntityScheduledTaskResponse < ::Array
end

# {urn:vim2}RevertToSnapshot_Task
class RevertToSnapshot_Task
  attr_accessor :host

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, host = nil)
    @v__this = v__this
    @host = host
  end
end

# {urn:vim2}RevertToSnapshot_TaskResponse
class RevertToSnapshot_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RemoveSnapshot_Task
class RemoveSnapshot_Task
  attr_accessor :removeChildren

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, removeChildren = nil)
    @v__this = v__this
    @removeChildren = removeChildren
  end
end

# {urn:vim2}RemoveSnapshot_TaskResponse
class RemoveSnapshot_TaskResponse
  attr_accessor :returnval

  def initialize(returnval = nil)
    @returnval = returnval
  end
end

# {urn:vim2}RenameSnapshot
class RenameSnapshot
  attr_accessor :name
  attr_accessor :description

  def m__this
    @v__this
  end

  def m__this=(value)
    @v__this = value
  end

  def initialize(v__this = nil, name = nil, description = nil)
    @v__this = v__this
    @name = name
    @description = description
  end
end

# {urn:vim2}RenameSnapshotResponse
class RenameSnapshotResponse
  def initialize
  end
end

# {urn:vim2}DynamicArray
class DynamicArray
  attr_accessor :dynamicType
  attr_accessor :val

  def initialize(dynamicType = nil, val = [])
    @dynamicType = dynamicType
    @val = val
  end
end

# {urn:vim2}DynamicData
class DynamicData
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}DynamicProperty
class DynamicProperty
  attr_accessor :name
  attr_accessor :val

  def initialize(name = nil, val = nil)
    @name = name
    @val = val
  end
end

# {urn:vim2}ArrayOfDynamicProperty
class ArrayOfDynamicProperty < ::Array
end

# {urn:vim2}HostCommunication
class HostCommunication
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostNotConnected
class HostNotConnected
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostNotReachable
class HostNotReachable
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidArgument
class InvalidArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :invalidProperty

  def initialize(dynamicType = nil, dynamicProperty = [], invalidProperty = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @invalidProperty = invalidProperty
  end
end

# {urn:vim2}InvalidRequest
class InvalidRequest
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidType
class InvalidType
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :argument

  def initialize(dynamicType = nil, dynamicProperty = [], argument = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @argument = argument
  end
end

# {urn:vim2}ManagedObjectNotFound
class ManagedObjectNotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :obj

  def initialize(dynamicType = nil, dynamicProperty = [], obj = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @obj = obj
  end
end

# {urn:vim2}MethodNotFound
class MethodNotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :receiver
  attr_accessor :method

  def initialize(dynamicType = nil, dynamicProperty = [], receiver = nil, method = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @receiver = receiver
    @method = method
  end
end

# {urn:vim2}NotEnoughLicenses
class NotEnoughLicenses
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NotImplemented
class NotImplemented
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NotSupported
class NotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}RequestCanceled
class RequestCanceled
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}SecurityError
class SecurityError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}SystemError
class SystemError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @reason = reason
  end
end

# {urn:vim2}InvalidCollectorVersion
class InvalidCollectorVersion
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidProperty
class InvalidProperty
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}PropertyFilterSpec
class PropertyFilterSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :propSet
  attr_accessor :objectSet

  def initialize(dynamicType = nil, dynamicProperty = [], propSet = [], objectSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @propSet = propSet
    @objectSet = objectSet
  end
end

# {urn:vim2}ArrayOfPropertyFilterSpec
class ArrayOfPropertyFilterSpec < ::Array
end

# {urn:vim2}PropertySpec
class PropertySpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :all
  attr_accessor :pathSet

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, all = nil, pathSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @all = all
    @pathSet = pathSet
  end
end

# {urn:vim2}ArrayOfPropertySpec
class ArrayOfPropertySpec < ::Array
end

# {urn:vim2}ObjectSpec
class ObjectSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :obj
  attr_accessor :skip
  attr_accessor :selectSet

  def initialize(dynamicType = nil, dynamicProperty = [], obj = nil, skip = nil, selectSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @obj = obj
    @skip = skip
    @selectSet = selectSet
  end
end

# {urn:vim2}ArrayOfObjectSpec
class ArrayOfObjectSpec < ::Array
end

# {urn:vim2}SelectionSpec
class SelectionSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}ArrayOfSelectionSpec
class ArrayOfSelectionSpec < ::Array
end

# {urn:vim2}TraversalSpec
class TraversalSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :type
  attr_accessor :path
  attr_accessor :skip
  attr_accessor :selectSet

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, type = nil, path = nil, skip = nil, selectSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @type = type
    @path = path
    @skip = skip
    @selectSet = selectSet
  end
end

# {urn:vim2}ObjectContent
class ObjectContent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :obj
  attr_accessor :propSet
  attr_accessor :missingSet

  def initialize(dynamicType = nil, dynamicProperty = [], obj = nil, propSet = [], missingSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @obj = obj
    @propSet = propSet
    @missingSet = missingSet
  end
end

# {urn:vim2}ArrayOfObjectContent
class ArrayOfObjectContent < ::Array
end

# {urn:vim2}UpdateSet
class UpdateSet
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :version
  attr_accessor :filterSet

  def initialize(dynamicType = nil, dynamicProperty = [], version = nil, filterSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @version = version
    @filterSet = filterSet
  end
end

# {urn:vim2}PropertyFilterUpdate
class PropertyFilterUpdate
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :filter
  attr_accessor :objectSet
  attr_accessor :missingSet

  def initialize(dynamicType = nil, dynamicProperty = [], filter = nil, objectSet = [], missingSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @filter = filter
    @objectSet = objectSet
    @missingSet = missingSet
  end
end

# {urn:vim2}ArrayOfPropertyFilterUpdate
class ArrayOfPropertyFilterUpdate < ::Array
end

# {urn:vim2}ObjectUpdate
class ObjectUpdate
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :kind
  attr_accessor :obj
  attr_accessor :changeSet
  attr_accessor :missingSet

  def initialize(dynamicType = nil, dynamicProperty = [], kind = nil, obj = nil, changeSet = [], missingSet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @kind = kind
    @obj = obj
    @changeSet = changeSet
    @missingSet = missingSet
  end
end

# {urn:vim2}ArrayOfObjectUpdate
class ArrayOfObjectUpdate < ::Array
end

# {urn:vim2}PropertyChange
class PropertyChange
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :op
  attr_accessor :val

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, op = nil, val = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @op = op
    @val = val
  end
end

# {urn:vim2}ArrayOfPropertyChange
class ArrayOfPropertyChange < ::Array
end

# {urn:vim2}MissingProperty
class MissingProperty
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fault = fault
  end
end

# {urn:vim2}ArrayOfMissingProperty
class ArrayOfMissingProperty < ::Array
end

# {urn:vim2}MissingObject
class MissingObject
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :obj
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], obj = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @obj = obj
    @fault = fault
  end
end

# {urn:vim2}ArrayOfMissingObject
class ArrayOfMissingObject < ::Array
end

# {urn:vim2}LocalizedMethodFault
class LocalizedMethodFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fault
  attr_accessor :localizedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], fault = nil, localizedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fault = fault
    @localizedMessage = localizedMessage
  end
end

# {urn:vim2}MethodFault
class MethodFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}RuntimeFault
class RuntimeFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}AboutInfo
class AboutInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :fullName
  attr_accessor :vendor
  attr_accessor :version
  attr_accessor :build
  attr_accessor :localeVersion
  attr_accessor :localeBuild
  attr_accessor :osType
  attr_accessor :productLineId
  attr_accessor :apiType
  attr_accessor :apiVersion

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, fullName = nil, vendor = nil, version = nil, build = nil, localeVersion = nil, localeBuild = nil, osType = nil, productLineId = nil, apiType = nil, apiVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @fullName = fullName
    @vendor = vendor
    @version = version
    @build = build
    @localeVersion = localeVersion
    @localeBuild = localeBuild
    @osType = osType
    @productLineId = productLineId
    @apiType = apiType
    @apiVersion = apiVersion
  end
end

# {urn:vim2}AuthorizationDescription
class AuthorizationDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :privilege
  attr_accessor :privilegeGroup

  def initialize(dynamicType = nil, dynamicProperty = [], privilege = [], privilegeGroup = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @privilege = privilege
    @privilegeGroup = privilegeGroup
  end
end

# {urn:vim2}Permission
class Permission
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :principal
  attr_accessor :group
  attr_accessor :roleId
  attr_accessor :propagate

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, principal = nil, group = nil, roleId = nil, propagate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @principal = principal
    @group = group
    @roleId = roleId
    @propagate = propagate
  end
end

# {urn:vim2}ArrayOfPermission
class ArrayOfPermission < ::Array
end

# {urn:vim2}AuthorizationRole
class AuthorizationRole
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :roleId
  attr_accessor :system
  attr_accessor :name
  attr_accessor :info
  attr_accessor :privilege

  def initialize(dynamicType = nil, dynamicProperty = [], roleId = nil, system = nil, name = nil, info = nil, privilege = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @roleId = roleId
    @system = system
    @name = name
    @info = info
    @privilege = privilege
  end
end

# {urn:vim2}ArrayOfAuthorizationRole
class ArrayOfAuthorizationRole < ::Array
end

# {urn:vim2}AuthorizationPrivilege
class AuthorizationPrivilege
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :privId
  attr_accessor :onParent
  attr_accessor :name
  attr_accessor :privGroupName

  def initialize(dynamicType = nil, dynamicProperty = [], privId = nil, onParent = nil, name = nil, privGroupName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @privId = privId
    @onParent = onParent
    @name = name
    @privGroupName = privGroupName
  end
end

# {urn:vim2}ArrayOfAuthorizationPrivilege
class ArrayOfAuthorizationPrivilege < ::Array
end

# {urn:vim2}Capability
class Capability
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :provisioningSupported
  attr_accessor :multiHostSupported

  def initialize(dynamicType = nil, dynamicProperty = [], provisioningSupported = nil, multiHostSupported = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @provisioningSupported = provisioningSupported
    @multiHostSupported = multiHostSupported
  end
end

# {urn:vim2}ClusterComputeResourceSummary
class ClusterComputeResourceSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :totalCpu
  attr_accessor :totalMemory
  attr_accessor :numCpuCores
  attr_accessor :numCpuThreads
  attr_accessor :effectiveCpu
  attr_accessor :effectiveMemory
  attr_accessor :numHosts
  attr_accessor :numEffectiveHosts
  attr_accessor :overallStatus
  attr_accessor :currentFailoverLevel
  attr_accessor :numVmotions

  def initialize(dynamicType = nil, dynamicProperty = [], totalCpu = nil, totalMemory = nil, numCpuCores = nil, numCpuThreads = nil, effectiveCpu = nil, effectiveMemory = nil, numHosts = nil, numEffectiveHosts = nil, overallStatus = nil, currentFailoverLevel = nil, numVmotions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @totalCpu = totalCpu
    @totalMemory = totalMemory
    @numCpuCores = numCpuCores
    @numCpuThreads = numCpuThreads
    @effectiveCpu = effectiveCpu
    @effectiveMemory = effectiveMemory
    @numHosts = numHosts
    @numEffectiveHosts = numEffectiveHosts
    @overallStatus = overallStatus
    @currentFailoverLevel = currentFailoverLevel
    @numVmotions = numVmotions
  end
end

# {urn:vim2}ComputeResourceSummary
class ComputeResourceSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :totalCpu
  attr_accessor :totalMemory
  attr_accessor :numCpuCores
  attr_accessor :numCpuThreads
  attr_accessor :effectiveCpu
  attr_accessor :effectiveMemory
  attr_accessor :numHosts
  attr_accessor :numEffectiveHosts
  attr_accessor :overallStatus

  def initialize(dynamicType = nil, dynamicProperty = [], totalCpu = nil, totalMemory = nil, numCpuCores = nil, numCpuThreads = nil, effectiveCpu = nil, effectiveMemory = nil, numHosts = nil, numEffectiveHosts = nil, overallStatus = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @totalCpu = totalCpu
    @totalMemory = totalMemory
    @numCpuCores = numCpuCores
    @numCpuThreads = numCpuThreads
    @effectiveCpu = effectiveCpu
    @effectiveMemory = effectiveMemory
    @numHosts = numHosts
    @numEffectiveHosts = numEffectiveHosts
    @overallStatus = overallStatus
  end
end

# {urn:vim2}CustomFieldDef
class CustomFieldDef
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :name
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, name = nil, type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @name = name
    @type = type
  end
end

# {urn:vim2}ArrayOfCustomFieldDef
class ArrayOfCustomFieldDef < ::Array
end

# {urn:vim2}CustomFieldValue
class CustomFieldValue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
  end
end

# {urn:vim2}ArrayOfCustomFieldValue
class ArrayOfCustomFieldValue < ::Array
end

# {urn:vim2}CustomFieldStringValue
class CustomFieldStringValue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @value = value
  end
end

# {urn:vim2}CustomizationSpecInfo
class CustomizationSpecInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :description
  attr_accessor :type
  attr_accessor :changeVersion
  attr_accessor :lastUpdateTime

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, description = nil, type = nil, changeVersion = nil, lastUpdateTime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @description = description
    @type = type
    @changeVersion = changeVersion
    @lastUpdateTime = lastUpdateTime
  end
end

# {urn:vim2}ArrayOfCustomizationSpecInfo
class ArrayOfCustomizationSpecInfo < ::Array
end

# {urn:vim2}CustomizationSpecItem
class CustomizationSpecItem
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :info
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], info = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @info = info
    @spec = spec
  end
end

# {urn:vim2}DatastoreSummary
class DatastoreSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :name
  attr_accessor :url
  attr_accessor :capacity
  attr_accessor :freeSpace
  attr_accessor :accessible
  attr_accessor :multipleHostAccess
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, name = nil, url = nil, capacity = nil, freeSpace = nil, accessible = nil, multipleHostAccess = nil, type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @name = name
    @url = url
    @capacity = capacity
    @freeSpace = freeSpace
    @accessible = accessible
    @multipleHostAccess = multipleHostAccess
    @type = type
  end
end

# {urn:vim2}DatastoreInfo
class DatastoreInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :url
  attr_accessor :freeSpace
  attr_accessor :maxFileSize

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, url = nil, freeSpace = nil, maxFileSize = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @url = url
    @freeSpace = freeSpace
    @maxFileSize = maxFileSize
  end
end

# {urn:vim2}DatastoreCapability
class DatastoreCapability
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :directoryHierarchySupported
  attr_accessor :rawDiskMappingsSupported
  attr_accessor :perFileThinProvisioningSupported

  def initialize(dynamicType = nil, dynamicProperty = [], directoryHierarchySupported = nil, rawDiskMappingsSupported = nil, perFileThinProvisioningSupported = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @directoryHierarchySupported = directoryHierarchySupported
    @rawDiskMappingsSupported = rawDiskMappingsSupported
    @perFileThinProvisioningSupported = perFileThinProvisioningSupported
  end
end

# {urn:vim2}DatastoreHostMount
class DatastoreHostMount
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :mountInfo

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, mountInfo = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @mountInfo = mountInfo
  end
end

# {urn:vim2}ArrayOfDatastoreHostMount
class ArrayOfDatastoreHostMount < ::Array
end

# {urn:vim2}Description
class Description
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
  end
end

# {urn:vim2}DiagnosticManagerLogDescriptor
class DiagnosticManagerLogDescriptor
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :fileName
  attr_accessor :creator
  attr_accessor :format
  attr_accessor :mimeType
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, fileName = nil, creator = nil, format = nil, mimeType = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @fileName = fileName
    @creator = creator
    @format = format
    @mimeType = mimeType
    @info = info
  end
end

# {urn:vim2}ArrayOfDiagnosticManagerLogDescriptor
class ArrayOfDiagnosticManagerLogDescriptor < ::Array
end

# {urn:vim2}DiagnosticManagerLogHeader
class DiagnosticManagerLogHeader
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :lineStart
  attr_accessor :lineEnd
  attr_accessor :lineText

  def initialize(dynamicType = nil, dynamicProperty = [], lineStart = nil, lineEnd = nil, lineText = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @lineStart = lineStart
    @lineEnd = lineEnd
    @lineText = lineText
  end
end

# {urn:vim2}DiagnosticManagerBundleInfo
class DiagnosticManagerBundleInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :system
  attr_accessor :url

  def initialize(dynamicType = nil, dynamicProperty = [], system = nil, url = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @system = system
    @url = url
  end
end

# {urn:vim2}ArrayOfDiagnosticManagerBundleInfo
class ArrayOfDiagnosticManagerBundleInfo < ::Array
end

# {urn:vim2}ElementDescription
class ElementDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary
  attr_accessor :key

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil, key = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
    @key = key
  end
end

# {urn:vim2}ArrayOfElementDescription
class ArrayOfElementDescription < ::Array
end

# {urn:vim2}HostServiceTicket
class HostServiceTicket
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :port
  attr_accessor :service
  attr_accessor :serviceVersion
  attr_accessor :sessionId

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, port = nil, service = nil, serviceVersion = nil, sessionId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @port = port
    @service = service
    @serviceVersion = serviceVersion
    @sessionId = sessionId
  end
end

# {urn:vim2}LicenseSource
class LicenseSource
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}LicenseServerSource
class LicenseServerSource
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :licenseServer

  def initialize(dynamicType = nil, dynamicProperty = [], licenseServer = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @licenseServer = licenseServer
  end
end

# {urn:vim2}LocalLicenseSource
class LocalLicenseSource
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :licenseKeys

  def initialize(dynamicType = nil, dynamicProperty = [], licenseKeys = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @licenseKeys = licenseKeys
  end
end

# {urn:vim2}LicenseFeatureInfo
class LicenseFeatureInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :featureName
  attr_accessor :state
  attr_accessor :costUnit

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, featureName = nil, state = nil, costUnit = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @featureName = featureName
    @state = state
    @costUnit = costUnit
  end
end

# {urn:vim2}ArrayOfLicenseFeatureInfo
class ArrayOfLicenseFeatureInfo < ::Array
end

# {urn:vim2}LicenseReservationInfo
class LicenseReservationInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :state
  attr_accessor :required

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, state = nil, required = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @state = state
    @required = required
  end
end

# {urn:vim2}ArrayOfLicenseReservationInfo
class ArrayOfLicenseReservationInfo < ::Array
end

# {urn:vim2}LicenseAvailabilityInfo
class LicenseAvailabilityInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :feature
  attr_accessor :total
  attr_accessor :available

  def initialize(dynamicType = nil, dynamicProperty = [], feature = nil, total = nil, available = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @feature = feature
    @total = total
    @available = available
  end
end

# {urn:vim2}ArrayOfLicenseAvailabilityInfo
class ArrayOfLicenseAvailabilityInfo < ::Array
end

# {urn:vim2}LicenseUsageInfo
class LicenseUsageInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :source
  attr_accessor :sourceAvailable
  attr_accessor :reservationInfo
  attr_accessor :featureInfo

  def initialize(dynamicType = nil, dynamicProperty = [], source = nil, sourceAvailable = nil, reservationInfo = [], featureInfo = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @source = source
    @sourceAvailable = sourceAvailable
    @reservationInfo = reservationInfo
    @featureInfo = featureInfo
  end
end

# {urn:vim2}MethodDescription
class MethodDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary
  attr_accessor :key

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil, key = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
    @key = key
  end
end

# {urn:vim2}NetworkSummary
class NetworkSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :network
  attr_accessor :name
  attr_accessor :accessible

  def initialize(dynamicType = nil, dynamicProperty = [], network = nil, name = nil, accessible = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @network = network
    @name = name
    @accessible = accessible
  end
end

# {urn:vim2}PerformanceDescription
class PerformanceDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :counterType
  attr_accessor :statsType

  def initialize(dynamicType = nil, dynamicProperty = [], counterType = [], statsType = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @counterType = counterType
    @statsType = statsType
  end
end

# {urn:vim2}PerfProviderSummary
class PerfProviderSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :currentSupported
  attr_accessor :summarySupported
  attr_accessor :refreshRate

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, currentSupported = nil, summarySupported = nil, refreshRate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @currentSupported = currentSupported
    @summarySupported = summarySupported
    @refreshRate = refreshRate
  end
end

# {urn:vim2}PerfCounterInfo
class PerfCounterInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :nameInfo
  attr_accessor :groupInfo
  attr_accessor :unitInfo
  attr_accessor :rollupType
  attr_accessor :statsType
  attr_accessor :associatedCounterId

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, nameInfo = nil, groupInfo = nil, unitInfo = nil, rollupType = nil, statsType = nil, associatedCounterId = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @nameInfo = nameInfo
    @groupInfo = groupInfo
    @unitInfo = unitInfo
    @rollupType = rollupType
    @statsType = statsType
    @associatedCounterId = associatedCounterId
  end
end

# {urn:vim2}ArrayOfPerfCounterInfo
class ArrayOfPerfCounterInfo < ::Array
end

# {urn:vim2}PerfMetricId
class PerfMetricId
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :counterId
  attr_accessor :instance

  def initialize(dynamicType = nil, dynamicProperty = [], counterId = nil, instance = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @counterId = counterId
    @instance = instance
  end
end

# {urn:vim2}ArrayOfPerfMetricId
class ArrayOfPerfMetricId < ::Array
end

# {urn:vim2}PerfQuerySpec
class PerfQuerySpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :startTime
  attr_accessor :endTime
  attr_accessor :maxSample
  attr_accessor :metricId
  attr_accessor :intervalId
  attr_accessor :format

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, startTime = nil, endTime = nil, maxSample = nil, metricId = [], intervalId = nil, format = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @startTime = startTime
    @endTime = endTime
    @maxSample = maxSample
    @metricId = metricId
    @intervalId = intervalId
    @format = format
  end
end

# {urn:vim2}ArrayOfPerfQuerySpec
class ArrayOfPerfQuerySpec < ::Array
end

# {urn:vim2}PerfSampleInfo
class PerfSampleInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :timestamp
  attr_accessor :interval

  def initialize(dynamicType = nil, dynamicProperty = [], timestamp = nil, interval = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @timestamp = timestamp
    @interval = interval
  end
end

# {urn:vim2}ArrayOfPerfSampleInfo
class ArrayOfPerfSampleInfo < ::Array
end

# {urn:vim2}PerfMetricSeries
class PerfMetricSeries
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
  end
end

# {urn:vim2}ArrayOfPerfMetricSeries
class ArrayOfPerfMetricSeries < ::Array
end

# {urn:vim2}PerfMetricIntSeries
class PerfMetricIntSeries
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, value = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @value = value
  end
end

# {urn:vim2}PerfMetricSeriesCSV
class PerfMetricSeriesCSV
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @value = value
  end
end

# {urn:vim2}ArrayOfPerfMetricSeriesCSV
class ArrayOfPerfMetricSeriesCSV < ::Array
end

# {urn:vim2}PerfEntityMetricBase
class PerfEntityMetricBase
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
  end
end

# {urn:vim2}ArrayOfPerfEntityMetricBase
class ArrayOfPerfEntityMetricBase < ::Array
end

# {urn:vim2}PerfEntityMetric
class PerfEntityMetric
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :sampleInfo
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, sampleInfo = [], value = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @sampleInfo = sampleInfo
    @value = value
  end
end

# {urn:vim2}PerfEntityMetricCSV
class PerfEntityMetricCSV
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :sampleInfoCSV
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, sampleInfoCSV = nil, value = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @sampleInfoCSV = sampleInfoCSV
    @value = value
  end
end

# {urn:vim2}ArrayOfPerfEntityMetricCSV
class ArrayOfPerfEntityMetricCSV < ::Array
end

# {urn:vim2}PerfCompositeMetric
class PerfCompositeMetric
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :childEntity

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, childEntity = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @childEntity = childEntity
  end
end

# {urn:vim2}PerfInterval
class PerfInterval
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :samplingPeriod
  attr_accessor :name
  attr_accessor :length

  def initialize(dynamicType = nil, dynamicProperty = [], samplingPeriod = nil, name = nil, length = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @samplingPeriod = samplingPeriod
    @name = name
    @length = length
  end
end

# {urn:vim2}ArrayOfPerfInterval
class ArrayOfPerfInterval < ::Array
end

# {urn:vim2}ResourceAllocationInfo
class ResourceAllocationInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :reservation
  attr_accessor :expandableReservation
  attr_accessor :limit
  attr_accessor :shares

  def initialize(dynamicType = nil, dynamicProperty = [], reservation = nil, expandableReservation = nil, limit = nil, shares = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @reservation = reservation
    @expandableReservation = expandableReservation
    @limit = limit
    @shares = shares
  end
end

# {urn:vim2}ResourceConfigSpec
class ResourceConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :changeVersion
  attr_accessor :lastModified
  attr_accessor :cpuAllocation
  attr_accessor :memoryAllocation

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, changeVersion = nil, lastModified = nil, cpuAllocation = nil, memoryAllocation = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @changeVersion = changeVersion
    @lastModified = lastModified
    @cpuAllocation = cpuAllocation
    @memoryAllocation = memoryAllocation
  end
end

# {urn:vim2}ArrayOfResourceConfigSpec
class ArrayOfResourceConfigSpec < ::Array
end

# {urn:vim2}ResourcePoolResourceUsage
class ResourcePoolResourceUsage
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :reservationUsed
  attr_accessor :reservationUsedForVm
  attr_accessor :unreservedForPool
  attr_accessor :unreservedForVm
  attr_accessor :overallUsage
  attr_accessor :maxUsage

  def initialize(dynamicType = nil, dynamicProperty = [], reservationUsed = nil, reservationUsedForVm = nil, unreservedForPool = nil, unreservedForVm = nil, overallUsage = nil, maxUsage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @reservationUsed = reservationUsed
    @reservationUsedForVm = reservationUsedForVm
    @unreservedForPool = unreservedForPool
    @unreservedForVm = unreservedForVm
    @overallUsage = overallUsage
    @maxUsage = maxUsage
  end
end

# {urn:vim2}ResourcePoolRuntimeInfo
class ResourcePoolRuntimeInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :memory
  attr_accessor :cpu
  attr_accessor :overallStatus

  def initialize(dynamicType = nil, dynamicProperty = [], memory = nil, cpu = nil, overallStatus = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @memory = memory
    @cpu = cpu
    @overallStatus = overallStatus
  end
end

# {urn:vim2}ResourcePoolSummary
class ResourcePoolSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :config
  attr_accessor :runtime

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, config = nil, runtime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @config = config
    @runtime = runtime
  end
end

# {urn:vim2}HostVMotionCompatibility
class HostVMotionCompatibility
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :compatibility

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, compatibility = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @compatibility = compatibility
  end
end

# {urn:vim2}ArrayOfHostVMotionCompatibility
class ArrayOfHostVMotionCompatibility < ::Array
end

# {urn:vim2}ServiceContent
class ServiceContent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :rootFolder
  attr_accessor :propertyCollector
  attr_accessor :about
  attr_accessor :setting
  attr_accessor :userDirectory
  attr_accessor :sessionManager
  attr_accessor :authorizationManager
  attr_accessor :perfManager
  attr_accessor :scheduledTaskManager
  attr_accessor :alarmManager
  attr_accessor :eventManager
  attr_accessor :taskManager
  attr_accessor :customizationSpecManager
  attr_accessor :customFieldsManager
  attr_accessor :accountManager
  attr_accessor :diagnosticManager
  attr_accessor :licenseManager
  attr_accessor :searchIndex

  def initialize(dynamicType = nil, dynamicProperty = [], rootFolder = nil, propertyCollector = nil, about = nil, setting = nil, userDirectory = nil, sessionManager = nil, authorizationManager = nil, perfManager = nil, scheduledTaskManager = nil, alarmManager = nil, eventManager = nil, taskManager = nil, customizationSpecManager = nil, customFieldsManager = nil, accountManager = nil, diagnosticManager = nil, licenseManager = nil, searchIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @rootFolder = rootFolder
    @propertyCollector = propertyCollector
    @about = about
    @setting = setting
    @userDirectory = userDirectory
    @sessionManager = sessionManager
    @authorizationManager = authorizationManager
    @perfManager = perfManager
    @scheduledTaskManager = scheduledTaskManager
    @alarmManager = alarmManager
    @eventManager = eventManager
    @taskManager = taskManager
    @customizationSpecManager = customizationSpecManager
    @customFieldsManager = customFieldsManager
    @accountManager = accountManager
    @diagnosticManager = diagnosticManager
    @licenseManager = licenseManager
    @searchIndex = searchIndex
  end
end

# {urn:vim2}SessionManagerLocalTicket
class SessionManagerLocalTicket
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :userName
  attr_accessor :passwordFilePath

  def initialize(dynamicType = nil, dynamicProperty = [], userName = nil, passwordFilePath = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @userName = userName
    @passwordFilePath = passwordFilePath
  end
end

# {urn:vim2}UserSession
class UserSession
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :userName
  attr_accessor :fullName
  attr_accessor :loginTime
  attr_accessor :lastActiveTime
  attr_accessor :locale
  attr_accessor :messageLocale

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, userName = nil, fullName = nil, loginTime = nil, lastActiveTime = nil, locale = nil, messageLocale = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @userName = userName
    @fullName = fullName
    @loginTime = loginTime
    @lastActiveTime = lastActiveTime
    @locale = locale
    @messageLocale = messageLocale
  end
end

# {urn:vim2}ArrayOfUserSession
class ArrayOfUserSession < ::Array
end

# {urn:vim2}SharesInfo
class SharesInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :shares
  attr_accessor :level

  def initialize(dynamicType = nil, dynamicProperty = [], shares = nil, level = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @shares = shares
    @level = level
  end
end

# {urn:vim2}TaskDescription
class TaskDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :methodInfo
  attr_accessor :state
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], methodInfo = [], state = [], reason = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @methodInfo = methodInfo
    @state = state
    @reason = reason
  end
end

# {urn:vim2}TaskFilterSpecByEntity
class TaskFilterSpecByEntity
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :recursion

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, recursion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @recursion = recursion
  end
end

# {urn:vim2}TaskFilterSpecByTime
class TaskFilterSpecByTime
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :timeType
  attr_accessor :beginTime
  attr_accessor :endTime

  def initialize(dynamicType = nil, dynamicProperty = [], timeType = nil, beginTime = nil, endTime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @timeType = timeType
    @beginTime = beginTime
    @endTime = endTime
  end
end

# {urn:vim2}TaskFilterSpecByUsername
class TaskFilterSpecByUsername
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :systemUser
  attr_accessor :userList

  def initialize(dynamicType = nil, dynamicProperty = [], systemUser = nil, userList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @systemUser = systemUser
    @userList = userList
  end
end

# {urn:vim2}TaskFilterSpec
class TaskFilterSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :time
  attr_accessor :userName
  attr_accessor :state
  attr_accessor :alarm
  attr_accessor :scheduledTask

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, time = nil, userName = nil, state = [], alarm = nil, scheduledTask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @time = time
    @userName = userName
    @state = state
    @alarm = alarm
    @scheduledTask = scheduledTask
  end
end

# {urn:vim2}ArrayOfTaskInfoState
class ArrayOfTaskInfoState < ::Array
end

# {urn:vim2}TaskInfo
class TaskInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :task
  attr_accessor :name
  attr_accessor :descriptionId
  attr_accessor :entity
  attr_accessor :entityName
  attr_accessor :locked
  attr_accessor :state
  attr_accessor :cancelled
  attr_accessor :cancelable
  attr_accessor :error
  attr_accessor :result
  attr_accessor :progress
  attr_accessor :reason
  attr_accessor :queueTime
  attr_accessor :startTime
  attr_accessor :completeTime
  attr_accessor :eventChainId

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, task = nil, name = nil, descriptionId = nil, entity = nil, entityName = nil, locked = [], state = nil, cancelled = nil, cancelable = nil, error = nil, result = nil, progress = nil, reason = nil, queueTime = nil, startTime = nil, completeTime = nil, eventChainId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @task = task
    @name = name
    @descriptionId = descriptionId
    @entity = entity
    @entityName = entityName
    @locked = locked
    @state = state
    @cancelled = cancelled
    @cancelable = cancelable
    @error = error
    @result = result
    @progress = progress
    @reason = reason
    @queueTime = queueTime
    @startTime = startTime
    @completeTime = completeTime
    @eventChainId = eventChainId
  end
end

# {urn:vim2}ArrayOfTaskInfo
class ArrayOfTaskInfo < ::Array
end

# {urn:vim2}TaskReason
class TaskReason
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}TaskReasonSystem
class TaskReasonSystem
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}TaskReasonUser
class TaskReasonUser
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :userName

  def initialize(dynamicType = nil, dynamicProperty = [], userName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @userName = userName
  end
end

# {urn:vim2}TaskReasonAlarm
class TaskReasonAlarm
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :alarmName
  attr_accessor :alarm
  attr_accessor :entityName
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], alarmName = nil, alarm = nil, entityName = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @alarmName = alarmName
    @alarm = alarm
    @entityName = entityName
    @entity = entity
  end
end

# {urn:vim2}TaskReasonSchedule
class TaskReasonSchedule
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :scheduledTask

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, scheduledTask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @scheduledTask = scheduledTask
  end
end

# {urn:vim2}TypeDescription
class TypeDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary
  attr_accessor :key

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil, key = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
    @key = key
  end
end

# {urn:vim2}ArrayOfTypeDescription
class ArrayOfTypeDescription < ::Array
end

# {urn:vim2}UserSearchResult
class UserSearchResult
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :principal
  attr_accessor :fullName
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], principal = nil, fullName = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @principal = principal
    @fullName = fullName
    @group = group
  end
end

# {urn:vim2}ArrayOfUserSearchResult
class ArrayOfUserSearchResult < ::Array
end

# {urn:vim2}PosixUserSearchResult
class PosixUserSearchResult
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :principal
  attr_accessor :fullName
  attr_accessor :group
  attr_accessor :id
  attr_accessor :shellAccess

  def initialize(dynamicType = nil, dynamicProperty = [], principal = nil, fullName = nil, group = nil, id = nil, shellAccess = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @principal = principal
    @fullName = fullName
    @group = group
    @id = id
    @shellAccess = shellAccess
  end
end

# {urn:vim2}VirtualMachineMksTicket
class VirtualMachineMksTicket
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ticket
  attr_accessor :cfgFile
  attr_accessor :host
  attr_accessor :port

  def initialize(dynamicType = nil, dynamicProperty = [], ticket = nil, cfgFile = nil, host = nil, port = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ticket = ticket
    @cfgFile = cfgFile
    @host = host
    @port = port
  end
end

# {urn:vim2}Action
class Action
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MethodActionArgument
class MethodActionArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @value = value
  end
end

# {urn:vim2}ArrayOfMethodActionArgument
class ArrayOfMethodActionArgument < ::Array
end

# {urn:vim2}MethodAction
class MethodAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :argument

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, argument = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @argument = argument
  end
end

# {urn:vim2}SendEmailAction
class SendEmailAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :toList
  attr_accessor :ccList
  attr_accessor :subject
  attr_accessor :body

  def initialize(dynamicType = nil, dynamicProperty = [], toList = nil, ccList = nil, subject = nil, body = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @toList = toList
    @ccList = ccList
    @subject = subject
    @body = body
  end
end

# {urn:vim2}SendSNMPAction
class SendSNMPAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}RunScriptAction
class RunScriptAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :script

  def initialize(dynamicType = nil, dynamicProperty = [], script = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @script = script
  end
end

# {urn:vim2}AlarmAction
class AlarmAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ArrayOfAlarmAction
class ArrayOfAlarmAction < ::Array
end

# {urn:vim2}AlarmTriggeringAction
class AlarmTriggeringAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :action
  attr_accessor :green2yellow
  attr_accessor :yellow2red
  attr_accessor :red2yellow
  attr_accessor :yellow2green

  def initialize(dynamicType = nil, dynamicProperty = [], action = nil, green2yellow = nil, yellow2red = nil, red2yellow = nil, yellow2green = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @action = action
    @green2yellow = green2yellow
    @yellow2red = yellow2red
    @red2yellow = red2yellow
    @yellow2green = yellow2green
  end
end

# {urn:vim2}GroupAlarmAction
class GroupAlarmAction
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :action

  def initialize(dynamicType = nil, dynamicProperty = [], action = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @action = action
  end
end

# {urn:vim2}AlarmDescription
class AlarmDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :expr
  attr_accessor :stateOperator
  attr_accessor :metricOperator
  attr_accessor :hostSystemConnectionState
  attr_accessor :virtualMachinePowerState
  attr_accessor :entityStatus
  attr_accessor :action

  def initialize(dynamicType = nil, dynamicProperty = [], expr = [], stateOperator = [], metricOperator = [], hostSystemConnectionState = [], virtualMachinePowerState = [], entityStatus = [], action = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @expr = expr
    @stateOperator = stateOperator
    @metricOperator = metricOperator
    @hostSystemConnectionState = hostSystemConnectionState
    @virtualMachinePowerState = virtualMachinePowerState
    @entityStatus = entityStatus
    @action = action
  end
end

# {urn:vim2}AlarmExpression
class AlarmExpression
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ArrayOfAlarmExpression
class ArrayOfAlarmExpression < ::Array
end

# {urn:vim2}AndAlarmExpression
class AndAlarmExpression
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :expression

  def initialize(dynamicType = nil, dynamicProperty = [], expression = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @expression = expression
  end
end

# {urn:vim2}OrAlarmExpression
class OrAlarmExpression
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :expression

  def initialize(dynamicType = nil, dynamicProperty = [], expression = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @expression = expression
  end
end

# {urn:vim2}StateAlarmExpression
class StateAlarmExpression
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operator
  attr_accessor :type
  attr_accessor :statePath
  attr_accessor :yellow
  attr_accessor :red

  def initialize(dynamicType = nil, dynamicProperty = [], operator = nil, type = nil, statePath = nil, yellow = nil, red = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operator = operator
    @type = type
    @statePath = statePath
    @yellow = yellow
    @red = red
  end
end

# {urn:vim2}MetricAlarmExpression
class MetricAlarmExpression
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operator
  attr_accessor :type
  attr_accessor :metric
  attr_accessor :yellow
  attr_accessor :red

  def initialize(dynamicType = nil, dynamicProperty = [], operator = nil, type = nil, metric = nil, yellow = nil, red = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operator = operator
    @type = type
    @metric = metric
    @yellow = yellow
    @red = red
  end
end

# {urn:vim2}AlarmInfo
class AlarmInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :description
  attr_accessor :enabled
  attr_accessor :expression
  attr_accessor :action
  attr_accessor :setting
  attr_accessor :key
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :lastModifiedTime
  attr_accessor :lastModifiedUser
  attr_accessor :creationEventId

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, description = nil, enabled = nil, expression = nil, action = nil, setting = nil, key = nil, alarm = nil, entity = nil, lastModifiedTime = nil, lastModifiedUser = nil, creationEventId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @description = description
    @enabled = enabled
    @expression = expression
    @action = action
    @setting = setting
    @key = key
    @alarm = alarm
    @entity = entity
    @lastModifiedTime = lastModifiedTime
    @lastModifiedUser = lastModifiedUser
    @creationEventId = creationEventId
  end
end

# {urn:vim2}AlarmSetting
class AlarmSetting
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :toleranceRange
  attr_accessor :reportingFrequency

  def initialize(dynamicType = nil, dynamicProperty = [], toleranceRange = nil, reportingFrequency = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @toleranceRange = toleranceRange
    @reportingFrequency = reportingFrequency
  end
end

# {urn:vim2}AlarmSpec
class AlarmSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :description
  attr_accessor :enabled
  attr_accessor :expression
  attr_accessor :action
  attr_accessor :setting

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, description = nil, enabled = nil, expression = nil, action = nil, setting = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @description = description
    @enabled = enabled
    @expression = expression
    @action = action
    @setting = setting
  end
end

# {urn:vim2}AlarmState
class AlarmState
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :entity
  attr_accessor :alarm
  attr_accessor :overallStatus
  attr_accessor :time

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, entity = nil, alarm = nil, overallStatus = nil, time = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @entity = entity
    @alarm = alarm
    @overallStatus = overallStatus
    @time = time
  end
end

# {urn:vim2}ArrayOfAlarmState
class ArrayOfAlarmState < ::Array
end

# {urn:vim2}ClusterConfigInfo
class ClusterConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dasConfig
  attr_accessor :dasVmConfig
  attr_accessor :drsConfig
  attr_accessor :drsVmConfig
  attr_accessor :rule

  def initialize(dynamicType = nil, dynamicProperty = [], dasConfig = nil, dasVmConfig = [], drsConfig = nil, drsVmConfig = [], rule = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dasConfig = dasConfig
    @dasVmConfig = dasVmConfig
    @drsConfig = drsConfig
    @drsVmConfig = drsVmConfig
    @rule = rule
  end
end

# {urn:vim2}ClusterDrsConfigInfo
class ClusterDrsConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :enabled
  attr_accessor :defaultVmBehavior
  attr_accessor :vmotionRate
  attr_accessor :option

  def initialize(dynamicType = nil, dynamicProperty = [], enabled = nil, defaultVmBehavior = nil, vmotionRate = nil, option = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @enabled = enabled
    @defaultVmBehavior = defaultVmBehavior
    @vmotionRate = vmotionRate
    @option = option
  end
end

# {urn:vim2}ClusterDrsVmConfigInfo
class ClusterDrsVmConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :enabled
  attr_accessor :behavior

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, enabled = nil, behavior = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @enabled = enabled
    @behavior = behavior
  end
end

# {urn:vim2}ArrayOfClusterDrsVmConfigInfo
class ArrayOfClusterDrsVmConfigInfo < ::Array
end

# {urn:vim2}ClusterConfigSpec
class ClusterConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dasConfig
  attr_accessor :dasVmConfigSpec
  attr_accessor :drsConfig
  attr_accessor :drsVmConfigSpec
  attr_accessor :rulesSpec

  def initialize(dynamicType = nil, dynamicProperty = [], dasConfig = nil, dasVmConfigSpec = [], drsConfig = nil, drsVmConfigSpec = [], rulesSpec = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dasConfig = dasConfig
    @dasVmConfigSpec = dasVmConfigSpec
    @drsConfig = drsConfig
    @drsVmConfigSpec = drsVmConfigSpec
    @rulesSpec = rulesSpec
  end
end

# {urn:vim2}ClusterDasVmConfigSpec
class ClusterDasVmConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :removeKey
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, removeKey = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @removeKey = removeKey
    @info = info
  end
end

# {urn:vim2}ArrayOfClusterDasVmConfigSpec
class ArrayOfClusterDasVmConfigSpec < ::Array
end

# {urn:vim2}ClusterDrsVmConfigSpec
class ClusterDrsVmConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :removeKey
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, removeKey = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @removeKey = removeKey
    @info = info
  end
end

# {urn:vim2}ArrayOfClusterDrsVmConfigSpec
class ArrayOfClusterDrsVmConfigSpec < ::Array
end

# {urn:vim2}ClusterRuleSpec
class ClusterRuleSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :removeKey
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, removeKey = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @removeKey = removeKey
    @info = info
  end
end

# {urn:vim2}ArrayOfClusterRuleSpec
class ArrayOfClusterRuleSpec < ::Array
end

# {urn:vim2}ClusterDasConfigInfo
class ClusterDasConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :enabled
  attr_accessor :failoverLevel
  attr_accessor :admissionControlEnabled
  attr_accessor :option

  def initialize(dynamicType = nil, dynamicProperty = [], enabled = nil, failoverLevel = nil, admissionControlEnabled = nil, option = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @enabled = enabled
    @failoverLevel = failoverLevel
    @admissionControlEnabled = admissionControlEnabled
    @option = option
  end
end

# {urn:vim2}ClusterDasVmConfigInfo
class ClusterDasVmConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :restartPriority
  attr_accessor :powerOffOnIsolation

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, restartPriority = nil, powerOffOnIsolation = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @restartPriority = restartPriority
    @powerOffOnIsolation = powerOffOnIsolation
  end
end

# {urn:vim2}ArrayOfClusterDasVmConfigInfo
class ArrayOfClusterDasVmConfigInfo < ::Array
end

# {urn:vim2}ClusterDrsMigration
class ClusterDrsMigration
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :time
  attr_accessor :vm
  attr_accessor :cpuLoad
  attr_accessor :memoryLoad
  attr_accessor :source
  attr_accessor :sourceCpuLoad
  attr_accessor :sourceMemoryLoad
  attr_accessor :destination
  attr_accessor :destinationCpuLoad
  attr_accessor :destinationMemoryLoad

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, time = nil, vm = nil, cpuLoad = nil, memoryLoad = nil, source = nil, sourceCpuLoad = nil, sourceMemoryLoad = nil, destination = nil, destinationCpuLoad = nil, destinationMemoryLoad = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @time = time
    @vm = vm
    @cpuLoad = cpuLoad
    @memoryLoad = memoryLoad
    @source = source
    @sourceCpuLoad = sourceCpuLoad
    @sourceMemoryLoad = sourceMemoryLoad
    @destination = destination
    @destinationCpuLoad = destinationCpuLoad
    @destinationMemoryLoad = destinationMemoryLoad
  end
end

# {urn:vim2}ArrayOfClusterDrsMigration
class ArrayOfClusterDrsMigration < ::Array
end

# {urn:vim2}ClusterDrsRecommendation
class ClusterDrsRecommendation
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :rating
  attr_accessor :reason
  attr_accessor :reasonText
  attr_accessor :migrationList

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, rating = nil, reason = nil, reasonText = nil, migrationList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @rating = rating
    @reason = reason
    @reasonText = reasonText
    @migrationList = migrationList
  end
end

# {urn:vim2}ArrayOfClusterDrsRecommendation
class ArrayOfClusterDrsRecommendation < ::Array
end

# {urn:vim2}ClusterHostRecommendation
class ClusterHostRecommendation
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :rating

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, rating = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @rating = rating
  end
end

# {urn:vim2}ArrayOfClusterHostRecommendation
class ArrayOfClusterHostRecommendation < ::Array
end

# {urn:vim2}ClusterRuleInfo
class ClusterRuleInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :status
  attr_accessor :enabled
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, status = nil, enabled = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @status = status
    @enabled = enabled
    @name = name
  end
end

# {urn:vim2}ArrayOfClusterRuleInfo
class ArrayOfClusterRuleInfo < ::Array
end

# {urn:vim2}ClusterAffinityRuleSpec
class ClusterAffinityRuleSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :status
  attr_accessor :enabled
  attr_accessor :name
  attr_accessor :vm

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, status = nil, enabled = nil, name = nil, vm = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @status = status
    @enabled = enabled
    @name = name
    @vm = vm
  end
end

# {urn:vim2}ClusterAntiAffinityRuleSpec
class ClusterAntiAffinityRuleSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :status
  attr_accessor :enabled
  attr_accessor :name
  attr_accessor :vm

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, status = nil, enabled = nil, name = nil, vm = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @status = status
    @enabled = enabled
    @name = name
    @vm = vm
  end
end

# {urn:vim2}Event
class Event
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ArrayOfEvent
class ArrayOfEvent < ::Array
end

# {urn:vim2}GeneralEvent
class GeneralEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralHostInfoEvent
class GeneralHostInfoEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralHostWarningEvent
class GeneralHostWarningEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralHostErrorEvent
class GeneralHostErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralVmInfoEvent
class GeneralVmInfoEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralVmWarningEvent
class GeneralVmWarningEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralVmErrorEvent
class GeneralVmErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}GeneralUserEvent
class GeneralUserEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
    @entity = entity
  end
end

# {urn:vim2}SessionEvent
class SessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ServerStartedSessionEvent
class ServerStartedSessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}UserLoginSessionEvent
class UserLoginSessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :ipAddress
  attr_accessor :locale
  attr_accessor :sessionId

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, ipAddress = nil, locale = nil, sessionId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @ipAddress = ipAddress
    @locale = locale
    @sessionId = sessionId
  end
end

# {urn:vim2}UserLogoutSessionEvent
class UserLogoutSessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}BadUsernameSessionEvent
class BadUsernameSessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :ipAddress

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, ipAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @ipAddress = ipAddress
  end
end

# {urn:vim2}AlreadyAuthenticatedSessionEvent
class AlreadyAuthenticatedSessionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}NoAccessUserEvent
class NoAccessUserEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :ipAddress

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, ipAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @ipAddress = ipAddress
  end
end

# {urn:vim2}SessionTerminatedEvent
class SessionTerminatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :sessionId
  attr_accessor :terminatedUsername

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, sessionId = nil, terminatedUsername = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @sessionId = sessionId
    @terminatedUsername = terminatedUsername
  end
end

# {urn:vim2}GlobalMessageChangedEvent
class GlobalMessageChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}UpgradeEvent
class UpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}InfoUpgradeEvent
class InfoUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}WarningUpgradeEvent
class WarningUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}ErrorUpgradeEvent
class ErrorUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}UserUpgradeEvent
class UserUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @message = message
  end
end

# {urn:vim2}HostEvent
class HostEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostConnectedEvent
class HostConnectedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDisconnectedEvent
class HostDisconnectedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostConnectionLostEvent
class HostConnectionLostEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostReconnectionFailedEvent
class HostReconnectionFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedNoConnectionEvent
class HostCnxFailedNoConnectionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedBadUsernameEvent
class HostCnxFailedBadUsernameEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedBadVersionEvent
class HostCnxFailedBadVersionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedAlreadyManagedEvent
class HostCnxFailedAlreadyManagedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :serverName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, serverName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @serverName = serverName
  end
end

# {urn:vim2}HostCnxFailedNoLicenseEvent
class HostCnxFailedNoLicenseEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedNetworkErrorEvent
class HostCnxFailedNetworkErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostRemovedEvent
class HostRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedCcagentUpgradeEvent
class HostCnxFailedCcagentUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedBadCcagentEvent
class HostCnxFailedBadCcagentEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedEvent
class HostCnxFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedAccountFailedEvent
class HostCnxFailedAccountFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedNoAccessEvent
class HostCnxFailedNoAccessEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostShutdownEvent
class HostShutdownEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @reason = reason
  end
end

# {urn:vim2}HostCnxFailedNotFoundEvent
class HostCnxFailedNotFoundEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostCnxFailedTimeoutEvent
class HostCnxFailedTimeoutEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostUpgradeFailedEvent
class HostUpgradeFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}EnteringMaintenanceModeEvent
class EnteringMaintenanceModeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}EnteredMaintenanceModeEvent
class EnteredMaintenanceModeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ExitMaintenanceModeEvent
class ExitMaintenanceModeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}CanceledHostOperationEvent
class CanceledHostOperationEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}TimedOutHostOperationEvent
class TimedOutHostOperationEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasEnabledEvent
class HostDasEnabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasDisabledEvent
class HostDasDisabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasEnablingEvent
class HostDasEnablingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasDisablingEvent
class HostDasDisablingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasErrorEvent
class HostDasErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostDasOkEvent
class HostDasOkEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}VcAgentUpgradedEvent
class VcAgentUpgradedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}VcAgentUpgradeFailedEvent
class VcAgentUpgradeFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostAddedEvent
class HostAddedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}HostAddFailedEvent
class HostAddFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :hostname

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, hostname = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @hostname = hostname
  end
end

# {urn:vim2}AccountCreatedEvent
class AccountCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :spec
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, spec = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @spec = spec
    @group = group
  end
end

# {urn:vim2}AccountRemovedEvent
class AccountRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :account
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, account = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @account = account
    @group = group
  end
end

# {urn:vim2}UserPasswordChanged
class UserPasswordChanged
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :userLogin

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, userLogin = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @userLogin = userLogin
  end
end

# {urn:vim2}AccountUpdatedEvent
class AccountUpdatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :spec
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, spec = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @spec = spec
    @group = group
  end
end

# {urn:vim2}UserAssignedToGroup
class UserAssignedToGroup
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :userLogin
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, userLogin = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @userLogin = userLogin
    @group = group
  end
end

# {urn:vim2}UserUnassignedFromGroup
class UserUnassignedFromGroup
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :userLogin
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, userLogin = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @userLogin = userLogin
    @group = group
  end
end

# {urn:vim2}DatastorePrincipalConfigured
class DatastorePrincipalConfigured
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastorePrincipal

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastorePrincipal = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastorePrincipal = datastorePrincipal
  end
end

# {urn:vim2}VMFSDatastoreCreatedEvent
class VMFSDatastoreCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}NASDatastoreCreatedEvent
class NASDatastoreCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}LocalDatastoreCreatedEvent
class LocalDatastoreCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}DatastoreRemovedOnHostEvent
class DatastoreRemovedOnHostEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}DatastoreRenamedOnHostEvent
class DatastoreRenamedOnHostEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :oldName
  attr_accessor :newName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, oldName = nil, newName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @oldName = oldName
    @newName = newName
  end
end

# {urn:vim2}DatastoreDiscoveredEvent
class DatastoreDiscoveredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}DrsResourceConfigureFailedEvent
class DrsResourceConfigureFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @reason = reason
  end
end

# {urn:vim2}DrsResourceConfigureSyncedEvent
class DrsResourceConfigureSyncedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}VmEvent
class VmEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmPoweredOffEvent
class VmPoweredOffEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmPoweredOnEvent
class VmPoweredOnEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmSuspendedEvent
class VmSuspendedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmStartingEvent
class VmStartingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmStoppingEvent
class VmStoppingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmSuspendingEvent
class VmSuspendingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmResumingEvent
class VmResumingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmDisconnectedEvent
class VmDisconnectedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmDiscoveredEvent
class VmDiscoveredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmOrphanedEvent
class VmOrphanedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmBeingCreatedEvent
class VmBeingCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :configSpec

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, configSpec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @configSpec = configSpec
  end
end

# {urn:vim2}VmCreatedEvent
class VmCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmRegisteredEvent
class VmRegisteredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmAutoRenameEvent
class VmAutoRenameEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :oldName
  attr_accessor :newName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, oldName = nil, newName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @oldName = oldName
    @newName = newName
  end
end

# {urn:vim2}VmBeingHotMigratedEvent
class VmBeingHotMigratedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
  end
end

# {urn:vim2}VmResettingEvent
class VmResettingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmStaticMacConflictEvent
class VmStaticMacConflictEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :conflictedVm
  attr_accessor :mac

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, conflictedVm = nil, mac = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @conflictedVm = conflictedVm
    @mac = mac
  end
end

# {urn:vim2}VmMacConflictEvent
class VmMacConflictEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :conflictedVm
  attr_accessor :mac

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, conflictedVm = nil, mac = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @conflictedVm = conflictedVm
    @mac = mac
  end
end

# {urn:vim2}VmBeingDeployedEvent
class VmBeingDeployedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :srcTemplate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, srcTemplate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @srcTemplate = srcTemplate
  end
end

# {urn:vim2}VmDeployFailedEvent
class VmDeployFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destDatastore
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destDatastore = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destDatastore = destDatastore
    @reason = reason
  end
end

# {urn:vim2}VmDeployedEvent
class VmDeployedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :srcTemplate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, srcTemplate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @srcTemplate = srcTemplate
  end
end

# {urn:vim2}VmMacChangedEvent
class VmMacChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :adapter
  attr_accessor :oldMac
  attr_accessor :newMac

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, adapter = nil, oldMac = nil, newMac = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @adapter = adapter
    @oldMac = oldMac
    @newMac = newMac
  end
end

# {urn:vim2}VmMacAssignedEvent
class VmMacAssignedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :adapter
  attr_accessor :mac

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, adapter = nil, mac = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @adapter = adapter
    @mac = mac
  end
end

# {urn:vim2}VmUuidConflictEvent
class VmUuidConflictEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :conflictedVm
  attr_accessor :uuid

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, conflictedVm = nil, uuid = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @conflictedVm = conflictedVm
    @uuid = uuid
  end
end

# {urn:vim2}VmBeingMigratedEvent
class VmBeingMigratedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
  end
end

# {urn:vim2}VmFailedMigrateEvent
class VmFailedMigrateEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
    @reason = reason
  end
end

# {urn:vim2}VmMigratedEvent
class VmMigratedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :sourceHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, sourceHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @sourceHost = sourceHost
  end
end

# {urn:vim2}VmUnsupportedStartingEvent
class VmUnsupportedStartingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :guestId

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, guestId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @guestId = guestId
  end
end

# {urn:vim2}DrsVmMigratedEvent
class DrsVmMigratedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :sourceHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, sourceHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @sourceHost = sourceHost
  end
end

# {urn:vim2}VmRelocateSpecEvent
class VmRelocateSpecEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmBeingRelocatedEvent
class VmBeingRelocatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
  end
end

# {urn:vim2}VmRelocatedEvent
class VmRelocatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :sourceHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, sourceHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @sourceHost = sourceHost
  end
end

# {urn:vim2}VmRelocateFailedEvent
class VmRelocateFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
    @reason = reason
  end
end

# {urn:vim2}VmEmigratingEvent
class VmEmigratingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmCloneEvent
class VmCloneEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmBeingClonedEvent
class VmBeingClonedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destFolder
  attr_accessor :destName
  attr_accessor :destHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destFolder = nil, destName = nil, destHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destFolder = destFolder
    @destName = destName
    @destHost = destHost
  end
end

# {urn:vim2}VmCloneFailedEvent
class VmCloneFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destFolder
  attr_accessor :destName
  attr_accessor :destHost
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destFolder = nil, destName = nil, destHost = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destFolder = destFolder
    @destName = destName
    @destHost = destHost
    @reason = reason
  end
end

# {urn:vim2}VmClonedEvent
class VmClonedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :sourceVm

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, sourceVm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @sourceVm = sourceVm
  end
end

# {urn:vim2}VmResourceReallocatedEvent
class VmResourceReallocatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmRenamedEvent
class VmRenamedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :oldName
  attr_accessor :newName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, oldName = nil, newName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @oldName = oldName
    @newName = newName
  end
end

# {urn:vim2}VmDateRolledBackEvent
class VmDateRolledBackEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmNoNetworkAccessEvent
class VmNoNetworkAccessEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :destHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, destHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @destHost = destHost
  end
end

# {urn:vim2}VmDiskFailedEvent
class VmDiskFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :disk
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, disk = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @disk = disk
    @reason = reason
  end
end

# {urn:vim2}VmFailedToPowerOnEvent
class VmFailedToPowerOnEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToPowerOffEvent
class VmFailedToPowerOffEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToSuspendEvent
class VmFailedToSuspendEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToResetEvent
class VmFailedToResetEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToShutdownGuestEvent
class VmFailedToShutdownGuestEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToRebootGuestEvent
class VmFailedToRebootGuestEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmFailedToStandbyGuestEvent
class VmFailedToStandbyGuestEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmRemovedEvent
class VmRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmGuestShutdownEvent
class VmGuestShutdownEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmGuestRebootEvent
class VmGuestRebootEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmGuestStandbyEvent
class VmGuestStandbyEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmUpgradingEvent
class VmUpgradingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :version

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, version = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @version = version
  end
end

# {urn:vim2}VmUpgradeCompleteEvent
class VmUpgradeCompleteEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :version

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, version = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @version = version
  end
end

# {urn:vim2}VmUpgradeFailedEvent
class VmUpgradeFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmRestartedOnAlternateHostEvent
class VmRestartedOnAlternateHostEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :sourceHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, sourceHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @sourceHost = sourceHost
  end
end

# {urn:vim2}VmReconfiguredEvent
class VmReconfiguredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :configSpec

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, configSpec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @configSpec = configSpec
  end
end

# {urn:vim2}VmMessageEvent
class VmMessageEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :message

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, message = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @message = message
  end
end

# {urn:vim2}VmConfigMissingEvent
class VmConfigMissingEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmPowerOffOnIsolationEvent
class VmPowerOffOnIsolationEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :isolatedHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, isolatedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @isolatedHost = isolatedHost
  end
end

# {urn:vim2}VmFailoverFailed
class VmFailoverFailed
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}NotEnoughResourcesToStartVmEvent
class NotEnoughResourcesToStartVmEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmUuidAssignedEvent
class VmUuidAssignedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :uuid

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, uuid = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @uuid = uuid
  end
end

# {urn:vim2}VmUuidChangedEvent
class VmUuidChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :oldUuid
  attr_accessor :newUuid

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, oldUuid = nil, newUuid = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @oldUuid = oldUuid
    @newUuid = newUuid
  end
end

# {urn:vim2}VmFailedRelayoutOnVmfs2DatastoreEvent
class VmFailedRelayoutOnVmfs2DatastoreEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmFailedRelayoutEvent
class VmFailedRelayoutEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @reason = reason
  end
end

# {urn:vim2}VmRelayoutSuccessfulEvent
class VmRelayoutSuccessfulEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmRelayoutUpToDateEvent
class VmRelayoutUpToDateEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmConnectedEvent
class VmConnectedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmDasUpdateErrorEvent
class VmDasUpdateErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}NoMaintenanceModeDrsRecommendationForVM
class NoMaintenanceModeDrsRecommendationForVM
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}VmDasUpdateOkEvent
class VmDasUpdateOkEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
  end
end

# {urn:vim2}ScheduledTaskEvent
class ScheduledTaskEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskCreatedEvent
class ScheduledTaskCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskStartedEvent
class ScheduledTaskStartedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskRemovedEvent
class ScheduledTaskRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskReconfiguredEvent
class ScheduledTaskReconfiguredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskCompletedEvent
class ScheduledTaskCompletedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
  end
end

# {urn:vim2}ScheduledTaskFailedEvent
class ScheduledTaskFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
    @reason = reason
  end
end

# {urn:vim2}ScheduledTaskEmailCompletedEvent
class ScheduledTaskEmailCompletedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity
  attr_accessor :to

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil, to = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
    @to = to
  end
end

# {urn:vim2}ScheduledTaskEmailFailedEvent
class ScheduledTaskEmailFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :scheduledTask
  attr_accessor :entity
  attr_accessor :to
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, scheduledTask = nil, entity = nil, to = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @scheduledTask = scheduledTask
    @entity = entity
    @to = to
    @reason = reason
  end
end

# {urn:vim2}AlarmEvent
class AlarmEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
  end
end

# {urn:vim2}AlarmCreatedEvent
class AlarmCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
  end
end

# {urn:vim2}AlarmStatusChangedEvent
class AlarmStatusChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :source
  attr_accessor :entity
  attr_accessor :from
  attr_accessor :to

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, source = nil, entity = nil, from = nil, to = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @source = source
    @entity = entity
    @from = from
    @to = to
  end
end

# {urn:vim2}AlarmActionTriggeredEvent
class AlarmActionTriggeredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :source
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, source = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @source = source
    @entity = entity
  end
end

# {urn:vim2}AlarmEmailCompletedEvent
class AlarmEmailCompletedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :to

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil, to = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
    @to = to
  end
end

# {urn:vim2}AlarmEmailFailedEvent
class AlarmEmailFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :to
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil, to = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
    @to = to
    @reason = reason
  end
end

# {urn:vim2}AlarmSnmpCompletedEvent
class AlarmSnmpCompletedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
  end
end

# {urn:vim2}AlarmSnmpFailedEvent
class AlarmSnmpFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
    @reason = reason
  end
end

# {urn:vim2}AlarmScriptCompleteEvent
class AlarmScriptCompleteEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :script

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil, script = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
    @script = script
  end
end

# {urn:vim2}AlarmScriptFailedEvent
class AlarmScriptFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity
  attr_accessor :script
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil, script = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
    @script = script
    @reason = reason
  end
end

# {urn:vim2}AlarmRemovedEvent
class AlarmRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
  end
end

# {urn:vim2}AlarmReconfiguredEvent
class AlarmReconfiguredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :alarm
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, alarm = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @alarm = alarm
    @entity = entity
  end
end

# {urn:vim2}CustomFieldEvent
class CustomFieldEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}CustomFieldDefEvent
class CustomFieldDefEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :fieldKey
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, fieldKey = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @fieldKey = fieldKey
    @name = name
  end
end

# {urn:vim2}CustomFieldDefAddedEvent
class CustomFieldDefAddedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :fieldKey
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, fieldKey = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @fieldKey = fieldKey
    @name = name
  end
end

# {urn:vim2}CustomFieldDefRemovedEvent
class CustomFieldDefRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :fieldKey
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, fieldKey = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @fieldKey = fieldKey
    @name = name
  end
end

# {urn:vim2}CustomFieldDefRenamedEvent
class CustomFieldDefRenamedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :fieldKey
  attr_accessor :name
  attr_accessor :newName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, fieldKey = nil, name = nil, newName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @fieldKey = fieldKey
    @name = name
    @newName = newName
  end
end

# {urn:vim2}CustomFieldValueChangedEvent
class CustomFieldValueChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :entity
  attr_accessor :fieldKey
  attr_accessor :name
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, entity = nil, fieldKey = nil, name = nil, value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @entity = entity
    @fieldKey = fieldKey
    @name = name
    @value = value
  end
end

# {urn:vim2}AuthorizationEvent
class AuthorizationEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}PermissionEvent
class PermissionEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :entity
  attr_accessor :principal
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, entity = nil, principal = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @entity = entity
    @principal = principal
    @group = group
  end
end

# {urn:vim2}PermissionAddedEvent
class PermissionAddedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :entity
  attr_accessor :principal
  attr_accessor :group
  attr_accessor :role
  attr_accessor :propagate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, entity = nil, principal = nil, group = nil, role = nil, propagate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @entity = entity
    @principal = principal
    @group = group
    @role = role
    @propagate = propagate
  end
end

# {urn:vim2}PermissionUpdatedEvent
class PermissionUpdatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :entity
  attr_accessor :principal
  attr_accessor :group
  attr_accessor :role
  attr_accessor :propagate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, entity = nil, principal = nil, group = nil, role = nil, propagate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @entity = entity
    @principal = principal
    @group = group
    @role = role
    @propagate = propagate
  end
end

# {urn:vim2}PermissionRemovedEvent
class PermissionRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :entity
  attr_accessor :principal
  attr_accessor :group

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, entity = nil, principal = nil, group = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @entity = entity
    @principal = principal
    @group = group
  end
end

# {urn:vim2}RoleEvent
class RoleEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :role

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, role = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @role = role
  end
end

# {urn:vim2}RoleAddedEvent
class RoleAddedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :role
  attr_accessor :privilegeList

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, role = nil, privilegeList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @role = role
    @privilegeList = privilegeList
  end
end

# {urn:vim2}RoleUpdatedEvent
class RoleUpdatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :role
  attr_accessor :privilegeList

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, role = nil, privilegeList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @role = role
    @privilegeList = privilegeList
  end
end

# {urn:vim2}RoleRemovedEvent
class RoleRemovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :role

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, role = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @role = role
  end
end

# {urn:vim2}DatastoreEvent
class DatastoreEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}DatastoreDestroyedEvent
class DatastoreDestroyedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}DatastoreRenamedEvent
class DatastoreRenamedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore
  attr_accessor :oldName
  attr_accessor :newName

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil, oldName = nil, newName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
    @oldName = oldName
    @newName = newName
  end
end

# {urn:vim2}DatastoreDuplicatedEvent
class DatastoreDuplicatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @datastore = datastore
  end
end

# {urn:vim2}TaskEvent
class TaskEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @info = info
  end
end

# {urn:vim2}LicenseEvent
class LicenseEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ServerLicenseExpiredEvent
class ServerLicenseExpiredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :product

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, product = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @product = product
  end
end

# {urn:vim2}HostLicenseExpiredEvent
class HostLicenseExpiredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}VMotionLicenseExpiredEvent
class VMotionLicenseExpiredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}NoLicenseEvent
class NoLicenseEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :feature

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, feature = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @feature = feature
  end
end

# {urn:vim2}LicenseServerUnavailableEvent
class LicenseServerUnavailableEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :licenseServer

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, licenseServer = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @licenseServer = licenseServer
  end
end

# {urn:vim2}LicenseServerAvailableEvent
class LicenseServerAvailableEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :licenseServer

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, licenseServer = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @licenseServer = licenseServer
  end
end

# {urn:vim2}LicenseExpiredEvent
class LicenseExpiredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :feature

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, feature = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @feature = feature
  end
end

# {urn:vim2}MigrationEvent
class MigrationEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
  end
end

# {urn:vim2}MigrationWarningEvent
class MigrationWarningEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
  end
end

# {urn:vim2}MigrationErrorEvent
class MigrationErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
  end
end

# {urn:vim2}MigrationHostWarningEvent
class MigrationHostWarningEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault
  attr_accessor :dstHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil, dstHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
    @dstHost = dstHost
  end
end

# {urn:vim2}MigrationHostErrorEvent
class MigrationHostErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault
  attr_accessor :dstHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil, dstHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
    @dstHost = dstHost
  end
end

# {urn:vim2}MigrationResourceWarningEvent
class MigrationResourceWarningEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault
  attr_accessor :dstPool
  attr_accessor :dstHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil, dstPool = nil, dstHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
    @dstPool = dstPool
    @dstHost = dstHost
  end
end

# {urn:vim2}MigrationResourceErrorEvent
class MigrationResourceErrorEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :fault
  attr_accessor :dstPool
  attr_accessor :dstHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, fault = nil, dstPool = nil, dstHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @fault = fault
    @dstPool = dstPool
    @dstHost = dstHost
  end
end

# {urn:vim2}ClusterEvent
class ClusterEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasEnabledEvent
class DasEnabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasDisabledEvent
class DasDisabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasAdmissionControlDisabledEvent
class DasAdmissionControlDisabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasAdmissionControlEnabledEvent
class DasAdmissionControlEnabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasHostFailedEvent
class DasHostFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :failedHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, failedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @failedHost = failedHost
  end
end

# {urn:vim2}DasHostIsolatedEvent
class DasHostIsolatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :isolatedHost

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, isolatedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @isolatedHost = isolatedHost
  end
end

# {urn:vim2}DasAgentUnavailableEvent
class DasAgentUnavailableEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DasAgentFoundEvent
class DasAgentFoundEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}InsufficientFailoverResourcesEvent
class InsufficientFailoverResourcesEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}FailoverLevelRestored
class FailoverLevelRestored
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ClusterOvercommittedEvent
class ClusterOvercommittedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ClusterStatusChangedEvent
class ClusterStatusChangedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :oldStatus
  attr_accessor :newStatus

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, oldStatus = nil, newStatus = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @oldStatus = oldStatus
    @newStatus = newStatus
  end
end

# {urn:vim2}ClusterCreatedEvent
class ClusterCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :parent

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, parent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @parent = parent
  end
end

# {urn:vim2}ClusterDestroyedEvent
class ClusterDestroyedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}DrsEnabledEvent
class DrsEnabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :behavior

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, behavior = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @behavior = behavior
  end
end

# {urn:vim2}DrsDisabledEvent
class DrsDisabledEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ClusterReconfiguredEvent
class ClusterReconfiguredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
  end
end

# {urn:vim2}ResourcePoolEvent
class ResourcePoolEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
  end
end

# {urn:vim2}ResourcePoolCreatedEvent
class ResourcePoolCreatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool
  attr_accessor :parent

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil, parent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
    @parent = parent
  end
end

# {urn:vim2}ResourcePoolDestroyedEvent
class ResourcePoolDestroyedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
  end
end

# {urn:vim2}ResourcePoolMovedEvent
class ResourcePoolMovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool
  attr_accessor :oldParent
  attr_accessor :newParent

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil, oldParent = nil, newParent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
    @oldParent = oldParent
    @newParent = newParent
  end
end

# {urn:vim2}ResourcePoolReconfiguredEvent
class ResourcePoolReconfiguredEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
  end
end

# {urn:vim2}ResourceViolatedEvent
class ResourceViolatedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :resourcePool

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, resourcePool = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @resourcePool = resourcePool
  end
end

# {urn:vim2}VmResourcePoolMovedEvent
class VmResourcePoolMovedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :template
  attr_accessor :oldParent
  attr_accessor :newParent

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, template = nil, oldParent = nil, newParent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @template = template
    @oldParent = oldParent
    @newParent = newParent
  end
end

# {urn:vim2}TemplateUpgradeEvent
class TemplateUpgradeEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :legacyTemplate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, legacyTemplate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @legacyTemplate = legacyTemplate
  end
end

# {urn:vim2}TemplateBeingUpgradedEvent
class TemplateBeingUpgradedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :legacyTemplate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, legacyTemplate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @legacyTemplate = legacyTemplate
  end
end

# {urn:vim2}TemplateUpgradeFailedEvent
class TemplateUpgradeFailedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :legacyTemplate
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, legacyTemplate = nil, reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @legacyTemplate = legacyTemplate
    @reason = reason
  end
end

# {urn:vim2}TemplateUpgradedEvent
class TemplateUpgradedEvent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :chainId
  attr_accessor :createdTime
  attr_accessor :userName
  attr_accessor :datacenter
  attr_accessor :computeResource
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :fullFormattedMessage
  attr_accessor :legacyTemplate

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, chainId = nil, createdTime = nil, userName = nil, datacenter = nil, computeResource = nil, host = nil, vm = nil, fullFormattedMessage = nil, legacyTemplate = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @chainId = chainId
    @createdTime = createdTime
    @userName = userName
    @datacenter = datacenter
    @computeResource = computeResource
    @host = host
    @vm = vm
    @fullFormattedMessage = fullFormattedMessage
    @legacyTemplate = legacyTemplate
  end
end

# {urn:vim2}EventArgument
class EventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}RoleEventArgument
class RoleEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :roleId
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], roleId = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @roleId = roleId
    @name = name
  end
end

# {urn:vim2}EntityEventArgument
class EntityEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}ManagedEntityEventArgument
class ManagedEntityEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @entity = entity
  end
end

# {urn:vim2}FolderEventArgument
class FolderEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :folder

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, folder = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @folder = folder
  end
end

# {urn:vim2}DatacenterEventArgument
class DatacenterEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :datacenter

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, datacenter = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @datacenter = datacenter
  end
end

# {urn:vim2}ComputeResourceEventArgument
class ComputeResourceEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :computeResource

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, computeResource = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @computeResource = computeResource
  end
end

# {urn:vim2}ResourcePoolEventArgument
class ResourcePoolEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :resourcePool

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, resourcePool = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @resourcePool = resourcePool
  end
end

# {urn:vim2}HostEventArgument
class HostEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :host

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, host = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @host = host
  end
end

# {urn:vim2}VmEventArgument
class VmEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :vm

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, vm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @vm = vm
  end
end

# {urn:vim2}DatastoreEventArgument
class DatastoreEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @datastore = datastore
  end
end

# {urn:vim2}AlarmEventArgument
class AlarmEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :alarm

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, alarm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @alarm = alarm
  end
end

# {urn:vim2}ScheduledTaskEventArgument
class ScheduledTaskEventArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :scheduledTask

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, scheduledTask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @scheduledTask = scheduledTask
  end
end

# {urn:vim2}EventDescriptionEventDetail
class EventDescriptionEventDetail
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :category
  attr_accessor :formatOnDatacenter
  attr_accessor :formatOnComputeResource
  attr_accessor :formatOnHost
  attr_accessor :formatOnVm
  attr_accessor :fullFormat

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, category = nil, formatOnDatacenter = nil, formatOnComputeResource = nil, formatOnHost = nil, formatOnVm = nil, fullFormat = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @category = category
    @formatOnDatacenter = formatOnDatacenter
    @formatOnComputeResource = formatOnComputeResource
    @formatOnHost = formatOnHost
    @formatOnVm = formatOnVm
    @fullFormat = fullFormat
  end
end

# {urn:vim2}ArrayOfEventDescriptionEventDetail
class ArrayOfEventDescriptionEventDetail < ::Array
end

# {urn:vim2}EventDescription
class EventDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :category
  attr_accessor :eventInfo

  def initialize(dynamicType = nil, dynamicProperty = [], category = [], eventInfo = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @category = category
    @eventInfo = eventInfo
  end
end

# {urn:vim2}EventFilterSpecByEntity
class EventFilterSpecByEntity
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :recursion

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, recursion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @recursion = recursion
  end
end

# {urn:vim2}EventFilterSpecByTime
class EventFilterSpecByTime
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :beginTime
  attr_accessor :endTime

  def initialize(dynamicType = nil, dynamicProperty = [], beginTime = nil, endTime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @beginTime = beginTime
    @endTime = endTime
  end
end

# {urn:vim2}EventFilterSpecByUsername
class EventFilterSpecByUsername
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :systemUser
  attr_accessor :userList

  def initialize(dynamicType = nil, dynamicProperty = [], systemUser = nil, userList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @systemUser = systemUser
    @userList = userList
  end
end

# {urn:vim2}EventFilterSpec
class EventFilterSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :time
  attr_accessor :userName
  attr_accessor :eventChainId
  attr_accessor :alarm
  attr_accessor :scheduledTask
  attr_accessor :disableFullMessage
  attr_accessor :category
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, time = nil, userName = nil, eventChainId = nil, alarm = nil, scheduledTask = nil, disableFullMessage = nil, category = [], type = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @time = time
    @userName = userName
    @eventChainId = eventChainId
    @alarm = alarm
    @scheduledTask = scheduledTask
    @disableFullMessage = disableFullMessage
    @category = category
    @type = type
  end
end

# {urn:vim2}AffinityConfigured
class AffinityConfigured
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :configuredAffinity

  def initialize(dynamicType = nil, dynamicProperty = [], configuredAffinity = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @configuredAffinity = configuredAffinity
  end
end

# {urn:vim2}AgentInstallFailed
class AgentInstallFailed
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}AlreadyBeingManaged
class AlreadyBeingManaged
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ipAddress

  def initialize(dynamicType = nil, dynamicProperty = [], ipAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ipAddress = ipAddress
  end
end

# {urn:vim2}AlreadyConnected
class AlreadyConnected
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}AlreadyExists
class AlreadyExists
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}AlreadyUpgraded
class AlreadyUpgraded
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ApplicationQuiesceFault
class ApplicationQuiesceFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}AuthMinimumAdminPermission
class AuthMinimumAdminPermission
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CannotAccessFile
class CannotAccessFile
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}CannotAccessLocalSource
class CannotAccessLocalSource
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CannotAccessNetwork
class CannotAccessNetwork
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}CannotAccessVmComponent
class CannotAccessVmComponent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CannotAccessVmConfig
class CannotAccessVmConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @reason = reason
  end
end

# {urn:vim2}CannotAccessVmDevice
class CannotAccessVmDevice
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}CannotAccessVmDisk
class CannotAccessVmDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
    @fault = fault
  end
end

# {urn:vim2}CannotDecryptPasswords
class CannotDecryptPasswords
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CannotDeleteFile
class CannotDeleteFile
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}CannotModifyConfigCpuRequirements
class CannotModifyConfigCpuRequirements
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ConcurrentAccess
class ConcurrentAccess
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CpuCompatibilityUnknown
class CpuCompatibilityUnknown
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :level
  attr_accessor :registerName

  def initialize(dynamicType = nil, dynamicProperty = [], level = nil, registerName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @level = level
    @registerName = registerName
  end
end

# {urn:vim2}CpuIncompatible
class CpuIncompatible
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :level
  attr_accessor :registerName

  def initialize(dynamicType = nil, dynamicProperty = [], level = nil, registerName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @level = level
    @registerName = registerName
  end
end

# {urn:vim2}CustomizationFault
class CustomizationFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}DasConfigFault
class DasConfigFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}DatabaseError
class DatabaseError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}DatacenterMismatchArgument
class DatacenterMismatchArgument
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :entity
  attr_accessor :inputDatacenter

  def initialize(dynamicType = nil, dynamicProperty = [], entity = nil, inputDatacenter = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @entity = entity
    @inputDatacenter = inputDatacenter
  end
end

# {urn:vim2}ArrayOfDatacenterMismatchArgument
class ArrayOfDatacenterMismatchArgument < ::Array
end

# {urn:vim2}DatacenterMismatch
class DatacenterMismatch
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :invalidArgument
  attr_accessor :expectedDatacenter

  def initialize(dynamicType = nil, dynamicProperty = [], invalidArgument = [], expectedDatacenter = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @invalidArgument = invalidArgument
    @expectedDatacenter = expectedDatacenter
  end
end

# {urn:vim2}DatastoreNotWritableOnHost
class DatastoreNotWritableOnHost
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :name
  attr_accessor :host

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, name = nil, host = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @name = name
    @host = host
  end
end

# {urn:vim2}DestinationSwitchFull
class DestinationSwitchFull
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}DeviceNotFound
class DeviceNotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
  end
end

# {urn:vim2}DeviceNotSupported
class DeviceNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}DisallowedDiskModeChange
class DisallowedDiskModeChange
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
  end
end

# {urn:vim2}DisallowedMigrationDeviceAttached
class DisallowedMigrationDeviceAttached
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fault = fault
  end
end

# {urn:vim2}DiskNotSupported
class DiskNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :disk

  def initialize(dynamicType = nil, dynamicProperty = [], disk = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @disk = disk
  end
end

# {urn:vim2}DuplicateName
class DuplicateName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :object

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, object = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @object = object
  end
end

# {urn:vim2}FileAlreadyExists
class FileAlreadyExists
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}FileFault
class FileFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}FileLocked
class FileLocked
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}FileNotFound
class FileNotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}FileNotWritable
class FileNotWritable
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}FilesystemQuiesceFault
class FilesystemQuiesceFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}GenericVmConfigFault
class GenericVmConfigFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :reason

  def initialize(dynamicType = nil, dynamicProperty = [], reason = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @reason = reason
  end
end

# {urn:vim2}HostConfigFault
class HostConfigFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostConnectFault
class HostConnectFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}IDEDiskNotSupported
class IDEDiskNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :disk

  def initialize(dynamicType = nil, dynamicProperty = [], disk = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @disk = disk
  end
end

# {urn:vim2}InaccessibleDatastore
class InaccessibleDatastore
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @name = name
  end
end

# {urn:vim2}IncompatibleSetting
class IncompatibleSetting
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :invalidProperty
  attr_accessor :conflictingProperty

  def initialize(dynamicType = nil, dynamicProperty = [], invalidProperty = nil, conflictingProperty = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @invalidProperty = invalidProperty
    @conflictingProperty = conflictingProperty
  end
end

# {urn:vim2}IncorrectFileType
class IncorrectFileType
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}InsufficientCpuResourcesFault
class InsufficientCpuResourcesFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :unreserved
  attr_accessor :requested

  def initialize(dynamicType = nil, dynamicProperty = [], unreserved = nil, requested = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @unreserved = unreserved
    @requested = requested
  end
end

# {urn:vim2}InsufficientFailoverResourcesFault
class InsufficientFailoverResourcesFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InsufficientHostCapacityFault
class InsufficientHostCapacityFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InsufficientMemoryResourcesFault
class InsufficientMemoryResourcesFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :unreserved
  attr_accessor :requested

  def initialize(dynamicType = nil, dynamicProperty = [], unreserved = nil, requested = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @unreserved = unreserved
    @requested = requested
  end
end

# {urn:vim2}InsufficientResourcesFault
class InsufficientResourcesFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidController
class InvalidController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex
  attr_accessor :controllerKey

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil, controllerKey = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
    @controllerKey = controllerKey
  end
end

# {urn:vim2}InvalidDatastore
class InvalidDatastore
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @name = name
  end
end

# {urn:vim2}InvalidDatastorePath
class InvalidDatastorePath
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :name
  attr_accessor :datastorePath

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, name = nil, datastorePath = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @name = name
    @datastorePath = datastorePath
  end
end

# {urn:vim2}InvalidDeviceBacking
class InvalidDeviceBacking
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
  end
end

# {urn:vim2}InvalidDeviceOperation
class InvalidDeviceOperation
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex
  attr_accessor :badOp
  attr_accessor :badFileOp

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil, badOp = nil, badFileOp = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
    @badOp = badOp
    @badFileOp = badFileOp
  end
end

# {urn:vim2}InvalidDeviceSpec
class InvalidDeviceSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
  end
end

# {urn:vim2}InvalidDiskFormat
class InvalidDiskFormat
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidFolder
class InvalidFolder
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :target

  def initialize(dynamicType = nil, dynamicProperty = [], target = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @target = target
  end
end

# {urn:vim2}InvalidFormat
class InvalidFormat
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidLicense
class InvalidLicense
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :licenseContent

  def initialize(dynamicType = nil, dynamicProperty = [], licenseContent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @licenseContent = licenseContent
  end
end

# {urn:vim2}InvalidLocale
class InvalidLocale
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidLogin
class InvalidLogin
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidName
class InvalidName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :entity

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, entity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @entity = entity
  end
end

# {urn:vim2}InvalidPowerState
class InvalidPowerState
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :requestedState
  attr_accessor :existingState

  def initialize(dynamicType = nil, dynamicProperty = [], requestedState = nil, existingState = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @requestedState = requestedState
    @existingState = existingState
  end
end

# {urn:vim2}InvalidResourcePoolStructureFault
class InvalidResourcePoolStructureFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidSnapshotFormat
class InvalidSnapshotFormat
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidState
class InvalidState
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}InvalidVmConfig
class InvalidVmConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
  end
end

# {urn:vim2}IpHostnameGeneratorError
class IpHostnameGeneratorError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}LegacyNetworkInterfaceInUse
class LegacyNetworkInterfaceInUse
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}LicenseServerUnavailable
class LicenseServerUnavailable
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :licenseServer

  def initialize(dynamicType = nil, dynamicProperty = [], licenseServer = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @licenseServer = licenseServer
  end
end

# {urn:vim2}LinuxVolumeNotClean
class LinuxVolumeNotClean
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}LogBundlingFailed
class LogBundlingFailed
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MemorySnapshotOnIndependentDisk
class MemorySnapshotOnIndependentDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MigrationFault
class MigrationFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MismatchedNetworkPolicies
class MismatchedNetworkPolicies
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}MismatchedVMotionNetworkNames
class MismatchedVMotionNetworkNames
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :sourceNetwork
  attr_accessor :destNetwork

  def initialize(dynamicType = nil, dynamicProperty = [], sourceNetwork = nil, destNetwork = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @sourceNetwork = sourceNetwork
    @destNetwork = destNetwork
  end
end

# {urn:vim2}MissingController
class MissingController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :deviceIndex

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, deviceIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @deviceIndex = deviceIndex
  end
end

# {urn:vim2}MissingLinuxCustResources
class MissingLinuxCustResources
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MissingWindowsCustResources
class MissingWindowsCustResources
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}MountError
class MountError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vm
  attr_accessor :diskIndex

  def initialize(dynamicType = nil, dynamicProperty = [], vm = nil, diskIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vm = vm
    @diskIndex = diskIndex
  end
end

# {urn:vim2}MultipleSnapshotsNotSupported
class MultipleSnapshotsNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NetworkCopyFault
class NetworkCopyFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
  end
end

# {urn:vim2}NoActiveHostInCluster
class NoActiveHostInCluster
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :computeResource

  def initialize(dynamicType = nil, dynamicProperty = [], computeResource = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @computeResource = computeResource
  end
end

# {urn:vim2}NoDiskFound
class NoDiskFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NoDiskSpace
class NoDiskSpace
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :file
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], file = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @file = file
    @datastore = datastore
  end
end

# {urn:vim2}NoDisksToCustomize
class NoDisksToCustomize
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NoGateway
class NoGateway
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NoGuestHeartbeat
class NoGuestHeartbeat
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NoHost
class NoHost
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}NoPermission
class NoPermission
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :object
  attr_accessor :privilegeId

  def initialize(dynamicType = nil, dynamicProperty = [], object = nil, privilegeId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @object = object
    @privilegeId = privilegeId
  end
end

# {urn:vim2}NoPermissionOnHost
class NoPermissionOnHost
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NoVirtualNic
class NoVirtualNic
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NotEnoughCpus
class NotEnoughCpus
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numCpuDest
  attr_accessor :numCpuVm

  def initialize(dynamicType = nil, dynamicProperty = [], numCpuDest = nil, numCpuVm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numCpuDest = numCpuDest
    @numCpuVm = numCpuVm
  end
end

# {urn:vim2}NotEnoughLogicalCpus
class NotEnoughLogicalCpus
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numCpuDest
  attr_accessor :numCpuVm

  def initialize(dynamicType = nil, dynamicProperty = [], numCpuDest = nil, numCpuVm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numCpuDest = numCpuDest
    @numCpuVm = numCpuVm
  end
end

# {urn:vim2}NotFound
class NotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}NotSupportedHost
class NotSupportedHost
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :productName
  attr_accessor :productVersion

  def initialize(dynamicType = nil, dynamicProperty = [], productName = nil, productVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @productName = productName
    @productVersion = productVersion
  end
end

# {urn:vim2}NumVirtualCpusNotSupported
class NumVirtualCpusNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :maxSupportedVcpusDest
  attr_accessor :numCpuVm

  def initialize(dynamicType = nil, dynamicProperty = [], maxSupportedVcpusDest = nil, numCpuVm = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @maxSupportedVcpusDest = maxSupportedVcpusDest
    @numCpuVm = numCpuVm
  end
end

# {urn:vim2}OutOfBounds
class OutOfBounds
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :argumentName

  def initialize(dynamicType = nil, dynamicProperty = [], argumentName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @argumentName = argumentName
  end
end

# {urn:vim2}PhysCompatRDMNotSupported
class PhysCompatRDMNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}PlatformConfigFault
class PlatformConfigFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :text

  def initialize(dynamicType = nil, dynamicProperty = [], text = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @text = text
  end
end

# {urn:vim2}RDMNotPreserved
class RDMNotPreserved
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}RDMNotSupported
class RDMNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}RDMPointsToInaccessibleDisk
class RDMPointsToInaccessibleDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil, fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
    @fault = fault
  end
end

# {urn:vim2}RawDiskNotSupported
class RawDiskNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}ReadOnlyDisksWithLegacyDestination
class ReadOnlyDisksWithLegacyDestination
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :roDiskCount
  attr_accessor :timeoutDanger

  def initialize(dynamicType = nil, dynamicProperty = [], roDiskCount = nil, timeoutDanger = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @roDiskCount = roDiskCount
    @timeoutDanger = timeoutDanger
  end
end

# {urn:vim2}RemoteDeviceNotSupported
class RemoteDeviceNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}RemoveFailed
class RemoveFailed
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ResourceInUse
class ResourceInUse
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @name = name
  end
end

# {urn:vim2}RuleViolation
class RuleViolation
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}SharedBusControllerNotSupported
class SharedBusControllerNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
  end
end

# {urn:vim2}SnapshotCopyNotSupported
class SnapshotCopyNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}SnapshotFault
class SnapshotFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}SnapshotIncompatibleDeviceInVm
class SnapshotIncompatibleDeviceInVm
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fault

  def initialize(dynamicType = nil, dynamicProperty = [], fault = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fault = fault
  end
end

# {urn:vim2}SnapshotRevertIssue
class SnapshotRevertIssue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :snapshotName
  attr_accessor :event
  attr_accessor :errors

  def initialize(dynamicType = nil, dynamicProperty = [], snapshotName = nil, event = [], errors = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @snapshotName = snapshotName
    @event = event
    @errors = errors
  end
end

# {urn:vim2}SuspendedRelocateNotSupported
class SuspendedRelocateNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}TaskInProgress
class TaskInProgress
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :task

  def initialize(dynamicType = nil, dynamicProperty = [], task = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @task = task
  end
end

# {urn:vim2}Timedout
class Timedout
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}TooManyDevices
class TooManyDevices
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
  end
end

# {urn:vim2}TooManyHosts
class TooManyHosts
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}TooManySnapshotLevels
class TooManySnapshotLevels
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ToolsUnavailable
class ToolsUnavailable
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}UncommittedUndoableDisk
class UncommittedUndoableDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}UncustomizableGuest
class UncustomizableGuest
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :uncustomizableGuestOS

  def initialize(dynamicType = nil, dynamicProperty = [], uncustomizableGuestOS = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @uncustomizableGuestOS = uncustomizableGuestOS
  end
end

# {urn:vim2}UnexpectedCustomizationFault
class UnexpectedCustomizationFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}UnsupportedDatastore
class UnsupportedDatastore
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
  end
end

# {urn:vim2}UnsupportedGuest
class UnsupportedGuest
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :property
  attr_accessor :unsupportedGuestOS

  def initialize(dynamicType = nil, dynamicProperty = [], property = nil, unsupportedGuestOS = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @property = property
    @unsupportedGuestOS = unsupportedGuestOS
  end
end

# {urn:vim2}UnsupportedVmxLocation
class UnsupportedVmxLocation
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}UserNotFound
class UserNotFound
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :principal
  attr_accessor :unresolved

  def initialize(dynamicType = nil, dynamicProperty = [], principal = nil, unresolved = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @principal = principal
    @unresolved = unresolved
  end
end

# {urn:vim2}VMOnVirtualIntranet
class VMOnVirtualIntranet
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :backing
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, backing = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @backing = backing
    @connected = connected
  end
end

# {urn:vim2}VMotionInterfaceIssue
class VMotionInterfaceIssue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
  end
end

# {urn:vim2}VMotionLinkCapacityLow
class VMotionLinkCapacityLow
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil, network = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
    @network = network
  end
end

# {urn:vim2}VMotionLinkDown
class VMotionLinkDown
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil, network = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
    @network = network
  end
end

# {urn:vim2}VMotionNotConfigured
class VMotionNotConfigured
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
  end
end

# {urn:vim2}VMotionNotLicensed
class VMotionNotLicensed
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
  end
end

# {urn:vim2}VMotionNotSupported
class VMotionNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :atSourceHost
  attr_accessor :failedHost

  def initialize(dynamicType = nil, dynamicProperty = [], atSourceHost = nil, failedHost = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @atSourceHost = atSourceHost
    @failedHost = failedHost
  end
end

# {urn:vim2}VMotionProtocolIncompatible
class VMotionProtocolIncompatible
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VimFault
class VimFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VirtualHardwareCompatibilityIssue
class VirtualHardwareCompatibilityIssue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VirtualHardwareVersionNotSupported
class VirtualHardwareVersionNotSupported
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmConfigFault
class VmConfigFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmLimitLicense
class VmLimitLicense
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :limit

  def initialize(dynamicType = nil, dynamicProperty = [], limit = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @limit = limit
  end
end

# {urn:vim2}VmToolsUpgradeFault
class VmToolsUpgradeFault
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VolumeEditorError
class VolumeEditorError
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}WillModifyConfigCpuRequirements
class WillModifyConfigCpuRequirements
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}AutoStartDefaults
class AutoStartDefaults
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :enabled
  attr_accessor :startDelay
  attr_accessor :stopDelay
  attr_accessor :waitForHeartbeat
  attr_accessor :stopAction

  def initialize(dynamicType = nil, dynamicProperty = [], enabled = nil, startDelay = nil, stopDelay = nil, waitForHeartbeat = nil, stopAction = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @enabled = enabled
    @startDelay = startDelay
    @stopDelay = stopDelay
    @waitForHeartbeat = waitForHeartbeat
    @stopAction = stopAction
  end
end

# {urn:vim2}AutoStartPowerInfo
class AutoStartPowerInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :startOrder
  attr_accessor :startDelay
  attr_accessor :waitForHeartbeat
  attr_accessor :startAction
  attr_accessor :stopDelay
  attr_accessor :stopAction

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, startOrder = nil, startDelay = nil, waitForHeartbeat = nil, startAction = nil, stopDelay = nil, stopAction = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @startOrder = startOrder
    @startDelay = startDelay
    @waitForHeartbeat = waitForHeartbeat
    @startAction = startAction
    @stopDelay = stopDelay
    @stopAction = stopAction
  end
end

# {urn:vim2}ArrayOfAutoStartPowerInfo
class ArrayOfAutoStartPowerInfo < ::Array
end

# {urn:vim2}HostAutoStartManagerConfig
class HostAutoStartManagerConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :defaults
  attr_accessor :powerInfo

  def initialize(dynamicType = nil, dynamicProperty = [], defaults = nil, powerInfo = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @defaults = defaults
    @powerInfo = powerInfo
  end
end

# {urn:vim2}HostCapability
class HostCapability
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :recursiveResourcePoolsSupported
  attr_accessor :rebootSupported
  attr_accessor :shutdownSupported
  attr_accessor :vmotionSupported
  attr_accessor :maxSupportedVMs
  attr_accessor :maxRunningVMs
  attr_accessor :maxSupportedVcpus
  attr_accessor :datastorePrincipalSupported
  attr_accessor :sanSupported
  attr_accessor :nfsSupported
  attr_accessor :iscsiSupported
  attr_accessor :vlanTaggingSupported
  attr_accessor :nicTeamingSupported
  attr_accessor :highGuestMemSupported
  attr_accessor :maintenanceModeSupported
  attr_accessor :suspendedRelocateSupported

  def initialize(dynamicType = nil, dynamicProperty = [], recursiveResourcePoolsSupported = nil, rebootSupported = nil, shutdownSupported = nil, vmotionSupported = nil, maxSupportedVMs = nil, maxRunningVMs = nil, maxSupportedVcpus = nil, datastorePrincipalSupported = nil, sanSupported = nil, nfsSupported = nil, iscsiSupported = nil, vlanTaggingSupported = nil, nicTeamingSupported = nil, highGuestMemSupported = nil, maintenanceModeSupported = nil, suspendedRelocateSupported = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @recursiveResourcePoolsSupported = recursiveResourcePoolsSupported
    @rebootSupported = rebootSupported
    @shutdownSupported = shutdownSupported
    @vmotionSupported = vmotionSupported
    @maxSupportedVMs = maxSupportedVMs
    @maxRunningVMs = maxRunningVMs
    @maxSupportedVcpus = maxSupportedVcpus
    @datastorePrincipalSupported = datastorePrincipalSupported
    @sanSupported = sanSupported
    @nfsSupported = nfsSupported
    @iscsiSupported = iscsiSupported
    @vlanTaggingSupported = vlanTaggingSupported
    @nicTeamingSupported = nicTeamingSupported
    @highGuestMemSupported = highGuestMemSupported
    @maintenanceModeSupported = maintenanceModeSupported
    @suspendedRelocateSupported = suspendedRelocateSupported
  end
end

# {urn:vim2}HostConfigChange
class HostConfigChange
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostConfigInfo
class HostConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :product
  attr_accessor :hyperThread
  attr_accessor :consoleReservation
  attr_accessor :storageDevice
  attr_accessor :fileSystemVolume
  attr_accessor :network
  attr_accessor :vmotion
  attr_accessor :capabilities
  attr_accessor :offloadCapabilities
  attr_accessor :service
  attr_accessor :firewall
  attr_accessor :autoStart
  attr_accessor :activeDiagnosticPartition
  attr_accessor :option
  attr_accessor :optionDef
  attr_accessor :datastorePrincipal
  attr_accessor :systemResources

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, product = nil, hyperThread = nil, consoleReservation = nil, storageDevice = nil, fileSystemVolume = nil, network = nil, vmotion = nil, capabilities = nil, offloadCapabilities = nil, service = nil, firewall = nil, autoStart = nil, activeDiagnosticPartition = nil, option = [], optionDef = [], datastorePrincipal = nil, systemResources = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @product = product
    @hyperThread = hyperThread
    @consoleReservation = consoleReservation
    @storageDevice = storageDevice
    @fileSystemVolume = fileSystemVolume
    @network = network
    @vmotion = vmotion
    @capabilities = capabilities
    @offloadCapabilities = offloadCapabilities
    @service = service
    @firewall = firewall
    @autoStart = autoStart
    @activeDiagnosticPartition = activeDiagnosticPartition
    @option = option
    @optionDef = optionDef
    @datastorePrincipal = datastorePrincipal
    @systemResources = systemResources
  end
end

# {urn:vim2}HostConfigManager
class HostConfigManager
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :cpuScheduler
  attr_accessor :datastoreSystem
  attr_accessor :memoryManager
  attr_accessor :storageSystem
  attr_accessor :networkSystem
  attr_accessor :vmotionSystem
  attr_accessor :serviceSystem
  attr_accessor :firewallSystem
  attr_accessor :advancedOption
  attr_accessor :diagnosticSystem
  attr_accessor :autoStartManager
  attr_accessor :snmpSystem

  def initialize(dynamicType = nil, dynamicProperty = [], cpuScheduler = nil, datastoreSystem = nil, memoryManager = nil, storageSystem = nil, networkSystem = nil, vmotionSystem = nil, serviceSystem = nil, firewallSystem = nil, advancedOption = nil, diagnosticSystem = nil, autoStartManager = nil, snmpSystem = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @cpuScheduler = cpuScheduler
    @datastoreSystem = datastoreSystem
    @memoryManager = memoryManager
    @storageSystem = storageSystem
    @networkSystem = networkSystem
    @vmotionSystem = vmotionSystem
    @serviceSystem = serviceSystem
    @firewallSystem = firewallSystem
    @advancedOption = advancedOption
    @diagnosticSystem = diagnosticSystem
    @autoStartManager = autoStartManager
    @snmpSystem = snmpSystem
  end
end

# {urn:vim2}HostConnectInfoNetworkInfo
class HostConnectInfoNetworkInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :summary

  def initialize(dynamicType = nil, dynamicProperty = [], summary = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @summary = summary
  end
end

# {urn:vim2}ArrayOfHostConnectInfoNetworkInfo
class ArrayOfHostConnectInfoNetworkInfo < ::Array
end

# {urn:vim2}HostNewNetworkConnectInfo
class HostNewNetworkConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :summary

  def initialize(dynamicType = nil, dynamicProperty = [], summary = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @summary = summary
  end
end

# {urn:vim2}HostDatastoreConnectInfo
class HostDatastoreConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :summary

  def initialize(dynamicType = nil, dynamicProperty = [], summary = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @summary = summary
  end
end

# {urn:vim2}ArrayOfHostDatastoreConnectInfo
class ArrayOfHostDatastoreConnectInfo < ::Array
end

# {urn:vim2}HostDatastoreExistsConnectInfo
class HostDatastoreExistsConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :summary
  attr_accessor :newDatastoreName

  def initialize(dynamicType = nil, dynamicProperty = [], summary = nil, newDatastoreName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @summary = summary
    @newDatastoreName = newDatastoreName
  end
end

# {urn:vim2}HostDatastoreNameConflictConnectInfo
class HostDatastoreNameConflictConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :summary
  attr_accessor :newDatastoreName

  def initialize(dynamicType = nil, dynamicProperty = [], summary = nil, newDatastoreName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @summary = summary
    @newDatastoreName = newDatastoreName
  end
end

# {urn:vim2}HostConnectInfo
class HostConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :serverIp
  attr_accessor :host
  attr_accessor :vm
  attr_accessor :vimAccountNameRequired
  attr_accessor :clusterSupported
  attr_accessor :network
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], serverIp = nil, host = nil, vm = [], vimAccountNameRequired = nil, clusterSupported = nil, network = [], datastore = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @serverIp = serverIp
    @host = host
    @vm = vm
    @vimAccountNameRequired = vimAccountNameRequired
    @clusterSupported = clusterSupported
    @network = network
    @datastore = datastore
  end
end

# {urn:vim2}HostConnectSpec
class HostConnectSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :hostName
  attr_accessor :port
  attr_accessor :userName
  attr_accessor :password
  attr_accessor :vmFolder
  attr_accessor :force
  attr_accessor :vimAccountName
  attr_accessor :vimAccountPassword

  def initialize(dynamicType = nil, dynamicProperty = [], hostName = nil, port = nil, userName = nil, password = nil, vmFolder = nil, force = nil, vimAccountName = nil, vimAccountPassword = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @hostName = hostName
    @port = port
    @userName = userName
    @password = password
    @vmFolder = vmFolder
    @force = force
    @vimAccountName = vimAccountName
    @vimAccountPassword = vimAccountPassword
  end
end

# {urn:vim2}HostCpuIdInfo
class HostCpuIdInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :level
  attr_accessor :vendor
  attr_accessor :eax
  attr_accessor :ebx
  attr_accessor :ecx
  attr_accessor :edx

  def initialize(dynamicType = nil, dynamicProperty = [], level = nil, vendor = nil, eax = nil, ebx = nil, ecx = nil, edx = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @level = level
    @vendor = vendor
    @eax = eax
    @ebx = ebx
    @ecx = ecx
    @edx = edx
  end
end

# {urn:vim2}ArrayOfHostCpuIdInfo
class ArrayOfHostCpuIdInfo < ::Array
end

# {urn:vim2}HostHyperThreadScheduleInfo
class HostHyperThreadScheduleInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :available
  attr_accessor :active
  attr_accessor :config

  def initialize(dynamicType = nil, dynamicProperty = [], available = nil, active = nil, config = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @available = available
    @active = active
    @config = config
  end
end

# {urn:vim2}FileQueryFlags
class FileQueryFlags
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileType
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], fileType = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileType = fileType
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}FileInfo
class FileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}ArrayOfFileInfo
class ArrayOfFileInfo < ::Array
end

# {urn:vim2}FileQuery
class FileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}ArrayOfFileQuery
class ArrayOfFileQuery < ::Array
end

# {urn:vim2}VmConfigFileQueryFilter
class VmConfigFileQueryFilter
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :matchConfigVersion

  def initialize(dynamicType = nil, dynamicProperty = [], matchConfigVersion = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @matchConfigVersion = matchConfigVersion
  end
end

# {urn:vim2}VmConfigFileQueryFlags
class VmConfigFileQueryFlags
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :configVersion

  def initialize(dynamicType = nil, dynamicProperty = [], configVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @configVersion = configVersion
  end
end

# {urn:vim2}VmConfigFileQuery
class VmConfigFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :filter
  attr_accessor :details

  def initialize(dynamicType = nil, dynamicProperty = [], filter = nil, details = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @filter = filter
    @details = details
  end
end

# {urn:vim2}TemplateConfigFileQuery
class TemplateConfigFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :filter
  attr_accessor :details

  def initialize(dynamicType = nil, dynamicProperty = [], filter = nil, details = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @filter = filter
    @details = details
  end
end

# {urn:vim2}VmDiskFileQueryFilter
class VmDiskFileQueryFilter
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskType
  attr_accessor :matchHardwareVersion

  def initialize(dynamicType = nil, dynamicProperty = [], diskType = [], matchHardwareVersion = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskType = diskType
    @matchHardwareVersion = matchHardwareVersion
  end
end

# {urn:vim2}VmDiskFileQueryFlags
class VmDiskFileQueryFlags
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskType
  attr_accessor :capacityKb
  attr_accessor :hardwareVersion

  def initialize(dynamicType = nil, dynamicProperty = [], diskType = nil, capacityKb = nil, hardwareVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskType = diskType
    @capacityKb = capacityKb
    @hardwareVersion = hardwareVersion
  end
end

# {urn:vim2}VmDiskFileQuery
class VmDiskFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :filter
  attr_accessor :details

  def initialize(dynamicType = nil, dynamicProperty = [], filter = nil, details = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @filter = filter
    @details = details
  end
end

# {urn:vim2}FolderFileQuery
class FolderFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmSnapshotFileQuery
class VmSnapshotFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}IsoImageFileQuery
class IsoImageFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}FloppyImageFileQuery
class FloppyImageFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmNvramFileQuery
class VmNvramFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmLogFileQuery
class VmLogFileQuery
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VmConfigFileInfo
class VmConfigFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification
  attr_accessor :configVersion

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil, configVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
    @configVersion = configVersion
  end
end

# {urn:vim2}TemplateConfigFileInfo
class TemplateConfigFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification
  attr_accessor :configVersion

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil, configVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
    @configVersion = configVersion
  end
end

# {urn:vim2}VmDiskFileInfo
class VmDiskFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification
  attr_accessor :diskType
  attr_accessor :capacityKb
  attr_accessor :hardwareVersion

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil, diskType = nil, capacityKb = nil, hardwareVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
    @diskType = diskType
    @capacityKb = capacityKb
    @hardwareVersion = hardwareVersion
  end
end

# {urn:vim2}FolderFileInfo
class FolderFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}VmSnapshotFileInfo
class VmSnapshotFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}IsoImageFileInfo
class IsoImageFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}FloppyImageFileInfo
class FloppyImageFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}VmNvramFileInfo
class VmNvramFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}VmLogFileInfo
class VmLogFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :fileSize
  attr_accessor :modification

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, fileSize = nil, modification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @fileSize = fileSize
    @modification = modification
  end
end

# {urn:vim2}HostDatastoreBrowserSearchSpec
class HostDatastoreBrowserSearchSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :query
  attr_accessor :details
  attr_accessor :searchCaseInsensitive
  attr_accessor :matchPattern
  attr_accessor :sortFoldersFirst

  def initialize(dynamicType = nil, dynamicProperty = [], query = [], details = nil, searchCaseInsensitive = nil, matchPattern = [], sortFoldersFirst = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @query = query
    @details = details
    @searchCaseInsensitive = searchCaseInsensitive
    @matchPattern = matchPattern
    @sortFoldersFirst = sortFoldersFirst
  end
end

# {urn:vim2}HostDatastoreBrowserSearchResults
class HostDatastoreBrowserSearchResults
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :folderPath
  attr_accessor :file

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, folderPath = nil, file = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @folderPath = folderPath
    @file = file
  end
end

# {urn:vim2}ArrayOfHostDatastoreBrowserSearchResults
class ArrayOfHostDatastoreBrowserSearchResults < ::Array
end

# {urn:vim2}VmfsDatastoreInfo
class VmfsDatastoreInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :url
  attr_accessor :freeSpace
  attr_accessor :maxFileSize
  attr_accessor :vmfs

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, url = nil, freeSpace = nil, maxFileSize = nil, vmfs = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @url = url
    @freeSpace = freeSpace
    @maxFileSize = maxFileSize
    @vmfs = vmfs
  end
end

# {urn:vim2}NasDatastoreInfo
class NasDatastoreInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :url
  attr_accessor :freeSpace
  attr_accessor :maxFileSize
  attr_accessor :nas

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, url = nil, freeSpace = nil, maxFileSize = nil, nas = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @url = url
    @freeSpace = freeSpace
    @maxFileSize = maxFileSize
    @nas = nas
  end
end

# {urn:vim2}LocalDatastoreInfo
class LocalDatastoreInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :url
  attr_accessor :freeSpace
  attr_accessor :maxFileSize
  attr_accessor :path

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, url = nil, freeSpace = nil, maxFileSize = nil, path = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @url = url
    @freeSpace = freeSpace
    @maxFileSize = maxFileSize
    @path = path
  end
end

# {urn:vim2}VmfsDatastoreSpec
class VmfsDatastoreSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskUuid

  def initialize(dynamicType = nil, dynamicProperty = [], diskUuid = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskUuid = diskUuid
  end
end

# {urn:vim2}VmfsDatastoreCreateSpec
class VmfsDatastoreCreateSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskUuid
  attr_accessor :partition
  attr_accessor :vmfs
  attr_accessor :extent

  def initialize(dynamicType = nil, dynamicProperty = [], diskUuid = nil, partition = nil, vmfs = nil, extent = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskUuid = diskUuid
    @partition = partition
    @vmfs = vmfs
    @extent = extent
  end
end

# {urn:vim2}VmfsDatastoreExtendSpec
class VmfsDatastoreExtendSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskUuid
  attr_accessor :partition
  attr_accessor :extent

  def initialize(dynamicType = nil, dynamicProperty = [], diskUuid = nil, partition = nil, extent = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskUuid = diskUuid
    @partition = partition
    @extent = extent
  end
end

# {urn:vim2}VmfsDatastoreBaseOption
class VmfsDatastoreBaseOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :layout

  def initialize(dynamicType = nil, dynamicProperty = [], layout = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @layout = layout
  end
end

# {urn:vim2}VmfsDatastoreSingleExtentOption
class VmfsDatastoreSingleExtentOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :layout
  attr_accessor :vmfsExtent

  def initialize(dynamicType = nil, dynamicProperty = [], layout = nil, vmfsExtent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @layout = layout
    @vmfsExtent = vmfsExtent
  end
end

# {urn:vim2}VmfsDatastoreAllExtentOption
class VmfsDatastoreAllExtentOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :layout
  attr_accessor :vmfsExtent

  def initialize(dynamicType = nil, dynamicProperty = [], layout = nil, vmfsExtent = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @layout = layout
    @vmfsExtent = vmfsExtent
  end
end

# {urn:vim2}VmfsDatastoreMultipleExtentOption
class VmfsDatastoreMultipleExtentOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :layout
  attr_accessor :vmfsExtent

  def initialize(dynamicType = nil, dynamicProperty = [], layout = nil, vmfsExtent = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @layout = layout
    @vmfsExtent = vmfsExtent
  end
end

# {urn:vim2}VmfsDatastoreOption
class VmfsDatastoreOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :info
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], info = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @info = info
    @spec = spec
  end
end

# {urn:vim2}ArrayOfVmfsDatastoreOption
class ArrayOfVmfsDatastoreOption < ::Array
end

# {urn:vim2}HostDevice
class HostDevice
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :deviceType

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, deviceType = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @deviceType = deviceType
  end
end

# {urn:vim2}HostDiagnosticPartitionCreateOption
class HostDiagnosticPartitionCreateOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :storageType
  attr_accessor :diagnosticType
  attr_accessor :disk

  def initialize(dynamicType = nil, dynamicProperty = [], storageType = nil, diagnosticType = nil, disk = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @storageType = storageType
    @diagnosticType = diagnosticType
    @disk = disk
  end
end

# {urn:vim2}ArrayOfHostDiagnosticPartitionCreateOption
class ArrayOfHostDiagnosticPartitionCreateOption < ::Array
end

# {urn:vim2}HostDiagnosticPartitionCreateSpec
class HostDiagnosticPartitionCreateSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :storageType
  attr_accessor :diagnosticType
  attr_accessor :id
  attr_accessor :partition
  attr_accessor :active

  def initialize(dynamicType = nil, dynamicProperty = [], storageType = nil, diagnosticType = nil, id = nil, partition = nil, active = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @storageType = storageType
    @diagnosticType = diagnosticType
    @id = id
    @partition = partition
    @active = active
  end
end

# {urn:vim2}HostDiagnosticPartitionCreateDescription
class HostDiagnosticPartitionCreateDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :layout
  attr_accessor :diskUuid
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], layout = nil, diskUuid = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @layout = layout
    @diskUuid = diskUuid
    @spec = spec
  end
end

# {urn:vim2}HostDiagnosticPartition
class HostDiagnosticPartition
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :storageType
  attr_accessor :diagnosticType
  attr_accessor :slots
  attr_accessor :id

  def initialize(dynamicType = nil, dynamicProperty = [], storageType = nil, diagnosticType = nil, slots = nil, id = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @storageType = storageType
    @diagnosticType = diagnosticType
    @slots = slots
    @id = id
  end
end

# {urn:vim2}ArrayOfHostDiagnosticPartition
class ArrayOfHostDiagnosticPartition < ::Array
end

# {urn:vim2}HostDiskBlockInfoExtent
class HostDiskBlockInfoExtent
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :logicalStart
  attr_accessor :physicalStart
  attr_accessor :length

  def initialize(dynamicType = nil, dynamicProperty = [], logicalStart = nil, physicalStart = nil, length = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @logicalStart = logicalStart
    @physicalStart = physicalStart
    @length = length
  end
end

# {urn:vim2}ArrayOfHostDiskBlockInfoExtent
class ArrayOfHostDiskBlockInfoExtent < ::Array
end

# {urn:vim2}HostDiskBlockInfoMapping
class HostDiskBlockInfoMapping
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :element
  attr_accessor :extent

  def initialize(dynamicType = nil, dynamicProperty = [], element = nil, extent = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @element = element
    @extent = extent
  end
end

# {urn:vim2}ArrayOfHostDiskBlockInfoMapping
class ArrayOfHostDiskBlockInfoMapping < ::Array
end

# {urn:vim2}HostDiskBlockInfoScsiMapping
class HostDiskBlockInfoScsiMapping
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :element
  attr_accessor :extent

  def initialize(dynamicType = nil, dynamicProperty = [], element = nil, extent = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @element = element
    @extent = extent
  end
end

# {urn:vim2}HostDiskBlockInfo
class HostDiskBlockInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :size
  attr_accessor :granularity
  attr_accessor :minBlockSize
  attr_accessor :map

  def initialize(dynamicType = nil, dynamicProperty = [], size = nil, granularity = nil, minBlockSize = nil, map = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @size = size
    @granularity = granularity
    @minBlockSize = minBlockSize
    @map = map
  end
end

# {urn:vim2}HostDiskDimensionsChs
class HostDiskDimensionsChs
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :cylinder
  attr_accessor :head
  attr_accessor :sector

  def initialize(dynamicType = nil, dynamicProperty = [], cylinder = nil, head = nil, sector = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @cylinder = cylinder
    @head = head
    @sector = sector
  end
end

# {urn:vim2}HostDiskDimensionsLba
class HostDiskDimensionsLba
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :blockSize
  attr_accessor :block

  def initialize(dynamicType = nil, dynamicProperty = [], blockSize = nil, block = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @blockSize = blockSize
    @block = block
  end
end

# {urn:vim2}HostDiskDimensions
class HostDiskDimensions
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostDiskManagerLeaseInfo
class HostDiskManagerLeaseInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :lease
  attr_accessor :ddbOption
  attr_accessor :blockInfo

  def initialize(dynamicType = nil, dynamicProperty = [], lease = nil, ddbOption = [], blockInfo = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @lease = lease
    @ddbOption = ddbOption
    @blockInfo = blockInfo
  end
end

# {urn:vim2}HostDiskPartitionAttributes
class HostDiskPartitionAttributes
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :partition
  attr_accessor :startSector
  attr_accessor :endSector
  attr_accessor :type
  attr_accessor :logical
  attr_accessor :attributes

  def initialize(dynamicType = nil, dynamicProperty = [], partition = nil, startSector = nil, endSector = nil, type = nil, logical = nil, attributes = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @partition = partition
    @startSector = startSector
    @endSector = endSector
    @type = type
    @logical = logical
    @attributes = attributes
  end
end

# {urn:vim2}ArrayOfHostDiskPartitionAttributes
class ArrayOfHostDiskPartitionAttributes < ::Array
end

# {urn:vim2}HostDiskPartitionBlockRange
class HostDiskPartitionBlockRange
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :partition
  attr_accessor :type
  attr_accessor :start

  def end
    @v_end
  end

  def end=(value)
    @v_end = value
  end

  def initialize(dynamicType = nil, dynamicProperty = [], partition = nil, type = nil, start = nil, v_end = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @partition = partition
    @type = type
    @start = start
    @v_end = v_end
  end
end

# {urn:vim2}ArrayOfHostDiskPartitionBlockRange
class ArrayOfHostDiskPartitionBlockRange < ::Array
end

# {urn:vim2}HostDiskPartitionSpec
class HostDiskPartitionSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :chs
  attr_accessor :totalSectors
  attr_accessor :partition

  def initialize(dynamicType = nil, dynamicProperty = [], chs = nil, totalSectors = nil, partition = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @chs = chs
    @totalSectors = totalSectors
    @partition = partition
  end
end

# {urn:vim2}HostDiskPartitionLayout
class HostDiskPartitionLayout
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :total
  attr_accessor :partition

  def initialize(dynamicType = nil, dynamicProperty = [], total = nil, partition = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @total = total
    @partition = partition
  end
end

# {urn:vim2}HostDiskPartitionInfo
class HostDiskPartitionInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :spec
  attr_accessor :layout

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, spec = nil, layout = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @spec = spec
    @layout = layout
  end
end

# {urn:vim2}ArrayOfHostDiskPartitionInfo
class ArrayOfHostDiskPartitionInfo < ::Array
end

# {urn:vim2}HostDnsConfig
class HostDnsConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dhcp
  attr_accessor :virtualNicDevice
  attr_accessor :hostName
  attr_accessor :domainName
  attr_accessor :address
  attr_accessor :searchDomain

  def initialize(dynamicType = nil, dynamicProperty = [], dhcp = nil, virtualNicDevice = nil, hostName = nil, domainName = nil, address = [], searchDomain = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dhcp = dhcp
    @virtualNicDevice = virtualNicDevice
    @hostName = hostName
    @domainName = domainName
    @address = address
    @searchDomain = searchDomain
  end
end

# {urn:vim2}ModeInfo
class ModeInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :browse
  attr_accessor :read
  attr_accessor :modify
  attr_accessor :use
  attr_accessor :admin
  attr_accessor :full

  def initialize(dynamicType = nil, dynamicProperty = [], browse = nil, read = nil, modify = nil, use = nil, admin = nil, full = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @browse = browse
    @read = read
    @modify = modify
    @use = use
    @admin = admin
    @full = full
  end
end

# {urn:vim2}HostFileAccess
class HostFileAccess
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :who
  attr_accessor :what

  def initialize(dynamicType = nil, dynamicProperty = [], who = nil, what = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @who = who
    @what = what
  end
end

# {urn:vim2}HostFileSystemVolumeInfo
class HostFileSystemVolumeInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :volumeTypeList
  attr_accessor :mountInfo

  def initialize(dynamicType = nil, dynamicProperty = [], volumeTypeList = [], mountInfo = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @volumeTypeList = volumeTypeList
    @mountInfo = mountInfo
  end
end

# {urn:vim2}HostFileSystemMountInfo
class HostFileSystemMountInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :mountInfo
  attr_accessor :volume

  def initialize(dynamicType = nil, dynamicProperty = [], mountInfo = nil, volume = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @mountInfo = mountInfo
    @volume = volume
  end
end

# {urn:vim2}ArrayOfHostFileSystemMountInfo
class ArrayOfHostFileSystemMountInfo < ::Array
end

# {urn:vim2}HostFileSystemVolume
class HostFileSystemVolume
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :name
  attr_accessor :capacity

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, name = nil, capacity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @name = name
    @capacity = capacity
  end
end

# {urn:vim2}HostNasVolumeSpec
class HostNasVolumeSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :remoteHost
  attr_accessor :remotePath
  attr_accessor :localPath
  attr_accessor :accessMode

  def initialize(dynamicType = nil, dynamicProperty = [], remoteHost = nil, remotePath = nil, localPath = nil, accessMode = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @remoteHost = remoteHost
    @remotePath = remotePath
    @localPath = localPath
    @accessMode = accessMode
  end
end

# {urn:vim2}HostNasVolume
class HostNasVolume
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :name
  attr_accessor :capacity
  attr_accessor :remoteHost
  attr_accessor :remotePath

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, name = nil, capacity = nil, remoteHost = nil, remotePath = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @name = name
    @capacity = capacity
    @remoteHost = remoteHost
    @remotePath = remotePath
  end
end

# {urn:vim2}HostLocalFileSystemVolumeSpec
class HostLocalFileSystemVolumeSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :localPath

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, localPath = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @localPath = localPath
  end
end

# {urn:vim2}HostLocalFileSystemVolume
class HostLocalFileSystemVolume
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :name
  attr_accessor :capacity
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, name = nil, capacity = nil, device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @name = name
    @capacity = capacity
    @device = device
  end
end

# {urn:vim2}HostFirewallDefaultPolicy
class HostFirewallDefaultPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :incomingBlocked
  attr_accessor :outgoingBlocked

  def initialize(dynamicType = nil, dynamicProperty = [], incomingBlocked = nil, outgoingBlocked = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @incomingBlocked = incomingBlocked
    @outgoingBlocked = outgoingBlocked
  end
end

# {urn:vim2}HostFirewallInfo
class HostFirewallInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :defaultPolicy
  attr_accessor :ruleset

  def initialize(dynamicType = nil, dynamicProperty = [], defaultPolicy = nil, ruleset = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @defaultPolicy = defaultPolicy
    @ruleset = ruleset
  end
end

# {urn:vim2}HostHardwareInfo
class HostHardwareInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :systemInfo
  attr_accessor :cpuInfo
  attr_accessor :cpuPkg
  attr_accessor :memorySize
  attr_accessor :numaInfo
  attr_accessor :pciDevice
  attr_accessor :cpuFeature

  def initialize(dynamicType = nil, dynamicProperty = [], systemInfo = nil, cpuInfo = nil, cpuPkg = [], memorySize = nil, numaInfo = nil, pciDevice = [], cpuFeature = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @systemInfo = systemInfo
    @cpuInfo = cpuInfo
    @cpuPkg = cpuPkg
    @memorySize = memorySize
    @numaInfo = numaInfo
    @pciDevice = pciDevice
    @cpuFeature = cpuFeature
  end
end

# {urn:vim2}HostSystemInfo
class HostSystemInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vendor
  attr_accessor :model
  attr_accessor :uuid

  def initialize(dynamicType = nil, dynamicProperty = [], vendor = nil, model = nil, uuid = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vendor = vendor
    @model = model
    @uuid = uuid
  end
end

# {urn:vim2}HostCpuInfo
class HostCpuInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numCpuPackages
  attr_accessor :numCpuCores
  attr_accessor :numCpuThreads
  attr_accessor :hz

  def initialize(dynamicType = nil, dynamicProperty = [], numCpuPackages = nil, numCpuCores = nil, numCpuThreads = nil, hz = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numCpuPackages = numCpuPackages
    @numCpuCores = numCpuCores
    @numCpuThreads = numCpuThreads
    @hz = hz
  end
end

# {urn:vim2}HostCpuPackage
class HostCpuPackage
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :index
  attr_accessor :vendor
  attr_accessor :hz
  attr_accessor :busHz
  attr_accessor :description
  attr_accessor :threadId
  attr_accessor :cpuFeature

  def initialize(dynamicType = nil, dynamicProperty = [], index = nil, vendor = nil, hz = nil, busHz = nil, description = nil, threadId = [], cpuFeature = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @index = index
    @vendor = vendor
    @hz = hz
    @busHz = busHz
    @description = description
    @threadId = threadId
    @cpuFeature = cpuFeature
  end
end

# {urn:vim2}ArrayOfHostCpuPackage
class ArrayOfHostCpuPackage < ::Array
end

# {urn:vim2}HostNumaInfo
class HostNumaInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :numNodes
  attr_accessor :numaNode

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, numNodes = nil, numaNode = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @numNodes = numNodes
    @numaNode = numaNode
  end
end

# {urn:vim2}HostNumaNode
class HostNumaNode
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :typeId
  attr_accessor :cpuID
  attr_accessor :memoryRangeBegin
  attr_accessor :memoryRangeLength

  def initialize(dynamicType = nil, dynamicProperty = [], typeId = nil, cpuID = [], memoryRangeBegin = nil, memoryRangeLength = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @typeId = typeId
    @cpuID = cpuID
    @memoryRangeBegin = memoryRangeBegin
    @memoryRangeLength = memoryRangeLength
  end
end

# {urn:vim2}ArrayOfHostNumaNode
class ArrayOfHostNumaNode < ::Array
end

# {urn:vim2}HostHostBusAdapter
class HostHostBusAdapter
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :bus
  attr_accessor :status
  attr_accessor :model
  attr_accessor :driver
  attr_accessor :pci

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, bus = nil, status = nil, model = nil, driver = nil, pci = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @bus = bus
    @status = status
    @model = model
    @driver = driver
    @pci = pci
  end
end

# {urn:vim2}ArrayOfHostHostBusAdapter
class ArrayOfHostHostBusAdapter < ::Array
end

# {urn:vim2}HostParallelScsiHba
class HostParallelScsiHba
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :bus
  attr_accessor :status
  attr_accessor :model
  attr_accessor :driver
  attr_accessor :pci

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, bus = nil, status = nil, model = nil, driver = nil, pci = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @bus = bus
    @status = status
    @model = model
    @driver = driver
    @pci = pci
  end
end

# {urn:vim2}HostBlockHba
class HostBlockHba
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :bus
  attr_accessor :status
  attr_accessor :model
  attr_accessor :driver
  attr_accessor :pci

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, bus = nil, status = nil, model = nil, driver = nil, pci = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @bus = bus
    @status = status
    @model = model
    @driver = driver
    @pci = pci
  end
end

# {urn:vim2}HostFibreChannelHba
class HostFibreChannelHba
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :bus
  attr_accessor :status
  attr_accessor :model
  attr_accessor :driver
  attr_accessor :pci
  attr_accessor :portWorldWideName
  attr_accessor :nodeWorldWideName
  attr_accessor :portType
  attr_accessor :speed

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, bus = nil, status = nil, model = nil, driver = nil, pci = nil, portWorldWideName = nil, nodeWorldWideName = nil, portType = nil, speed = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @bus = bus
    @status = status
    @model = model
    @driver = driver
    @pci = pci
    @portWorldWideName = portWorldWideName
    @nodeWorldWideName = nodeWorldWideName
    @portType = portType
    @speed = speed
  end
end

# {urn:vim2}HostInternetScsiHbaDiscoveryCapabilities
class HostInternetScsiHbaDiscoveryCapabilities
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :iSnsDiscoverySettable
  attr_accessor :slpDiscoverySettable
  attr_accessor :staticTargetDiscoverySettable
  attr_accessor :sendTargetsDiscoverySettable

  def initialize(dynamicType = nil, dynamicProperty = [], iSnsDiscoverySettable = nil, slpDiscoverySettable = nil, staticTargetDiscoverySettable = nil, sendTargetsDiscoverySettable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @iSnsDiscoverySettable = iSnsDiscoverySettable
    @slpDiscoverySettable = slpDiscoverySettable
    @staticTargetDiscoverySettable = staticTargetDiscoverySettable
    @sendTargetsDiscoverySettable = sendTargetsDiscoverySettable
  end
end

# {urn:vim2}HostInternetScsiHbaDiscoveryProperties
class HostInternetScsiHbaDiscoveryProperties
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :iSnsDiscoveryEnabled
  attr_accessor :iSnsDiscoveryMethod
  attr_accessor :iSnsHost
  attr_accessor :slpDiscoveryEnabled
  attr_accessor :slpDiscoveryMethod
  attr_accessor :slpHost
  attr_accessor :staticTargetDiscoveryEnabled
  attr_accessor :sendTargetsDiscoveryEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], iSnsDiscoveryEnabled = nil, iSnsDiscoveryMethod = nil, iSnsHost = nil, slpDiscoveryEnabled = nil, slpDiscoveryMethod = nil, slpHost = nil, staticTargetDiscoveryEnabled = nil, sendTargetsDiscoveryEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @iSnsDiscoveryEnabled = iSnsDiscoveryEnabled
    @iSnsDiscoveryMethod = iSnsDiscoveryMethod
    @iSnsHost = iSnsHost
    @slpDiscoveryEnabled = slpDiscoveryEnabled
    @slpDiscoveryMethod = slpDiscoveryMethod
    @slpHost = slpHost
    @staticTargetDiscoveryEnabled = staticTargetDiscoveryEnabled
    @sendTargetsDiscoveryEnabled = sendTargetsDiscoveryEnabled
  end
end

# {urn:vim2}HostInternetScsiHbaAuthenticationCapabilities
class HostInternetScsiHbaAuthenticationCapabilities
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :chapAuthSettable
  attr_accessor :krb5AuthSettable
  attr_accessor :srpAuthSettable
  attr_accessor :spkmAuthSettable

  def initialize(dynamicType = nil, dynamicProperty = [], chapAuthSettable = nil, krb5AuthSettable = nil, srpAuthSettable = nil, spkmAuthSettable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @chapAuthSettable = chapAuthSettable
    @krb5AuthSettable = krb5AuthSettable
    @srpAuthSettable = srpAuthSettable
    @spkmAuthSettable = spkmAuthSettable
  end
end

# {urn:vim2}HostInternetScsiHbaAuthenticationProperties
class HostInternetScsiHbaAuthenticationProperties
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :chapAuthEnabled
  attr_accessor :chapName
  attr_accessor :chapSecret

  def initialize(dynamicType = nil, dynamicProperty = [], chapAuthEnabled = nil, chapName = nil, chapSecret = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @chapAuthEnabled = chapAuthEnabled
    @chapName = chapName
    @chapSecret = chapSecret
  end
end

# {urn:vim2}HostInternetScsiHbaIPCapabilities
class HostInternetScsiHbaIPCapabilities
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :addressSettable
  attr_accessor :ipConfigurationMethodSettable
  attr_accessor :subnetMaskSettable
  attr_accessor :defaultGatewaySettable
  attr_accessor :primaryDnsServerAddressSettable
  attr_accessor :alternateDnsServerAddressSettable

  def initialize(dynamicType = nil, dynamicProperty = [], addressSettable = nil, ipConfigurationMethodSettable = nil, subnetMaskSettable = nil, defaultGatewaySettable = nil, primaryDnsServerAddressSettable = nil, alternateDnsServerAddressSettable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @addressSettable = addressSettable
    @ipConfigurationMethodSettable = ipConfigurationMethodSettable
    @subnetMaskSettable = subnetMaskSettable
    @defaultGatewaySettable = defaultGatewaySettable
    @primaryDnsServerAddressSettable = primaryDnsServerAddressSettable
    @alternateDnsServerAddressSettable = alternateDnsServerAddressSettable
  end
end

# {urn:vim2}HostInternetScsiHbaIPProperties
class HostInternetScsiHbaIPProperties
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :mac
  attr_accessor :address
  attr_accessor :dhcpConfigurationEnabled
  attr_accessor :subnetMask
  attr_accessor :defaultGateway
  attr_accessor :primaryDnsServerAddress
  attr_accessor :alternateDnsServerAddress

  def initialize(dynamicType = nil, dynamicProperty = [], mac = nil, address = nil, dhcpConfigurationEnabled = nil, subnetMask = nil, defaultGateway = nil, primaryDnsServerAddress = nil, alternateDnsServerAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @mac = mac
    @address = address
    @dhcpConfigurationEnabled = dhcpConfigurationEnabled
    @subnetMask = subnetMask
    @defaultGateway = defaultGateway
    @primaryDnsServerAddress = primaryDnsServerAddress
    @alternateDnsServerAddress = alternateDnsServerAddress
  end
end

# {urn:vim2}HostInternetScsiHbaSendTarget
class HostInternetScsiHbaSendTarget
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :address
  attr_accessor :port

  def initialize(dynamicType = nil, dynamicProperty = [], address = nil, port = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @address = address
    @port = port
  end
end

# {urn:vim2}ArrayOfHostInternetScsiHbaSendTarget
class ArrayOfHostInternetScsiHbaSendTarget < ::Array
end

# {urn:vim2}HostInternetScsiHbaStaticTarget
class HostInternetScsiHbaStaticTarget
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :address
  attr_accessor :port
  attr_accessor :iScsiName

  def initialize(dynamicType = nil, dynamicProperty = [], address = nil, port = nil, iScsiName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @address = address
    @port = port
    @iScsiName = iScsiName
  end
end

# {urn:vim2}ArrayOfHostInternetScsiHbaStaticTarget
class ArrayOfHostInternetScsiHbaStaticTarget < ::Array
end

# {urn:vim2}HostInternetScsiHba
class HostInternetScsiHba
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :bus
  attr_accessor :status
  attr_accessor :model
  attr_accessor :driver
  attr_accessor :pci
  attr_accessor :isSoftwareBased
  attr_accessor :discoveryCapabilities
  attr_accessor :discoveryProperties
  attr_accessor :authenticationCapabilities
  attr_accessor :authenticationProperties
  attr_accessor :ipCapabilities
  attr_accessor :ipProperties
  attr_accessor :iScsiName
  attr_accessor :iScsiAlias
  attr_accessor :configuredSendTarget
  attr_accessor :configuredStaticTarget
  attr_accessor :maxSpeedMb
  attr_accessor :currentSpeedMb

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, bus = nil, status = nil, model = nil, driver = nil, pci = nil, isSoftwareBased = nil, discoveryCapabilities = nil, discoveryProperties = nil, authenticationCapabilities = nil, authenticationProperties = nil, ipCapabilities = nil, ipProperties = nil, iScsiName = nil, iScsiAlias = nil, configuredSendTarget = [], configuredStaticTarget = [], maxSpeedMb = nil, currentSpeedMb = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @bus = bus
    @status = status
    @model = model
    @driver = driver
    @pci = pci
    @isSoftwareBased = isSoftwareBased
    @discoveryCapabilities = discoveryCapabilities
    @discoveryProperties = discoveryProperties
    @authenticationCapabilities = authenticationCapabilities
    @authenticationProperties = authenticationProperties
    @ipCapabilities = ipCapabilities
    @ipProperties = ipProperties
    @iScsiName = iScsiName
    @iScsiAlias = iScsiAlias
    @configuredSendTarget = configuredSendTarget
    @configuredStaticTarget = configuredStaticTarget
    @maxSpeedMb = maxSpeedMb
    @currentSpeedMb = currentSpeedMb
  end
end

# {urn:vim2}HostIpConfig
class HostIpConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dhcp
  attr_accessor :ipAddress
  attr_accessor :subnetMask

  def initialize(dynamicType = nil, dynamicProperty = [], dhcp = nil, ipAddress = nil, subnetMask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dhcp = dhcp
    @ipAddress = ipAddress
    @subnetMask = subnetMask
  end
end

# {urn:vim2}HostIpRouteConfig
class HostIpRouteConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :defaultGateway
  attr_accessor :gatewayDevice

  def initialize(dynamicType = nil, dynamicProperty = [], defaultGateway = nil, gatewayDevice = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @defaultGateway = defaultGateway
    @gatewayDevice = gatewayDevice
  end
end

# {urn:vim2}HostAccountSpec
class HostAccountSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :password
  attr_accessor :description

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, password = nil, description = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @password = password
    @description = description
  end
end

# {urn:vim2}HostPosixAccountSpec
class HostPosixAccountSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :password
  attr_accessor :description
  attr_accessor :posixId
  attr_accessor :shellAccess

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, password = nil, description = nil, posixId = nil, shellAccess = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @password = password
    @description = description
    @posixId = posixId
    @shellAccess = shellAccess
  end
end

# {urn:vim2}ServiceConsoleReservationInfo
class ServiceConsoleReservationInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :serviceConsoleReservedCfg
  attr_accessor :serviceConsoleReserved
  attr_accessor :unreserved

  def initialize(dynamicType = nil, dynamicProperty = [], serviceConsoleReservedCfg = nil, serviceConsoleReserved = nil, unreserved = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @serviceConsoleReservedCfg = serviceConsoleReservedCfg
    @serviceConsoleReserved = serviceConsoleReserved
    @unreserved = unreserved
  end
end

# {urn:vim2}HostMountInfo
class HostMountInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :path
  attr_accessor :accessMode

  def initialize(dynamicType = nil, dynamicProperty = [], path = nil, accessMode = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @path = path
    @accessMode = accessMode
  end
end

# {urn:vim2}HostMultipathInfoLogicalUnitPolicy
class HostMultipathInfoLogicalUnitPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :policy

  def initialize(dynamicType = nil, dynamicProperty = [], policy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @policy = policy
  end
end

# {urn:vim2}HostMultipathInfoFixedLogicalUnitPolicy
class HostMultipathInfoFixedLogicalUnitPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :policy
  attr_accessor :prefer

  def initialize(dynamicType = nil, dynamicProperty = [], policy = nil, prefer = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @policy = policy
    @prefer = prefer
  end
end

# {urn:vim2}HostMultipathInfoLogicalUnit
class HostMultipathInfoLogicalUnit
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :id
  attr_accessor :lun
  attr_accessor :path
  attr_accessor :policy

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, id = nil, lun = nil, path = [], policy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @id = id
    @lun = lun
    @path = path
    @policy = policy
  end
end

# {urn:vim2}ArrayOfHostMultipathInfoLogicalUnit
class ArrayOfHostMultipathInfoLogicalUnit < ::Array
end

# {urn:vim2}HostMultipathInfoPath
class HostMultipathInfoPath
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :name
  attr_accessor :pathState
  attr_accessor :adapter
  attr_accessor :lun
  attr_accessor :transport

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, name = nil, pathState = nil, adapter = nil, lun = nil, transport = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @name = name
    @pathState = pathState
    @adapter = adapter
    @lun = lun
    @transport = transport
  end
end

# {urn:vim2}ArrayOfHostMultipathInfoPath
class ArrayOfHostMultipathInfoPath < ::Array
end

# {urn:vim2}HostMultipathInfo
class HostMultipathInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :lun

  def initialize(dynamicType = nil, dynamicProperty = [], lun = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @lun = lun
  end
end

# {urn:vim2}HostNetCapabilities
class HostNetCapabilities
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :canSetPhysicalNicLinkSpeed
  attr_accessor :supportsNicTeaming
  attr_accessor :nicTeamingPolicy
  attr_accessor :supportsVlan
  attr_accessor :usesServiceConsoleNic
  attr_accessor :supportsNetworkHints

  def initialize(dynamicType = nil, dynamicProperty = [], canSetPhysicalNicLinkSpeed = nil, supportsNicTeaming = nil, nicTeamingPolicy = [], supportsVlan = nil, usesServiceConsoleNic = nil, supportsNetworkHints = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @canSetPhysicalNicLinkSpeed = canSetPhysicalNicLinkSpeed
    @supportsNicTeaming = supportsNicTeaming
    @nicTeamingPolicy = nicTeamingPolicy
    @supportsVlan = supportsVlan
    @usesServiceConsoleNic = usesServiceConsoleNic
    @supportsNetworkHints = supportsNetworkHints
  end
end

# {urn:vim2}HostNetOffloadCapabilities
class HostNetOffloadCapabilities
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :csumOffload
  attr_accessor :tcpSegmentation
  attr_accessor :zeroCopyXmit

  def initialize(dynamicType = nil, dynamicProperty = [], csumOffload = nil, tcpSegmentation = nil, zeroCopyXmit = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @csumOffload = csumOffload
    @tcpSegmentation = tcpSegmentation
    @zeroCopyXmit = zeroCopyXmit
  end
end

# {urn:vim2}HostNetworkConfigResult
class HostNetworkConfigResult
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vnicDevice
  attr_accessor :consoleVnicDevice

  def initialize(dynamicType = nil, dynamicProperty = [], vnicDevice = [], consoleVnicDevice = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vnicDevice = vnicDevice
    @consoleVnicDevice = consoleVnicDevice
  end
end

# {urn:vim2}HostNetworkConfig
class HostNetworkConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vswitch
  attr_accessor :portgroup
  attr_accessor :pnic
  attr_accessor :vnic
  attr_accessor :consoleVnic
  attr_accessor :dnsConfig
  attr_accessor :ipRouteConfig
  attr_accessor :consoleIpRouteConfig

  def initialize(dynamicType = nil, dynamicProperty = [], vswitch = [], portgroup = [], pnic = [], vnic = [], consoleVnic = [], dnsConfig = nil, ipRouteConfig = nil, consoleIpRouteConfig = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vswitch = vswitch
    @portgroup = portgroup
    @pnic = pnic
    @vnic = vnic
    @consoleVnic = consoleVnic
    @dnsConfig = dnsConfig
    @ipRouteConfig = ipRouteConfig
    @consoleIpRouteConfig = consoleIpRouteConfig
  end
end

# {urn:vim2}HostNetworkInfo
class HostNetworkInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vswitch
  attr_accessor :portgroup
  attr_accessor :pnic
  attr_accessor :vnic
  attr_accessor :consoleVnic
  attr_accessor :dnsConfig
  attr_accessor :ipRouteConfig
  attr_accessor :consoleIpRouteConfig

  def initialize(dynamicType = nil, dynamicProperty = [], vswitch = [], portgroup = [], pnic = [], vnic = [], consoleVnic = [], dnsConfig = nil, ipRouteConfig = nil, consoleIpRouteConfig = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vswitch = vswitch
    @portgroup = portgroup
    @pnic = pnic
    @vnic = vnic
    @consoleVnic = consoleVnic
    @dnsConfig = dnsConfig
    @ipRouteConfig = ipRouteConfig
    @consoleIpRouteConfig = consoleIpRouteConfig
  end
end

# {urn:vim2}HostNetworkSecurityPolicy
class HostNetworkSecurityPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :allowPromiscuous
  attr_accessor :macChanges
  attr_accessor :forgedTransmits

  def initialize(dynamicType = nil, dynamicProperty = [], allowPromiscuous = nil, macChanges = nil, forgedTransmits = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @allowPromiscuous = allowPromiscuous
    @macChanges = macChanges
    @forgedTransmits = forgedTransmits
  end
end

# {urn:vim2}HostNetworkTrafficShapingPolicy
class HostNetworkTrafficShapingPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :enabled
  attr_accessor :averageBandwidth
  attr_accessor :peakBandwidth
  attr_accessor :burstSize

  def initialize(dynamicType = nil, dynamicProperty = [], enabled = nil, averageBandwidth = nil, peakBandwidth = nil, burstSize = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @enabled = enabled
    @averageBandwidth = averageBandwidth
    @peakBandwidth = peakBandwidth
    @burstSize = burstSize
  end
end

# {urn:vim2}HostNicFailureCriteria
class HostNicFailureCriteria
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :checkSpeed
  attr_accessor :speed
  attr_accessor :checkDuplex
  attr_accessor :fullDuplex
  attr_accessor :checkErrorPercent
  attr_accessor :percentage
  attr_accessor :checkBeacon

  def initialize(dynamicType = nil, dynamicProperty = [], checkSpeed = nil, speed = nil, checkDuplex = nil, fullDuplex = nil, checkErrorPercent = nil, percentage = nil, checkBeacon = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @checkSpeed = checkSpeed
    @speed = speed
    @checkDuplex = checkDuplex
    @fullDuplex = fullDuplex
    @checkErrorPercent = checkErrorPercent
    @percentage = percentage
    @checkBeacon = checkBeacon
  end
end

# {urn:vim2}HostNicOrderPolicy
class HostNicOrderPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeNic
  attr_accessor :standbyNic

  def initialize(dynamicType = nil, dynamicProperty = [], activeNic = [], standbyNic = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeNic = activeNic
    @standbyNic = standbyNic
  end
end

# {urn:vim2}HostNicTeamingPolicy
class HostNicTeamingPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :policy
  attr_accessor :reversePolicy
  attr_accessor :notifySwitches
  attr_accessor :rollingOrder
  attr_accessor :failureCriteria
  attr_accessor :nicOrder

  def initialize(dynamicType = nil, dynamicProperty = [], policy = nil, reversePolicy = nil, notifySwitches = nil, rollingOrder = nil, failureCriteria = nil, nicOrder = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @policy = policy
    @reversePolicy = reversePolicy
    @notifySwitches = notifySwitches
    @rollingOrder = rollingOrder
    @failureCriteria = failureCriteria
    @nicOrder = nicOrder
  end
end

# {urn:vim2}HostNetworkPolicy
class HostNetworkPolicy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :security
  attr_accessor :nicTeaming
  attr_accessor :offloadPolicy
  attr_accessor :shapingPolicy

  def initialize(dynamicType = nil, dynamicProperty = [], security = nil, nicTeaming = nil, offloadPolicy = nil, shapingPolicy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @security = security
    @nicTeaming = nicTeaming
    @offloadPolicy = offloadPolicy
    @shapingPolicy = shapingPolicy
  end
end

# {urn:vim2}HostPciDevice
class HostPciDevice
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :classId
  attr_accessor :bus
  attr_accessor :slot
  attr_accessor :function
  attr_accessor :vendorId
  attr_accessor :subVendorId
  attr_accessor :vendorName
  attr_accessor :deviceId
  attr_accessor :subDeviceId
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, classId = nil, bus = nil, slot = nil, function = nil, vendorId = nil, subVendorId = nil, vendorName = nil, deviceId = nil, subDeviceId = nil, deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @classId = classId
    @bus = bus
    @slot = slot
    @function = function
    @vendorId = vendorId
    @subVendorId = subVendorId
    @vendorName = vendorName
    @deviceId = deviceId
    @subDeviceId = subDeviceId
    @deviceName = deviceName
  end
end

# {urn:vim2}ArrayOfHostPciDevice
class ArrayOfHostPciDevice < ::Array
end

# {urn:vim2}PhysicalNicSpec
class PhysicalNicSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ip
  attr_accessor :linkSpeed

  def initialize(dynamicType = nil, dynamicProperty = [], ip = nil, linkSpeed = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ip = ip
    @linkSpeed = linkSpeed
  end
end

# {urn:vim2}PhysicalNicConfig
class PhysicalNicConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @spec = spec
  end
end

# {urn:vim2}ArrayOfPhysicalNicConfig
class ArrayOfPhysicalNicConfig < ::Array
end

# {urn:vim2}PhysicalNicLinkInfo
class PhysicalNicLinkInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :speedMb
  attr_accessor :duplex

  def initialize(dynamicType = nil, dynamicProperty = [], speedMb = nil, duplex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @speedMb = speedMb
    @duplex = duplex
  end
end

# {urn:vim2}ArrayOfPhysicalNicLinkInfo
class ArrayOfPhysicalNicLinkInfo < ::Array
end

# {urn:vim2}PhysicalNicHint
class PhysicalNicHint
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vlanId

  def initialize(dynamicType = nil, dynamicProperty = [], vlanId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vlanId = vlanId
  end
end

# {urn:vim2}PhysicalNicIpHint
class PhysicalNicIpHint
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vlanId
  attr_accessor :ipSubnet

  def initialize(dynamicType = nil, dynamicProperty = [], vlanId = nil, ipSubnet = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vlanId = vlanId
    @ipSubnet = ipSubnet
  end
end

# {urn:vim2}ArrayOfPhysicalNicIpHint
class ArrayOfPhysicalNicIpHint < ::Array
end

# {urn:vim2}PhysicalNicNameHint
class PhysicalNicNameHint
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vlanId
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], vlanId = nil, network = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vlanId = vlanId
    @network = network
  end
end

# {urn:vim2}ArrayOfPhysicalNicNameHint
class ArrayOfPhysicalNicNameHint < ::Array
end

# {urn:vim2}PhysicalNicHintInfo
class PhysicalNicHintInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :subnet
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, subnet = [], network = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @subnet = subnet
    @network = network
  end
end

# {urn:vim2}ArrayOfPhysicalNicHintInfo
class ArrayOfPhysicalNicHintInfo < ::Array
end

# {urn:vim2}PhysicalNic
class PhysicalNic
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :device
  attr_accessor :pci
  attr_accessor :driver
  attr_accessor :linkSpeed
  attr_accessor :validLinkSpecification
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, device = nil, pci = nil, driver = nil, linkSpeed = nil, validLinkSpecification = [], spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @device = device
    @pci = pci
    @driver = driver
    @linkSpeed = linkSpeed
    @validLinkSpecification = validLinkSpecification
    @spec = spec
  end
end

# {urn:vim2}ArrayOfPhysicalNic
class ArrayOfPhysicalNic < ::Array
end

# {urn:vim2}HostPortGroupSpec
class HostPortGroupSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :vlanId
  attr_accessor :vswitchName
  attr_accessor :policy

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, vlanId = nil, vswitchName = nil, policy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @vlanId = vlanId
    @vswitchName = vswitchName
    @policy = policy
  end
end

# {urn:vim2}HostPortGroupConfig
class HostPortGroupConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeOperation
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], changeOperation = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeOperation = changeOperation
    @spec = spec
  end
end

# {urn:vim2}ArrayOfHostPortGroupConfig
class ArrayOfHostPortGroupConfig < ::Array
end

# {urn:vim2}HostPortGroupPort
class HostPortGroupPort
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :mac
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, mac = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @mac = mac
    @type = type
  end
end

# {urn:vim2}ArrayOfHostPortGroupPort
class ArrayOfHostPortGroupPort < ::Array
end

# {urn:vim2}HostPortGroup
class HostPortGroup
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :port
  attr_accessor :vswitch
  attr_accessor :computedPolicy
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, port = [], vswitch = nil, computedPolicy = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @port = port
    @vswitch = vswitch
    @computedPolicy = computedPolicy
    @spec = spec
  end
end

# {urn:vim2}ArrayOfHostPortGroup
class ArrayOfHostPortGroup < ::Array
end

# {urn:vim2}HostFirewallRule
class HostFirewallRule
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :port
  attr_accessor :endPort
  attr_accessor :direction
  attr_accessor :protocol

  def initialize(dynamicType = nil, dynamicProperty = [], port = nil, endPort = nil, direction = nil, protocol = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @port = port
    @endPort = endPort
    @direction = direction
    @protocol = protocol
  end
end

# {urn:vim2}ArrayOfHostFirewallRule
class ArrayOfHostFirewallRule < ::Array
end

# {urn:vim2}HostFirewallRuleset
class HostFirewallRuleset
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :label
  attr_accessor :required
  attr_accessor :rule
  attr_accessor :service
  attr_accessor :enabled

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, label = nil, required = nil, rule = [], service = nil, enabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @label = label
    @required = required
    @rule = rule
    @service = service
    @enabled = enabled
  end
end

# {urn:vim2}ArrayOfHostFirewallRuleset
class ArrayOfHostFirewallRuleset < ::Array
end

# {urn:vim2}HostRuntimeInfo
class HostRuntimeInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :connectionState
  attr_accessor :inMaintenanceMode
  attr_accessor :bootTime

  def initialize(dynamicType = nil, dynamicProperty = [], connectionState = nil, inMaintenanceMode = nil, bootTime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @connectionState = connectionState
    @inMaintenanceMode = inMaintenanceMode
    @bootTime = bootTime
  end
end

# {urn:vim2}HostScsiDiskPartition
class HostScsiDiskPartition
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskName
  attr_accessor :partition

  def initialize(dynamicType = nil, dynamicProperty = [], diskName = nil, partition = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskName = diskName
    @partition = partition
  end
end

# {urn:vim2}ArrayOfHostScsiDiskPartition
class ArrayOfHostScsiDiskPartition < ::Array
end

# {urn:vim2}HostScsiDisk
class HostScsiDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :deviceType
  attr_accessor :key
  attr_accessor :uuid
  attr_accessor :canonicalName
  attr_accessor :lunType
  attr_accessor :vendor
  attr_accessor :model
  attr_accessor :revision
  attr_accessor :scsiLevel
  attr_accessor :serialNumber
  attr_accessor :durableName
  attr_accessor :queueDepth
  attr_accessor :operationalState
  attr_accessor :capacity
  attr_accessor :devicePath

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, deviceType = nil, key = nil, uuid = nil, canonicalName = nil, lunType = nil, vendor = nil, model = nil, revision = nil, scsiLevel = nil, serialNumber = nil, durableName = nil, queueDepth = nil, operationalState = [], capacity = nil, devicePath = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @deviceType = deviceType
    @key = key
    @uuid = uuid
    @canonicalName = canonicalName
    @lunType = lunType
    @vendor = vendor
    @model = model
    @revision = revision
    @scsiLevel = scsiLevel
    @serialNumber = serialNumber
    @durableName = durableName
    @queueDepth = queueDepth
    @operationalState = operationalState
    @capacity = capacity
    @devicePath = devicePath
  end
end

# {urn:vim2}ArrayOfHostScsiDisk
class ArrayOfHostScsiDisk < ::Array
end

# {urn:vim2}ScsiLunDurableName
class ScsiLunDurableName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :namespace
  attr_accessor :namespaceId
  attr_accessor :data

  def initialize(dynamicType = nil, dynamicProperty = [], namespace = nil, namespaceId = nil, data = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @namespace = namespace
    @namespaceId = namespaceId
    @data = data
  end
end

# {urn:vim2}ScsiLun
class ScsiLun
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :deviceType
  attr_accessor :key
  attr_accessor :uuid
  attr_accessor :canonicalName
  attr_accessor :lunType
  attr_accessor :vendor
  attr_accessor :model
  attr_accessor :revision
  attr_accessor :scsiLevel
  attr_accessor :serialNumber
  attr_accessor :durableName
  attr_accessor :queueDepth
  attr_accessor :operationalState

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, deviceType = nil, key = nil, uuid = nil, canonicalName = nil, lunType = nil, vendor = nil, model = nil, revision = nil, scsiLevel = nil, serialNumber = nil, durableName = nil, queueDepth = nil, operationalState = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @deviceType = deviceType
    @key = key
    @uuid = uuid
    @canonicalName = canonicalName
    @lunType = lunType
    @vendor = vendor
    @model = model
    @revision = revision
    @scsiLevel = scsiLevel
    @serialNumber = serialNumber
    @durableName = durableName
    @queueDepth = queueDepth
    @operationalState = operationalState
  end
end

# {urn:vim2}ArrayOfScsiLun
class ArrayOfScsiLun < ::Array
end

# {urn:vim2}HostScsiTopologyInterface
class HostScsiTopologyInterface
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :adapter
  attr_accessor :target

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, adapter = nil, target = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @adapter = adapter
    @target = target
  end
end

# {urn:vim2}ArrayOfHostScsiTopologyInterface
class ArrayOfHostScsiTopologyInterface < ::Array
end

# {urn:vim2}HostScsiTopologyTarget
class HostScsiTopologyTarget
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :target
  attr_accessor :lun
  attr_accessor :transport

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, target = nil, lun = [], transport = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @target = target
    @lun = lun
    @transport = transport
  end
end

# {urn:vim2}ArrayOfHostScsiTopologyTarget
class ArrayOfHostScsiTopologyTarget < ::Array
end

# {urn:vim2}HostScsiTopologyLun
class HostScsiTopologyLun
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :lun
  attr_accessor :scsiLun

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, lun = nil, scsiLun = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @lun = lun
    @scsiLun = scsiLun
  end
end

# {urn:vim2}ArrayOfHostScsiTopologyLun
class ArrayOfHostScsiTopologyLun < ::Array
end

# {urn:vim2}HostScsiTopology
class HostScsiTopology
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :adapter

  def initialize(dynamicType = nil, dynamicProperty = [], adapter = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @adapter = adapter
  end
end

# {urn:vim2}HostService
class HostService
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :label
  attr_accessor :required
  attr_accessor :uninstallable
  attr_accessor :running
  attr_accessor :ruleset
  attr_accessor :policy

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, label = nil, required = nil, uninstallable = nil, running = nil, ruleset = [], policy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @label = label
    @required = required
    @uninstallable = uninstallable
    @running = running
    @ruleset = ruleset
    @policy = policy
  end
end

# {urn:vim2}ArrayOfHostService
class ArrayOfHostService < ::Array
end

# {urn:vim2}HostServiceInfo
class HostServiceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :service

  def initialize(dynamicType = nil, dynamicProperty = [], service = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @service = service
  end
end

# {urn:vim2}HostSnmpConfig
class HostSnmpConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :autoStartMasterSnmpAgentEnabled
  attr_accessor :startupScript
  attr_accessor :configFile
  attr_accessor :vmwareSubagentEnabled
  attr_accessor :vmwareTrapsEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], autoStartMasterSnmpAgentEnabled = nil, startupScript = nil, configFile = nil, vmwareSubagentEnabled = nil, vmwareTrapsEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @autoStartMasterSnmpAgentEnabled = autoStartMasterSnmpAgentEnabled
    @startupScript = startupScript
    @configFile = configFile
    @vmwareSubagentEnabled = vmwareSubagentEnabled
    @vmwareTrapsEnabled = vmwareTrapsEnabled
  end
end

# {urn:vim2}HostStorageDeviceInfo
class HostStorageDeviceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :hostBusAdapter
  attr_accessor :scsiLun
  attr_accessor :scsiTopology
  attr_accessor :multipathInfo
  attr_accessor :softwareInternetScsiEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], hostBusAdapter = [], scsiLun = [], scsiTopology = nil, multipathInfo = nil, softwareInternetScsiEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @hostBusAdapter = hostBusAdapter
    @scsiLun = scsiLun
    @scsiTopology = scsiTopology
    @multipathInfo = multipathInfo
    @softwareInternetScsiEnabled = softwareInternetScsiEnabled
  end
end

# {urn:vim2}HostHardwareSummary
class HostHardwareSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vendor
  attr_accessor :model
  attr_accessor :uuid
  attr_accessor :memorySize
  attr_accessor :cpuModel
  attr_accessor :cpuMhz
  attr_accessor :numCpuPkgs
  attr_accessor :numCpuCores
  attr_accessor :numCpuThreads
  attr_accessor :numNics
  attr_accessor :numHBAs

  def initialize(dynamicType = nil, dynamicProperty = [], vendor = nil, model = nil, uuid = nil, memorySize = nil, cpuModel = nil, cpuMhz = nil, numCpuPkgs = nil, numCpuCores = nil, numCpuThreads = nil, numNics = nil, numHBAs = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vendor = vendor
    @model = model
    @uuid = uuid
    @memorySize = memorySize
    @cpuModel = cpuModel
    @cpuMhz = cpuMhz
    @numCpuPkgs = numCpuPkgs
    @numCpuCores = numCpuCores
    @numCpuThreads = numCpuThreads
    @numNics = numNics
    @numHBAs = numHBAs
  end
end

# {urn:vim2}HostListSummaryQuickStats
class HostListSummaryQuickStats
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :overallCpuUsage
  attr_accessor :overallMemoryUsage
  attr_accessor :distributedCpuFairness
  attr_accessor :distributedMemoryFairness

  def initialize(dynamicType = nil, dynamicProperty = [], overallCpuUsage = nil, overallMemoryUsage = nil, distributedCpuFairness = nil, distributedMemoryFairness = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @overallCpuUsage = overallCpuUsage
    @overallMemoryUsage = overallMemoryUsage
    @distributedCpuFairness = distributedCpuFairness
    @distributedMemoryFairness = distributedMemoryFairness
  end
end

# {urn:vim2}HostConfigSummary
class HostConfigSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :port
  attr_accessor :product
  attr_accessor :vmotionEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, port = nil, product = nil, vmotionEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @port = port
    @product = product
    @vmotionEnabled = vmotionEnabled
  end
end

# {urn:vim2}HostListSummary
class HostListSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :hardware
  attr_accessor :runtime
  attr_accessor :config
  attr_accessor :quickStats
  attr_accessor :overallStatus
  attr_accessor :rebootRequired
  attr_accessor :customValue

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, hardware = nil, runtime = nil, config = nil, quickStats = nil, overallStatus = nil, rebootRequired = nil, customValue = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @hardware = hardware
    @runtime = runtime
    @config = config
    @quickStats = quickStats
    @overallStatus = overallStatus
    @rebootRequired = rebootRequired
    @customValue = customValue
  end
end

# {urn:vim2}HostSystemResourceInfo
class HostSystemResourceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :config
  attr_accessor :child

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, config = nil, child = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @config = config
    @child = child
  end
end

# {urn:vim2}ArrayOfHostSystemResourceInfo
class ArrayOfHostSystemResourceInfo < ::Array
end

# {urn:vim2}HostTargetTransport
class HostTargetTransport
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostParallelScsiTargetTransport
class HostParallelScsiTargetTransport
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostBlockAdapterTargetTransport
class HostBlockAdapterTargetTransport
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostFibreChannelTargetTransport
class HostFibreChannelTargetTransport
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :portWorldWideName
  attr_accessor :nodeWorldWideName

  def initialize(dynamicType = nil, dynamicProperty = [], portWorldWideName = nil, nodeWorldWideName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @portWorldWideName = portWorldWideName
    @nodeWorldWideName = nodeWorldWideName
  end
end

# {urn:vim2}HostInternetScsiTargetTransport
class HostInternetScsiTargetTransport
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :iScsiName
  attr_accessor :iScsiAlias
  attr_accessor :address

  def initialize(dynamicType = nil, dynamicProperty = [], iScsiName = nil, iScsiAlias = nil, address = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @iScsiName = iScsiName
    @iScsiAlias = iScsiAlias
    @address = address
  end
end

# {urn:vim2}HostVMotionConfig
class HostVMotionConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vmotionNicKey
  attr_accessor :enabled

  def initialize(dynamicType = nil, dynamicProperty = [], vmotionNicKey = nil, enabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vmotionNicKey = vmotionNicKey
    @enabled = enabled
  end
end

# {urn:vim2}HostVMotionInfo
class HostVMotionInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :netConfig
  attr_accessor :ipConfig

  def initialize(dynamicType = nil, dynamicProperty = [], netConfig = nil, ipConfig = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @netConfig = netConfig
    @ipConfig = ipConfig
  end
end

# {urn:vim2}HostVMotionManagerSpec
class HostVMotionManagerSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :migrationId
  attr_accessor :srcIp
  attr_accessor :dstIp
  attr_accessor :srcUuid
  attr_accessor :dstUuid
  attr_accessor :priority

  def initialize(dynamicType = nil, dynamicProperty = [], migrationId = nil, srcIp = nil, dstIp = nil, srcUuid = nil, dstUuid = nil, priority = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @migrationId = migrationId
    @srcIp = srcIp
    @dstIp = dstIp
    @srcUuid = srcUuid
    @dstUuid = dstUuid
    @priority = priority
  end
end

# {urn:vim2}HostVMotionManagerDestinationState
class HostVMotionManagerDestinationState
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dstId
  attr_accessor :dstTask

  def initialize(dynamicType = nil, dynamicProperty = [], dstId = nil, dstTask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dstId = dstId
    @dstTask = dstTask
  end
end

# {urn:vim2}HostVMotionManagerReparentSpec
class HostVMotionManagerReparentSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :busNumber
  attr_accessor :unitNumber
  attr_accessor :filename

  def initialize(dynamicType = nil, dynamicProperty = [], busNumber = nil, unitNumber = nil, filename = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @busNumber = busNumber
    @unitNumber = unitNumber
    @filename = filename
  end
end

# {urn:vim2}ArrayOfHostVMotionManagerReparentSpec
class ArrayOfHostVMotionManagerReparentSpec < ::Array
end

# {urn:vim2}HostVMotionNetConfig
class HostVMotionNetConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :candidateVnic
  attr_accessor :selectedVnic

  def initialize(dynamicType = nil, dynamicProperty = [], candidateVnic = [], selectedVnic = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @candidateVnic = candidateVnic
    @selectedVnic = selectedVnic
  end
end

# {urn:vim2}HostVirtualNicSpec
class HostVirtualNicSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ip
  attr_accessor :mac

  def initialize(dynamicType = nil, dynamicProperty = [], ip = nil, mac = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ip = ip
    @mac = mac
  end
end

# {urn:vim2}HostVirtualNicConfig
class HostVirtualNicConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeOperation
  attr_accessor :device
  attr_accessor :portgroup
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], changeOperation = nil, device = nil, portgroup = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeOperation = changeOperation
    @device = device
    @portgroup = portgroup
    @spec = spec
  end
end

# {urn:vim2}ArrayOfHostVirtualNicConfig
class ArrayOfHostVirtualNicConfig < ::Array
end

# {urn:vim2}HostVirtualNic
class HostVirtualNic
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :device
  attr_accessor :key
  attr_accessor :portgroup
  attr_accessor :spec
  attr_accessor :port

  def initialize(dynamicType = nil, dynamicProperty = [], device = nil, key = nil, portgroup = nil, spec = nil, port = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @device = device
    @key = key
    @portgroup = portgroup
    @spec = spec
    @port = port
  end
end

# {urn:vim2}ArrayOfHostVirtualNic
class ArrayOfHostVirtualNic < ::Array
end

# {urn:vim2}HostVirtualSwitchBridge
class HostVirtualSwitchBridge
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostVirtualSwitchAutoBridge
class HostVirtualSwitchAutoBridge
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}HostVirtualSwitchSimpleBridge
class HostVirtualSwitchSimpleBridge
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :nicDevice

  def initialize(dynamicType = nil, dynamicProperty = [], nicDevice = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @nicDevice = nicDevice
  end
end

# {urn:vim2}HostVirtualSwitchBondBridge
class HostVirtualSwitchBondBridge
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :nicDevice
  attr_accessor :beacon

  def initialize(dynamicType = nil, dynamicProperty = [], nicDevice = [], beacon = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @nicDevice = nicDevice
    @beacon = beacon
  end
end

# {urn:vim2}HostVirtualSwitchBeaconConfig
class HostVirtualSwitchBeaconConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :interval

  def initialize(dynamicType = nil, dynamicProperty = [], interval = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @interval = interval
  end
end

# {urn:vim2}HostVirtualSwitchSpec
class HostVirtualSwitchSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numPorts
  attr_accessor :bridge
  attr_accessor :policy

  def initialize(dynamicType = nil, dynamicProperty = [], numPorts = nil, bridge = nil, policy = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numPorts = numPorts
    @bridge = bridge
    @policy = policy
  end
end

# {urn:vim2}HostVirtualSwitchConfig
class HostVirtualSwitchConfig
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeOperation
  attr_accessor :name
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], changeOperation = nil, name = nil, spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeOperation = changeOperation
    @name = name
    @spec = spec
  end
end

# {urn:vim2}ArrayOfHostVirtualSwitchConfig
class ArrayOfHostVirtualSwitchConfig < ::Array
end

# {urn:vim2}HostVirtualSwitch
class HostVirtualSwitch
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :key
  attr_accessor :numPorts
  attr_accessor :numPortsAvailable
  attr_accessor :portgroup
  attr_accessor :pnic
  attr_accessor :spec

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, key = nil, numPorts = nil, numPortsAvailable = nil, portgroup = [], pnic = [], spec = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @key = key
    @numPorts = numPorts
    @numPortsAvailable = numPortsAvailable
    @portgroup = portgroup
    @pnic = pnic
    @spec = spec
  end
end

# {urn:vim2}ArrayOfHostVirtualSwitch
class ArrayOfHostVirtualSwitch < ::Array
end

# {urn:vim2}HostVmfsSpec
class HostVmfsSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :extent
  attr_accessor :blockSizeMb
  attr_accessor :majorVersion
  attr_accessor :volumeName

  def initialize(dynamicType = nil, dynamicProperty = [], extent = nil, blockSizeMb = nil, majorVersion = nil, volumeName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @extent = extent
    @blockSizeMb = blockSizeMb
    @majorVersion = majorVersion
    @volumeName = volumeName
  end
end

# {urn:vim2}HostVmfsVolume
class HostVmfsVolume
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :name
  attr_accessor :capacity
  attr_accessor :blockSizeMb
  attr_accessor :maxBlocks
  attr_accessor :majorVersion
  attr_accessor :version
  attr_accessor :uuid
  attr_accessor :extent
  attr_accessor :vmfsUpgradable

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, name = nil, capacity = nil, blockSizeMb = nil, maxBlocks = nil, majorVersion = nil, version = nil, uuid = nil, extent = [], vmfsUpgradable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @name = name
    @capacity = capacity
    @blockSizeMb = blockSizeMb
    @maxBlocks = maxBlocks
    @majorVersion = majorVersion
    @version = version
    @uuid = uuid
    @extent = extent
    @vmfsUpgradable = vmfsUpgradable
  end
end

# {urn:vim2}ArrayUpdateSpec
class ArrayUpdateSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :removeKey

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, removeKey = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @removeKey = removeKey
  end
end

# {urn:vim2}BoolOption
class BoolOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :supported
  attr_accessor :defaultValue

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, supported = nil, defaultValue = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @supported = supported
    @defaultValue = defaultValue
  end
end

# {urn:vim2}ChoiceOption
class ChoiceOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :choiceInfo
  attr_accessor :defaultIndex

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, choiceInfo = [], defaultIndex = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @choiceInfo = choiceInfo
    @defaultIndex = defaultIndex
  end
end

# {urn:vim2}FloatOption
class FloatOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :min
  attr_accessor :max
  attr_accessor :defaultValue

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, min = nil, max = nil, defaultValue = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @min = min
    @max = max
    @defaultValue = defaultValue
  end
end

# {urn:vim2}IntOption
class IntOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :min
  attr_accessor :max
  attr_accessor :defaultValue

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, min = nil, max = nil, defaultValue = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @min = min
    @max = max
    @defaultValue = defaultValue
  end
end

# {urn:vim2}LongOption
class LongOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :min
  attr_accessor :max
  attr_accessor :defaultValue

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, min = nil, max = nil, defaultValue = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @min = min
    @max = max
    @defaultValue = defaultValue
  end
end

# {urn:vim2}OptionDef
class OptionDef
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary
  attr_accessor :key
  attr_accessor :optionType

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil, key = nil, optionType = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
    @key = key
    @optionType = optionType
  end
end

# {urn:vim2}ArrayOfOptionDef
class ArrayOfOptionDef < ::Array
end

# {urn:vim2}OptionType
class OptionType
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
  end
end

# {urn:vim2}OptionValue
class OptionValue
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @value = value
  end
end

# {urn:vim2}ArrayOfOptionValue
class ArrayOfOptionValue < ::Array
end

# {urn:vim2}StringOption
class StringOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :valueIsReadonly
  attr_accessor :defaultValue
  attr_accessor :validCharacters

  def initialize(dynamicType = nil, dynamicProperty = [], valueIsReadonly = nil, defaultValue = nil, validCharacters = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @valueIsReadonly = valueIsReadonly
    @defaultValue = defaultValue
    @validCharacters = validCharacters
  end
end

# {urn:vim2}ScheduledTaskDetail
class ScheduledTaskDetail
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :label
  attr_accessor :summary
  attr_accessor :key
  attr_accessor :frequency

  def initialize(dynamicType = nil, dynamicProperty = [], label = nil, summary = nil, key = nil, frequency = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @label = label
    @summary = summary
    @key = key
    @frequency = frequency
  end
end

# {urn:vim2}ArrayOfScheduledTaskDetail
class ArrayOfScheduledTaskDetail < ::Array
end

# {urn:vim2}ScheduledTaskDescription
class ScheduledTaskDescription
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :action
  attr_accessor :schedulerInfo
  attr_accessor :state
  attr_accessor :dayOfWeek
  attr_accessor :weekOfMonth

  def initialize(dynamicType = nil, dynamicProperty = [], action = [], schedulerInfo = [], state = [], dayOfWeek = [], weekOfMonth = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @action = action
    @schedulerInfo = schedulerInfo
    @state = state
    @dayOfWeek = dayOfWeek
    @weekOfMonth = weekOfMonth
  end
end

# {urn:vim2}ScheduledTaskInfo
class ScheduledTaskInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :description
  attr_accessor :enabled
  attr_accessor :scheduler
  attr_accessor :action
  attr_accessor :notification
  attr_accessor :scheduledTask
  attr_accessor :entity
  attr_accessor :lastModifiedTime
  attr_accessor :lastModifiedUser
  attr_accessor :nextRunTime
  attr_accessor :prevRunTime
  attr_accessor :state
  attr_accessor :error
  attr_accessor :result
  attr_accessor :progress
  attr_accessor :activeTask

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, description = nil, enabled = nil, scheduler = nil, action = nil, notification = nil, scheduledTask = nil, entity = nil, lastModifiedTime = nil, lastModifiedUser = nil, nextRunTime = nil, prevRunTime = nil, state = nil, error = nil, result = nil, progress = nil, activeTask = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @description = description
    @enabled = enabled
    @scheduler = scheduler
    @action = action
    @notification = notification
    @scheduledTask = scheduledTask
    @entity = entity
    @lastModifiedTime = lastModifiedTime
    @lastModifiedUser = lastModifiedUser
    @nextRunTime = nextRunTime
    @prevRunTime = prevRunTime
    @state = state
    @error = error
    @result = result
    @progress = progress
    @activeTask = activeTask
  end
end

# {urn:vim2}TaskScheduler
class TaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
  end
end

# {urn:vim2}AfterStartupTaskScheduler
class AfterStartupTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :minute

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, minute = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @minute = minute
  end
end

# {urn:vim2}OnceTaskScheduler
class OnceTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :runAt

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, runAt = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @runAt = runAt
  end
end

# {urn:vim2}RecurrentTaskScheduler
class RecurrentTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
  end
end

# {urn:vim2}HourlyTaskScheduler
class HourlyTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
  end
end

# {urn:vim2}DailyTaskScheduler
class DailyTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute
  attr_accessor :hour

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil, hour = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
    @hour = hour
  end
end

# {urn:vim2}WeeklyTaskScheduler
class WeeklyTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute
  attr_accessor :hour
  attr_accessor :sunday
  attr_accessor :monday
  attr_accessor :tuesday
  attr_accessor :wednesday
  attr_accessor :thursday
  attr_accessor :friday
  attr_accessor :saturday

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil, hour = nil, sunday = nil, monday = nil, tuesday = nil, wednesday = nil, thursday = nil, friday = nil, saturday = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
    @hour = hour
    @sunday = sunday
    @monday = monday
    @tuesday = tuesday
    @wednesday = wednesday
    @thursday = thursday
    @friday = friday
    @saturday = saturday
  end
end

# {urn:vim2}MonthlyTaskScheduler
class MonthlyTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute
  attr_accessor :hour

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil, hour = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
    @hour = hour
  end
end

# {urn:vim2}MonthlyByDayTaskScheduler
class MonthlyByDayTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute
  attr_accessor :hour
  attr_accessor :day

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil, hour = nil, day = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
    @hour = hour
    @day = day
  end
end

# {urn:vim2}MonthlyByWeekdayTaskScheduler
class MonthlyByWeekdayTaskScheduler
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :activeTime
  attr_accessor :expireTime
  attr_accessor :interval
  attr_accessor :minute
  attr_accessor :hour
  attr_accessor :offset
  attr_accessor :weekday

  def initialize(dynamicType = nil, dynamicProperty = [], activeTime = nil, expireTime = nil, interval = nil, minute = nil, hour = nil, offset = nil, weekday = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @activeTime = activeTime
    @expireTime = expireTime
    @interval = interval
    @minute = minute
    @hour = hour
    @offset = offset
    @weekday = weekday
  end
end

# {urn:vim2}ScheduledTaskSpec
class ScheduledTaskSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :description
  attr_accessor :enabled
  attr_accessor :scheduler
  attr_accessor :action
  attr_accessor :notification

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, description = nil, enabled = nil, scheduler = nil, action = nil, notification = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @description = description
    @enabled = enabled
    @scheduler = scheduler
    @action = action
    @notification = notification
  end
end

# {urn:vim2}VirtualMachineAffinityInfo
class VirtualMachineAffinityInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :affinitySet

  def initialize(dynamicType = nil, dynamicProperty = [], affinitySet = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @affinitySet = affinitySet
  end
end

# {urn:vim2}VirtualMachineCapability
class VirtualMachineCapability
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :snapshotOperationsSupported
  attr_accessor :multipleSnapshotsSupported
  attr_accessor :snapshotConfigSupported
  attr_accessor :poweredOffSnapshotsSupported
  attr_accessor :memorySnapshotsSupported
  attr_accessor :revertToSnapshotSupported
  attr_accessor :quiescedSnapshotsSupported
  attr_accessor :consolePreferencesSupported
  attr_accessor :cpuFeatureMaskSupported
  attr_accessor :s1AcpiManagementSupported
  attr_accessor :settingScreenResolutionSupported
  attr_accessor :toolsAutoUpdateSupported

  def initialize(dynamicType = nil, dynamicProperty = [], snapshotOperationsSupported = nil, multipleSnapshotsSupported = nil, snapshotConfigSupported = nil, poweredOffSnapshotsSupported = nil, memorySnapshotsSupported = nil, revertToSnapshotSupported = nil, quiescedSnapshotsSupported = nil, consolePreferencesSupported = nil, cpuFeatureMaskSupported = nil, s1AcpiManagementSupported = nil, settingScreenResolutionSupported = nil, toolsAutoUpdateSupported = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @snapshotOperationsSupported = snapshotOperationsSupported
    @multipleSnapshotsSupported = multipleSnapshotsSupported
    @snapshotConfigSupported = snapshotConfigSupported
    @poweredOffSnapshotsSupported = poweredOffSnapshotsSupported
    @memorySnapshotsSupported = memorySnapshotsSupported
    @revertToSnapshotSupported = revertToSnapshotSupported
    @quiescedSnapshotsSupported = quiescedSnapshotsSupported
    @consolePreferencesSupported = consolePreferencesSupported
    @cpuFeatureMaskSupported = cpuFeatureMaskSupported
    @s1AcpiManagementSupported = s1AcpiManagementSupported
    @settingScreenResolutionSupported = settingScreenResolutionSupported
    @toolsAutoUpdateSupported = toolsAutoUpdateSupported
  end
end

# {urn:vim2}VirtualMachineCdromInfo
class VirtualMachineCdromInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
  end
end

# {urn:vim2}ArrayOfVirtualMachineCdromInfo
class ArrayOfVirtualMachineCdromInfo < ::Array
end

# {urn:vim2}VirtualMachineCloneSpec
class VirtualMachineCloneSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :location
  attr_accessor :template
  attr_accessor :config
  attr_accessor :customization
  attr_accessor :powerOn

  def initialize(dynamicType = nil, dynamicProperty = [], location = nil, template = nil, config = nil, customization = nil, powerOn = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @location = location
    @template = template
    @config = config
    @customization = customization
    @powerOn = powerOn
  end
end

# {urn:vim2}VirtualMachineConfigInfoDatastoreUrlPair
class VirtualMachineConfigInfoDatastoreUrlPair
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :url

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, url = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @url = url
  end
end

# {urn:vim2}ArrayOfVirtualMachineConfigInfoDatastoreUrlPair
class ArrayOfVirtualMachineConfigInfoDatastoreUrlPair < ::Array
end

# {urn:vim2}VirtualMachineConfigInfo
class VirtualMachineConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeVersion
  attr_accessor :modified
  attr_accessor :name
  attr_accessor :guestFullName
  attr_accessor :version
  attr_accessor :uuid
  attr_accessor :locationId
  attr_accessor :template
  attr_accessor :guestId
  attr_accessor :annotation
  attr_accessor :files
  attr_accessor :tools
  attr_accessor :flags
  attr_accessor :consolePreferences
  attr_accessor :defaultPowerOps
  attr_accessor :hardware
  attr_accessor :cpuAllocation
  attr_accessor :memoryAllocation
  attr_accessor :cpuAffinity
  attr_accessor :memoryAffinity
  attr_accessor :networkShaper
  attr_accessor :extraConfig
  attr_accessor :cpuFeatureMask
  attr_accessor :datastoreUrl

  def initialize(dynamicType = nil, dynamicProperty = [], changeVersion = nil, modified = nil, name = nil, guestFullName = nil, version = nil, uuid = nil, locationId = nil, template = nil, guestId = nil, annotation = nil, files = nil, tools = nil, flags = nil, consolePreferences = nil, defaultPowerOps = nil, hardware = nil, cpuAllocation = nil, memoryAllocation = nil, cpuAffinity = nil, memoryAffinity = nil, networkShaper = nil, extraConfig = [], cpuFeatureMask = [], datastoreUrl = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeVersion = changeVersion
    @modified = modified
    @name = name
    @guestFullName = guestFullName
    @version = version
    @uuid = uuid
    @locationId = locationId
    @template = template
    @guestId = guestId
    @annotation = annotation
    @files = files
    @tools = tools
    @flags = flags
    @consolePreferences = consolePreferences
    @defaultPowerOps = defaultPowerOps
    @hardware = hardware
    @cpuAllocation = cpuAllocation
    @memoryAllocation = memoryAllocation
    @cpuAffinity = cpuAffinity
    @memoryAffinity = memoryAffinity
    @networkShaper = networkShaper
    @extraConfig = extraConfig
    @cpuFeatureMask = cpuFeatureMask
    @datastoreUrl = datastoreUrl
  end
end

# {urn:vim2}VirtualMachineConfigOption
class VirtualMachineConfigOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :version
  attr_accessor :description
  attr_accessor :guestOSDescriptor
  attr_accessor :guestOSDefaultIndex
  attr_accessor :hardwareOptions
  attr_accessor :capabilities
  attr_accessor :datastore
  attr_accessor :defaultDevice

  def initialize(dynamicType = nil, dynamicProperty = [], version = nil, description = nil, guestOSDescriptor = [], guestOSDefaultIndex = nil, hardwareOptions = nil, capabilities = nil, datastore = nil, defaultDevice = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @version = version
    @description = description
    @guestOSDescriptor = guestOSDescriptor
    @guestOSDefaultIndex = guestOSDefaultIndex
    @hardwareOptions = hardwareOptions
    @capabilities = capabilities
    @datastore = datastore
    @defaultDevice = defaultDevice
  end
end

# {urn:vim2}VirtualMachineConfigOptionDescriptor
class VirtualMachineConfigOptionDescriptor
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :description
  attr_accessor :host

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, description = nil, host = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @description = description
    @host = host
  end
end

# {urn:vim2}ArrayOfVirtualMachineConfigOptionDescriptor
class ArrayOfVirtualMachineConfigOptionDescriptor < ::Array
end

# {urn:vim2}VirtualMachineCpuIdInfoSpec
class VirtualMachineCpuIdInfoSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :removeKey
  attr_accessor :info

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, removeKey = nil, info = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @removeKey = removeKey
    @info = info
  end
end

# {urn:vim2}ArrayOfVirtualMachineCpuIdInfoSpec
class ArrayOfVirtualMachineCpuIdInfoSpec < ::Array
end

# {urn:vim2}VirtualMachineConfigSpec
class VirtualMachineConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeVersion
  attr_accessor :name
  attr_accessor :version
  attr_accessor :uuid
  attr_accessor :locationId
  attr_accessor :guestId
  attr_accessor :annotation
  attr_accessor :files
  attr_accessor :tools
  attr_accessor :flags
  attr_accessor :consolePreferences
  attr_accessor :powerOpInfo
  attr_accessor :numCPUs
  attr_accessor :memoryMB
  attr_accessor :deviceChange
  attr_accessor :cpuAllocation
  attr_accessor :memoryAllocation
  attr_accessor :cpuAffinity
  attr_accessor :memoryAffinity
  attr_accessor :networkShaper
  attr_accessor :cpuFeatureMask
  attr_accessor :extraConfig

  def initialize(dynamicType = nil, dynamicProperty = [], changeVersion = nil, name = nil, version = nil, uuid = nil, locationId = nil, guestId = nil, annotation = nil, files = nil, tools = nil, flags = nil, consolePreferences = nil, powerOpInfo = nil, numCPUs = nil, memoryMB = nil, deviceChange = [], cpuAllocation = nil, memoryAllocation = nil, cpuAffinity = nil, memoryAffinity = nil, networkShaper = nil, cpuFeatureMask = [], extraConfig = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeVersion = changeVersion
    @name = name
    @version = version
    @uuid = uuid
    @locationId = locationId
    @guestId = guestId
    @annotation = annotation
    @files = files
    @tools = tools
    @flags = flags
    @consolePreferences = consolePreferences
    @powerOpInfo = powerOpInfo
    @numCPUs = numCPUs
    @memoryMB = memoryMB
    @deviceChange = deviceChange
    @cpuAllocation = cpuAllocation
    @memoryAllocation = memoryAllocation
    @cpuAffinity = cpuAffinity
    @memoryAffinity = memoryAffinity
    @networkShaper = networkShaper
    @cpuFeatureMask = cpuFeatureMask
    @extraConfig = extraConfig
  end
end

# {urn:vim2}ConfigTarget
class ConfigTarget
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numCpus
  attr_accessor :numCpuCores
  attr_accessor :numNumaNodes
  attr_accessor :datastore
  attr_accessor :network
  attr_accessor :cdRom
  attr_accessor :serial
  attr_accessor :parallel
  attr_accessor :floppy
  attr_accessor :legacyNetworkInfo
  attr_accessor :scsiPassthrough
  attr_accessor :scsiDisk
  attr_accessor :ideDisk
  attr_accessor :maxMemMBOptimalPerf
  attr_accessor :resourcePool
  attr_accessor :autoVmotion

  def initialize(dynamicType = nil, dynamicProperty = [], numCpus = nil, numCpuCores = nil, numNumaNodes = nil, datastore = [], network = [], cdRom = [], serial = [], parallel = [], floppy = [], legacyNetworkInfo = [], scsiPassthrough = [], scsiDisk = [], ideDisk = [], maxMemMBOptimalPerf = nil, resourcePool = nil, autoVmotion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numCpus = numCpus
    @numCpuCores = numCpuCores
    @numNumaNodes = numNumaNodes
    @datastore = datastore
    @network = network
    @cdRom = cdRom
    @serial = serial
    @parallel = parallel
    @floppy = floppy
    @legacyNetworkInfo = legacyNetworkInfo
    @scsiPassthrough = scsiPassthrough
    @scsiDisk = scsiDisk
    @ideDisk = ideDisk
    @maxMemMBOptimalPerf = maxMemMBOptimalPerf
    @resourcePool = resourcePool
    @autoVmotion = autoVmotion
  end
end

# {urn:vim2}VirtualMachineConsolePreferences
class VirtualMachineConsolePreferences
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :powerOnWhenOpened
  attr_accessor :enterFullScreenOnPowerOn
  attr_accessor :closeOnPowerOffOrSuspend

  def initialize(dynamicType = nil, dynamicProperty = [], powerOnWhenOpened = nil, enterFullScreenOnPowerOn = nil, closeOnPowerOffOrSuspend = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @powerOnWhenOpened = powerOnWhenOpened
    @enterFullScreenOnPowerOn = enterFullScreenOnPowerOn
    @closeOnPowerOffOrSuspend = closeOnPowerOffOrSuspend
  end
end

# {urn:vim2}VirtualMachineDatastoreInfo
class VirtualMachineDatastoreInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :datastore
  attr_accessor :capability
  attr_accessor :maxFileSize
  attr_accessor :mode

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], datastore = nil, capability = nil, maxFileSize = nil, mode = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @datastore = datastore
    @capability = capability
    @maxFileSize = maxFileSize
    @mode = mode
  end
end

# {urn:vim2}ArrayOfVirtualMachineDatastoreInfo
class ArrayOfVirtualMachineDatastoreInfo < ::Array
end

# {urn:vim2}VirtualMachineDatastoreVolumeOption
class VirtualMachineDatastoreVolumeOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileSystemType
  attr_accessor :majorVersion

  def initialize(dynamicType = nil, dynamicProperty = [], fileSystemType = nil, majorVersion = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileSystemType = fileSystemType
    @majorVersion = majorVersion
  end
end

# {urn:vim2}ArrayOfVirtualMachineDatastoreVolumeOption
class ArrayOfVirtualMachineDatastoreVolumeOption < ::Array
end

# {urn:vim2}DatastoreOption
class DatastoreOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :unsupportedVolumes

  def initialize(dynamicType = nil, dynamicProperty = [], unsupportedVolumes = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @unsupportedVolumes = unsupportedVolumes
  end
end

# {urn:vim2}VirtualMachineDefaultPowerOpInfo
class VirtualMachineDefaultPowerOpInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :powerOffType
  attr_accessor :suspendType
  attr_accessor :resetType
  attr_accessor :defaultPowerOffType
  attr_accessor :defaultSuspendType
  attr_accessor :defaultResetType
  attr_accessor :standbyAction

  def initialize(dynamicType = nil, dynamicProperty = [], powerOffType = nil, suspendType = nil, resetType = nil, defaultPowerOffType = nil, defaultSuspendType = nil, defaultResetType = nil, standbyAction = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @powerOffType = powerOffType
    @suspendType = suspendType
    @resetType = resetType
    @defaultPowerOffType = defaultPowerOffType
    @defaultSuspendType = defaultSuspendType
    @defaultResetType = defaultResetType
    @standbyAction = standbyAction
  end
end

# {urn:vim2}VirtualMachineDiskDeviceInfo
class VirtualMachineDiskDeviceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :capacity
  attr_accessor :vm

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], capacity = nil, vm = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @capacity = capacity
    @vm = vm
  end
end

# {urn:vim2}VirtualMachineFileInfo
class VirtualMachineFileInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vmPathName
  attr_accessor :snapshotDirectory
  attr_accessor :suspendDirectory
  attr_accessor :logDirectory

  def initialize(dynamicType = nil, dynamicProperty = [], vmPathName = nil, snapshotDirectory = nil, suspendDirectory = nil, logDirectory = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vmPathName = vmPathName
    @snapshotDirectory = snapshotDirectory
    @suspendDirectory = suspendDirectory
    @logDirectory = logDirectory
  end
end

# {urn:vim2}VirtualMachineFileLayoutDiskLayout
class VirtualMachineFileLayoutDiskLayout
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :diskFile

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, diskFile = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @diskFile = diskFile
  end
end

# {urn:vim2}ArrayOfVirtualMachineFileLayoutDiskLayout
class ArrayOfVirtualMachineFileLayoutDiskLayout < ::Array
end

# {urn:vim2}VirtualMachineFileLayoutSnapshotLayout
class VirtualMachineFileLayoutSnapshotLayout
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :snapshotFile

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, snapshotFile = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @snapshotFile = snapshotFile
  end
end

# {urn:vim2}ArrayOfVirtualMachineFileLayoutSnapshotLayout
class ArrayOfVirtualMachineFileLayoutSnapshotLayout < ::Array
end

# {urn:vim2}VirtualMachineFileLayout
class VirtualMachineFileLayout
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :configFile
  attr_accessor :logFile
  attr_accessor :disk
  attr_accessor :snapshot
  attr_accessor :swapFile

  def initialize(dynamicType = nil, dynamicProperty = [], configFile = [], logFile = [], disk = [], snapshot = [], swapFile = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @configFile = configFile
    @logFile = logFile
    @disk = disk
    @snapshot = snapshot
    @swapFile = swapFile
  end
end

# {urn:vim2}VirtualMachineFlagInfo
class VirtualMachineFlagInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :disableAcceleration
  attr_accessor :enableLogging
  attr_accessor :useToe
  attr_accessor :runWithDebugInfo
  attr_accessor :htSharing

  def initialize(dynamicType = nil, dynamicProperty = [], disableAcceleration = nil, enableLogging = nil, useToe = nil, runWithDebugInfo = nil, htSharing = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @disableAcceleration = disableAcceleration
    @enableLogging = enableLogging
    @useToe = useToe
    @runWithDebugInfo = runWithDebugInfo
    @htSharing = htSharing
  end
end

# {urn:vim2}VirtualMachineFloppyInfo
class VirtualMachineFloppyInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
  end
end

# {urn:vim2}ArrayOfVirtualMachineFloppyInfo
class ArrayOfVirtualMachineFloppyInfo < ::Array
end

# {urn:vim2}GuestDiskInfo
class GuestDiskInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskPath
  attr_accessor :capacity
  attr_accessor :freeSpace

  def initialize(dynamicType = nil, dynamicProperty = [], diskPath = nil, capacity = nil, freeSpace = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskPath = diskPath
    @capacity = capacity
    @freeSpace = freeSpace
  end
end

# {urn:vim2}ArrayOfGuestDiskInfo
class ArrayOfGuestDiskInfo < ::Array
end

# {urn:vim2}GuestNicInfo
class GuestNicInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :network
  attr_accessor :ipAddress
  attr_accessor :macAddress
  attr_accessor :connected
  attr_accessor :deviceConfigId

  def initialize(dynamicType = nil, dynamicProperty = [], network = nil, ipAddress = [], macAddress = nil, connected = nil, deviceConfigId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @network = network
    @ipAddress = ipAddress
    @macAddress = macAddress
    @connected = connected
    @deviceConfigId = deviceConfigId
  end
end

# {urn:vim2}ArrayOfGuestNicInfo
class ArrayOfGuestNicInfo < ::Array
end

# {urn:vim2}GuestScreenInfo
class GuestScreenInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :width
  attr_accessor :height

  def initialize(dynamicType = nil, dynamicProperty = [], width = nil, height = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @width = width
    @height = height
  end
end

# {urn:vim2}GuestInfo
class GuestInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :toolsStatus
  attr_accessor :toolsVersion
  attr_accessor :guestId
  attr_accessor :guestFamily
  attr_accessor :guestFullName
  attr_accessor :hostName
  attr_accessor :ipAddress
  attr_accessor :net
  attr_accessor :disk
  attr_accessor :screen
  attr_accessor :guestState

  def initialize(dynamicType = nil, dynamicProperty = [], toolsStatus = nil, toolsVersion = nil, guestId = nil, guestFamily = nil, guestFullName = nil, hostName = nil, ipAddress = nil, net = [], disk = [], screen = nil, guestState = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @toolsStatus = toolsStatus
    @toolsVersion = toolsVersion
    @guestId = guestId
    @guestFamily = guestFamily
    @guestFullName = guestFullName
    @hostName = hostName
    @ipAddress = ipAddress
    @net = net
    @disk = disk
    @screen = screen
    @guestState = guestState
  end
end

# {urn:vim2}GuestOsDescriptor
class GuestOsDescriptor
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :family
  attr_accessor :fullName
  attr_accessor :supportedMaxCPUs
  attr_accessor :supportedMinMemMB
  attr_accessor :supportedMaxMemMB
  attr_accessor :recommendedMemMB
  attr_accessor :recommendedColorDepth
  attr_accessor :supportedDiskControllerList
  attr_accessor :recommendedSCSIController
  attr_accessor :recommendedDiskController
  attr_accessor :supportedNumDisks
  attr_accessor :recommendedDiskSizeMB
  attr_accessor :supportedEthernetCard
  attr_accessor :recommendedEthernetCard
  attr_accessor :supportsSlaveDisk
  attr_accessor :cpuFeatureMask
  attr_accessor :supportsWakeOnLan

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, family = nil, fullName = nil, supportedMaxCPUs = nil, supportedMinMemMB = nil, supportedMaxMemMB = nil, recommendedMemMB = nil, recommendedColorDepth = nil, supportedDiskControllerList = [], recommendedSCSIController = nil, recommendedDiskController = nil, supportedNumDisks = nil, recommendedDiskSizeMB = nil, supportedEthernetCard = [], recommendedEthernetCard = nil, supportsSlaveDisk = nil, cpuFeatureMask = [], supportsWakeOnLan = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @family = family
    @fullName = fullName
    @supportedMaxCPUs = supportedMaxCPUs
    @supportedMinMemMB = supportedMinMemMB
    @supportedMaxMemMB = supportedMaxMemMB
    @recommendedMemMB = recommendedMemMB
    @recommendedColorDepth = recommendedColorDepth
    @supportedDiskControllerList = supportedDiskControllerList
    @recommendedSCSIController = recommendedSCSIController
    @recommendedDiskController = recommendedDiskController
    @supportedNumDisks = supportedNumDisks
    @recommendedDiskSizeMB = recommendedDiskSizeMB
    @supportedEthernetCard = supportedEthernetCard
    @recommendedEthernetCard = recommendedEthernetCard
    @supportsSlaveDisk = supportsSlaveDisk
    @cpuFeatureMask = cpuFeatureMask
    @supportsWakeOnLan = supportsWakeOnLan
  end
end

# {urn:vim2}ArrayOfGuestOsDescriptor
class ArrayOfGuestOsDescriptor < ::Array
end

# {urn:vim2}VirtualMachineIdeDiskDevicePartitionInfo
class VirtualMachineIdeDiskDevicePartitionInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :capacity

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, capacity = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @capacity = capacity
  end
end

# {urn:vim2}ArrayOfVirtualMachineIdeDiskDevicePartitionInfo
class ArrayOfVirtualMachineIdeDiskDevicePartitionInfo < ::Array
end

# {urn:vim2}VirtualMachineIdeDiskDeviceInfo
class VirtualMachineIdeDiskDeviceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :capacity
  attr_accessor :vm
  attr_accessor :partitionTable

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], capacity = nil, vm = [], partitionTable = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @capacity = capacity
    @vm = vm
    @partitionTable = partitionTable
  end
end

# {urn:vim2}ArrayOfVirtualMachineIdeDiskDeviceInfo
class ArrayOfVirtualMachineIdeDiskDeviceInfo < ::Array
end

# {urn:vim2}VirtualMachineLegacyNetworkSwitchInfo
class VirtualMachineLegacyNetworkSwitchInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}ArrayOfVirtualMachineLegacyNetworkSwitchInfo
class ArrayOfVirtualMachineLegacyNetworkSwitchInfo < ::Array
end

# {urn:vim2}VirtualMachineNetworkInfo
class VirtualMachineNetworkInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], network = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @network = network
  end
end

# {urn:vim2}ArrayOfVirtualMachineNetworkInfo
class ArrayOfVirtualMachineNetworkInfo < ::Array
end

# {urn:vim2}VirtualMachineNetworkShaperInfo
class VirtualMachineNetworkShaperInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :enabled
  attr_accessor :peakBps
  attr_accessor :averageBps
  attr_accessor :burstSize

  def initialize(dynamicType = nil, dynamicProperty = [], enabled = nil, peakBps = nil, averageBps = nil, burstSize = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @enabled = enabled
    @peakBps = peakBps
    @averageBps = averageBps
    @burstSize = burstSize
  end
end

# {urn:vim2}VirtualMachineParallelInfo
class VirtualMachineParallelInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
  end
end

# {urn:vim2}ArrayOfVirtualMachineParallelInfo
class ArrayOfVirtualMachineParallelInfo < ::Array
end

# {urn:vim2}VirtualMachineQuestionInfo
class VirtualMachineQuestionInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :id
  attr_accessor :text
  attr_accessor :choice

  def initialize(dynamicType = nil, dynamicProperty = [], id = nil, text = nil, choice = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @id = id
    @text = text
    @choice = choice
  end
end

# {urn:vim2}VirtualMachineRelocateSpecDiskLocator
class VirtualMachineRelocateSpecDiskLocator
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :diskId
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], diskId = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @diskId = diskId
    @datastore = datastore
  end
end

# {urn:vim2}ArrayOfVirtualMachineRelocateSpecDiskLocator
class ArrayOfVirtualMachineRelocateSpecDiskLocator < ::Array
end

# {urn:vim2}VirtualMachineRelocateSpec
class VirtualMachineRelocateSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :datastore
  attr_accessor :pool
  attr_accessor :host
  attr_accessor :disk
  attr_accessor :transform

  def initialize(dynamicType = nil, dynamicProperty = [], datastore = nil, pool = nil, host = nil, disk = [], transform = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @datastore = datastore
    @pool = pool
    @host = host
    @disk = disk
    @transform = transform
  end
end

# {urn:vim2}VirtualMachineRuntimeInfo
class VirtualMachineRuntimeInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :host
  attr_accessor :connectionState
  attr_accessor :powerState
  attr_accessor :toolsInstallerMounted
  attr_accessor :suspendTime
  attr_accessor :bootTime
  attr_accessor :suspendInterval
  attr_accessor :question
  attr_accessor :memoryOverhead
  attr_accessor :maxCpuUsage
  attr_accessor :maxMemoryUsage
  attr_accessor :numMksConnections

  def initialize(dynamicType = nil, dynamicProperty = [], host = nil, connectionState = nil, powerState = nil, toolsInstallerMounted = nil, suspendTime = nil, bootTime = nil, suspendInterval = nil, question = nil, memoryOverhead = nil, maxCpuUsage = nil, maxMemoryUsage = nil, numMksConnections = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @host = host
    @connectionState = connectionState
    @powerState = powerState
    @toolsInstallerMounted = toolsInstallerMounted
    @suspendTime = suspendTime
    @bootTime = bootTime
    @suspendInterval = suspendInterval
    @question = question
    @memoryOverhead = memoryOverhead
    @maxCpuUsage = maxCpuUsage
    @maxMemoryUsage = maxMemoryUsage
    @numMksConnections = numMksConnections
  end
end

# {urn:vim2}VirtualMachineScsiDiskDeviceInfo
class VirtualMachineScsiDiskDeviceInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :capacity
  attr_accessor :vm
  attr_accessor :disk

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], capacity = nil, vm = [], disk = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @capacity = capacity
    @vm = vm
    @disk = disk
  end
end

# {urn:vim2}ArrayOfVirtualMachineScsiDiskDeviceInfo
class ArrayOfVirtualMachineScsiDiskDeviceInfo < ::Array
end

# {urn:vim2}VirtualMachineScsiPassthroughInfo
class VirtualMachineScsiPassthroughInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag
  attr_accessor :scsiClass
  attr_accessor :vendor
  attr_accessor :physicalUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [], scsiClass = nil, vendor = nil, physicalUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
    @scsiClass = scsiClass
    @vendor = vendor
    @physicalUnitNumber = physicalUnitNumber
  end
end

# {urn:vim2}ArrayOfVirtualMachineScsiPassthroughInfo
class ArrayOfVirtualMachineScsiPassthroughInfo < ::Array
end

# {urn:vim2}VirtualMachineSerialInfo
class VirtualMachineSerialInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
  end
end

# {urn:vim2}ArrayOfVirtualMachineSerialInfo
class ArrayOfVirtualMachineSerialInfo < ::Array
end

# {urn:vim2}VirtualMachineSnapshotInfo
class VirtualMachineSnapshotInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :currentSnapshot
  attr_accessor :rootSnapshotList

  def initialize(dynamicType = nil, dynamicProperty = [], currentSnapshot = nil, rootSnapshotList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @currentSnapshot = currentSnapshot
    @rootSnapshotList = rootSnapshotList
  end
end

# {urn:vim2}VirtualMachineSnapshotTree
class VirtualMachineSnapshotTree
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :snapshot
  attr_accessor :vm
  attr_accessor :name
  attr_accessor :description
  attr_accessor :createTime
  attr_accessor :state
  attr_accessor :quiesced
  attr_accessor :childSnapshotList

  def initialize(dynamicType = nil, dynamicProperty = [], snapshot = nil, vm = nil, name = nil, description = nil, createTime = nil, state = nil, quiesced = nil, childSnapshotList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @snapshot = snapshot
    @vm = vm
    @name = name
    @description = description
    @createTime = createTime
    @state = state
    @quiesced = quiesced
    @childSnapshotList = childSnapshotList
  end
end

# {urn:vim2}ArrayOfVirtualMachineSnapshotTree
class ArrayOfVirtualMachineSnapshotTree < ::Array
end

# {urn:vim2}VirtualMachineConfigSummary
class VirtualMachineConfigSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :template
  attr_accessor :vmPathName
  attr_accessor :memorySizeMB
  attr_accessor :cpuReservation
  attr_accessor :memoryReservation
  attr_accessor :numCpu
  attr_accessor :numEthernetCards
  attr_accessor :numVirtualDisks
  attr_accessor :uuid
  attr_accessor :guestId
  attr_accessor :guestFullName
  attr_accessor :annotation

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, template = nil, vmPathName = nil, memorySizeMB = nil, cpuReservation = nil, memoryReservation = nil, numCpu = nil, numEthernetCards = nil, numVirtualDisks = nil, uuid = nil, guestId = nil, guestFullName = nil, annotation = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @template = template
    @vmPathName = vmPathName
    @memorySizeMB = memorySizeMB
    @cpuReservation = cpuReservation
    @memoryReservation = memoryReservation
    @numCpu = numCpu
    @numEthernetCards = numEthernetCards
    @numVirtualDisks = numVirtualDisks
    @uuid = uuid
    @guestId = guestId
    @guestFullName = guestFullName
    @annotation = annotation
  end
end

# {urn:vim2}VirtualMachineQuickStats
class VirtualMachineQuickStats
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :overallCpuUsage
  attr_accessor :guestMemoryUsage
  attr_accessor :hostMemoryUsage
  attr_accessor :guestHeartbeatStatus
  attr_accessor :distributedCpuEntitlement
  attr_accessor :distributedMemoryEntitlement

  def initialize(dynamicType = nil, dynamicProperty = [], overallCpuUsage = nil, guestMemoryUsage = nil, hostMemoryUsage = nil, guestHeartbeatStatus = nil, distributedCpuEntitlement = nil, distributedMemoryEntitlement = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @overallCpuUsage = overallCpuUsage
    @guestMemoryUsage = guestMemoryUsage
    @hostMemoryUsage = hostMemoryUsage
    @guestHeartbeatStatus = guestHeartbeatStatus
    @distributedCpuEntitlement = distributedCpuEntitlement
    @distributedMemoryEntitlement = distributedMemoryEntitlement
  end
end

# {urn:vim2}VirtualMachineGuestSummary
class VirtualMachineGuestSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :guestId
  attr_accessor :guestFullName
  attr_accessor :toolsStatus
  attr_accessor :hostName
  attr_accessor :ipAddress

  def initialize(dynamicType = nil, dynamicProperty = [], guestId = nil, guestFullName = nil, toolsStatus = nil, hostName = nil, ipAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @guestId = guestId
    @guestFullName = guestFullName
    @toolsStatus = toolsStatus
    @hostName = hostName
    @ipAddress = ipAddress
  end
end

# {urn:vim2}VirtualMachineSummary
class VirtualMachineSummary
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :vm
  attr_accessor :runtime
  attr_accessor :guest
  attr_accessor :config
  attr_accessor :quickStats
  attr_accessor :overallStatus
  attr_accessor :customValue

  def initialize(dynamicType = nil, dynamicProperty = [], vm = nil, runtime = nil, guest = nil, config = nil, quickStats = nil, overallStatus = nil, customValue = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @vm = vm
    @runtime = runtime
    @guest = guest
    @config = config
    @quickStats = quickStats
    @overallStatus = overallStatus
    @customValue = customValue
  end
end

# {urn:vim2}ArrayOfVirtualMachineSummary
class ArrayOfVirtualMachineSummary < ::Array
end

# {urn:vim2}VirtualMachineTargetInfo
class VirtualMachineTargetInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :configurationTag

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, configurationTag = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @configurationTag = configurationTag
  end
end

# {urn:vim2}ToolsConfigInfo
class ToolsConfigInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :toolsVersion
  attr_accessor :afterPowerOn
  attr_accessor :afterResume
  attr_accessor :beforeGuestStandby
  attr_accessor :beforeGuestShutdown
  attr_accessor :beforeGuestReboot

  def initialize(dynamicType = nil, dynamicProperty = [], toolsVersion = nil, afterPowerOn = nil, afterResume = nil, beforeGuestStandby = nil, beforeGuestShutdown = nil, beforeGuestReboot = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @toolsVersion = toolsVersion
    @afterPowerOn = afterPowerOn
    @afterResume = afterResume
    @beforeGuestStandby = beforeGuestStandby
    @beforeGuestShutdown = beforeGuestShutdown
    @beforeGuestReboot = beforeGuestReboot
  end
end

# {urn:vim2}VirtualHardware
class VirtualHardware
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :numCPU
  attr_accessor :memoryMB
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], numCPU = nil, memoryMB = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @numCPU = numCPU
    @memoryMB = memoryMB
    @device = device
  end
end

# {urn:vim2}VirtualHardwareOption
class VirtualHardwareOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :hwVersion
  attr_accessor :virtualDeviceOption
  attr_accessor :deviceListReadonly
  attr_accessor :numCPU
  attr_accessor :numCpuReadonly
  attr_accessor :memoryMB
  attr_accessor :numPCIControllers
  attr_accessor :numIDEControllers
  attr_accessor :numUSBControllers
  attr_accessor :numSIOControllers
  attr_accessor :numPS2Controllers
  attr_accessor :licensingLimit

  def initialize(dynamicType = nil, dynamicProperty = [], hwVersion = nil, virtualDeviceOption = [], deviceListReadonly = nil, numCPU = [], numCpuReadonly = nil, memoryMB = nil, numPCIControllers = nil, numIDEControllers = nil, numUSBControllers = nil, numSIOControllers = nil, numPS2Controllers = nil, licensingLimit = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @hwVersion = hwVersion
    @virtualDeviceOption = virtualDeviceOption
    @deviceListReadonly = deviceListReadonly
    @numCPU = numCPU
    @numCpuReadonly = numCpuReadonly
    @memoryMB = memoryMB
    @numPCIControllers = numPCIControllers
    @numIDEControllers = numIDEControllers
    @numUSBControllers = numUSBControllers
    @numSIOControllers = numSIOControllers
    @numPS2Controllers = numPS2Controllers
    @licensingLimit = licensingLimit
  end
end

# {urn:vim2}CustomizationSpec
class CustomizationSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :options
  attr_accessor :identity
  attr_accessor :globalIPSettings
  attr_accessor :nicSettingMap
  attr_accessor :encryptionKey

  def initialize(dynamicType = nil, dynamicProperty = [], options = nil, identity = nil, globalIPSettings = nil, nicSettingMap = [], encryptionKey = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @options = options
    @identity = identity
    @globalIPSettings = globalIPSettings
    @nicSettingMap = nicSettingMap
    @encryptionKey = encryptionKey
  end
end

# {urn:vim2}CustomizationName
class CustomizationName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationFixedName
class CustomizationFixedName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
  end
end

# {urn:vim2}CustomizationPrefixName
class CustomizationPrefixName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :base

  def initialize(dynamicType = nil, dynamicProperty = [], base = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @base = base
  end
end

# {urn:vim2}CustomizationVirtualMachineName
class CustomizationVirtualMachineName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationUnknownName
class CustomizationUnknownName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationCustomName
class CustomizationCustomName
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :argument

  def initialize(dynamicType = nil, dynamicProperty = [], argument = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @argument = argument
  end
end

# {urn:vim2}CustomizationPassword
class CustomizationPassword
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :value
  attr_accessor :plainText

  def initialize(dynamicType = nil, dynamicProperty = [], value = nil, plainText = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @value = value
    @plainText = plainText
  end
end

# {urn:vim2}CustomizationOptions
class CustomizationOptions
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationWinOptions
class CustomizationWinOptions
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :changeSID
  attr_accessor :deleteAccounts

  def initialize(dynamicType = nil, dynamicProperty = [], changeSID = nil, deleteAccounts = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @changeSID = changeSID
    @deleteAccounts = deleteAccounts
  end
end

# {urn:vim2}CustomizationLinuxOptions
class CustomizationLinuxOptions
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationGuiUnattended
class CustomizationGuiUnattended
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :password
  attr_accessor :timeZone
  attr_accessor :autoLogon
  attr_accessor :autoLogonCount

  def initialize(dynamicType = nil, dynamicProperty = [], password = nil, timeZone = nil, autoLogon = nil, autoLogonCount = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @password = password
    @timeZone = timeZone
    @autoLogon = autoLogon
    @autoLogonCount = autoLogonCount
  end
end

# {urn:vim2}CustomizationUserData
class CustomizationUserData
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fullName
  attr_accessor :orgName
  attr_accessor :computerName
  attr_accessor :productId

  def initialize(dynamicType = nil, dynamicProperty = [], fullName = nil, orgName = nil, computerName = nil, productId = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fullName = fullName
    @orgName = orgName
    @computerName = computerName
    @productId = productId
  end
end

# {urn:vim2}CustomizationGuiRunOnce
class CustomizationGuiRunOnce
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :commandList

  def initialize(dynamicType = nil, dynamicProperty = [], commandList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @commandList = commandList
  end
end

# {urn:vim2}CustomizationIdentification
class CustomizationIdentification
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :joinWorkgroup
  attr_accessor :joinDomain
  attr_accessor :domainAdmin
  attr_accessor :domainAdminPassword

  def initialize(dynamicType = nil, dynamicProperty = [], joinWorkgroup = nil, joinDomain = nil, domainAdmin = nil, domainAdminPassword = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @joinWorkgroup = joinWorkgroup
    @joinDomain = joinDomain
    @domainAdmin = domainAdmin
    @domainAdminPassword = domainAdminPassword
  end
end

# {urn:vim2}CustomizationLicenseFilePrintData
class CustomizationLicenseFilePrintData
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :autoMode
  attr_accessor :autoUsers

  def initialize(dynamicType = nil, dynamicProperty = [], autoMode = nil, autoUsers = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @autoMode = autoMode
    @autoUsers = autoUsers
  end
end

# {urn:vim2}CustomizationIdentitySettings
class CustomizationIdentitySettings
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationSysprepText
class CustomizationSysprepText
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :value

  def initialize(dynamicType = nil, dynamicProperty = [], value = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @value = value
  end
end

# {urn:vim2}CustomizationSysprep
class CustomizationSysprep
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :guiUnattended
  attr_accessor :userData
  attr_accessor :guiRunOnce
  attr_accessor :identification
  attr_accessor :licenseFilePrintData

  def initialize(dynamicType = nil, dynamicProperty = [], guiUnattended = nil, userData = nil, guiRunOnce = nil, identification = nil, licenseFilePrintData = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @guiUnattended = guiUnattended
    @userData = userData
    @guiRunOnce = guiRunOnce
    @identification = identification
    @licenseFilePrintData = licenseFilePrintData
  end
end

# {urn:vim2}CustomizationLinuxPrep
class CustomizationLinuxPrep
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :hostName
  attr_accessor :domain

  def initialize(dynamicType = nil, dynamicProperty = [], hostName = nil, domain = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @hostName = hostName
    @domain = domain
  end
end

# {urn:vim2}CustomizationGlobalIPSettings
class CustomizationGlobalIPSettings
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :dnsSuffixList
  attr_accessor :dnsServerList

  def initialize(dynamicType = nil, dynamicProperty = [], dnsSuffixList = [], dnsServerList = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @dnsSuffixList = dnsSuffixList
    @dnsServerList = dnsServerList
  end
end

# {urn:vim2}CustomizationIPSettings
class CustomizationIPSettings
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ip
  attr_accessor :subnetMask
  attr_accessor :gateway
  attr_accessor :dnsServerList
  attr_accessor :dnsDomain
  attr_accessor :primaryWINS
  attr_accessor :secondaryWINS
  attr_accessor :netBIOS

  def initialize(dynamicType = nil, dynamicProperty = [], ip = nil, subnetMask = nil, gateway = [], dnsServerList = [], dnsDomain = nil, primaryWINS = nil, secondaryWINS = nil, netBIOS = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ip = ip
    @subnetMask = subnetMask
    @gateway = gateway
    @dnsServerList = dnsServerList
    @dnsDomain = dnsDomain
    @primaryWINS = primaryWINS
    @secondaryWINS = secondaryWINS
    @netBIOS = netBIOS
  end
end

# {urn:vim2}CustomizationIpGenerator
class CustomizationIpGenerator
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationDhcpIpGenerator
class CustomizationDhcpIpGenerator
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationFixedIp
class CustomizationFixedIp
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :ipAddress

  def initialize(dynamicType = nil, dynamicProperty = [], ipAddress = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @ipAddress = ipAddress
  end
end

# {urn:vim2}CustomizationUnknownIpGenerator
class CustomizationUnknownIpGenerator
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}CustomizationCustomIpGenerator
class CustomizationCustomIpGenerator
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :argument

  def initialize(dynamicType = nil, dynamicProperty = [], argument = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @argument = argument
  end
end

# {urn:vim2}CustomizationAdapterMapping
class CustomizationAdapterMapping
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :macAddress
  attr_accessor :adapter

  def initialize(dynamicType = nil, dynamicProperty = [], macAddress = nil, adapter = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @macAddress = macAddress
    @adapter = adapter
  end
end

# {urn:vim2}ArrayOfCustomizationAdapterMapping
class ArrayOfCustomizationAdapterMapping < ::Array
end

# {urn:vim2}HostDiskMappingPartitionInfo
class HostDiskMappingPartitionInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :fileSystem
  attr_accessor :capacityInKb

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, fileSystem = nil, capacityInKb = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @fileSystem = fileSystem
    @capacityInKb = capacityInKb
  end
end

# {urn:vim2}HostDiskMappingInfo
class HostDiskMappingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :physicalPartition
  attr_accessor :name
  attr_accessor :exclusive

  def initialize(dynamicType = nil, dynamicProperty = [], physicalPartition = nil, name = nil, exclusive = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @physicalPartition = physicalPartition
    @name = name
    @exclusive = exclusive
  end
end

# {urn:vim2}HostDiskMappingPartitionOption
class HostDiskMappingPartitionOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :name
  attr_accessor :fileSystem
  attr_accessor :capacityInKb

  def initialize(dynamicType = nil, dynamicProperty = [], name = nil, fileSystem = nil, capacityInKb = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @name = name
    @fileSystem = fileSystem
    @capacityInKb = capacityInKb
  end
end

# {urn:vim2}ArrayOfHostDiskMappingPartitionOption
class ArrayOfHostDiskMappingPartitionOption < ::Array
end

# {urn:vim2}HostDiskMappingOption
class HostDiskMappingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :physicalPartition
  attr_accessor :name

  def initialize(dynamicType = nil, dynamicProperty = [], physicalPartition = [], name = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @physicalPartition = physicalPartition
    @name = name
  end
end

# {urn:vim2}VirtualBusLogicController
class VirtualBusLogicController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device
  attr_accessor :hotAddRemove
  attr_accessor :sharedBus
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [], hotAddRemove = nil, sharedBus = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
    @hotAddRemove = hotAddRemove
    @sharedBus = sharedBus
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualBusLogicControllerOption
class VirtualBusLogicControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numSCSIDisks
  attr_accessor :numSCSICdroms
  attr_accessor :numSCSIPassthrough
  attr_accessor :sharing
  attr_accessor :defaultSharedIndex
  attr_accessor :hotAddRemove
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numSCSIDisks = nil, numSCSICdroms = nil, numSCSIPassthrough = nil, sharing = [], defaultSharedIndex = nil, hotAddRemove = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numSCSIDisks = numSCSIDisks
    @numSCSICdroms = numSCSICdroms
    @numSCSIPassthrough = numSCSIPassthrough
    @sharing = sharing
    @defaultSharedIndex = defaultSharedIndex
    @hotAddRemove = hotAddRemove
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualCdromIsoBackingInfo
class VirtualCdromIsoBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
  end
end

# {urn:vim2}VirtualCdromPassthroughBackingInfo
class VirtualCdromPassthroughBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :exclusive

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, exclusive = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @exclusive = exclusive
  end
end

# {urn:vim2}VirtualCdromRemotePassthroughBackingInfo
class VirtualCdromRemotePassthroughBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :exclusive

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, exclusive = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @exclusive = exclusive
  end
end

# {urn:vim2}VirtualCdromAtapiBackingInfo
class VirtualCdromAtapiBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualCdromRemoteAtapiBackingInfo
class VirtualCdromRemoteAtapiBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualCdrom
class VirtualCdrom
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualCdromIsoBackingOption
class VirtualCdromIsoBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
  end
end

# {urn:vim2}VirtualCdromPassthroughBackingOption
class VirtualCdromPassthroughBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :exclusive

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, exclusive = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @exclusive = exclusive
  end
end

# {urn:vim2}VirtualCdromRemotePassthroughBackingOption
class VirtualCdromRemotePassthroughBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :exclusive

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, exclusive = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @exclusive = exclusive
  end
end

# {urn:vim2}VirtualCdromAtapiBackingOption
class VirtualCdromAtapiBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualCdromRemoteAtapiBackingOption
class VirtualCdromRemoteAtapiBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualCdromOption
class VirtualCdromOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualController
class VirtualController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
  end
end

# {urn:vim2}VirtualControllerOption
class VirtualControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
  end
end

# {urn:vim2}VirtualDeviceBackingInfo
class VirtualDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty

  def initialize(dynamicType = nil, dynamicProperty = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
  end
end

# {urn:vim2}VirtualDeviceFileBackingInfo
class VirtualDeviceFileBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
  end
end

# {urn:vim2}VirtualDeviceDeviceBackingInfo
class VirtualDeviceDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualDeviceRemoteDeviceBackingInfo
class VirtualDeviceRemoteDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualDevicePipeBackingInfo
class VirtualDevicePipeBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :pipeName

  def initialize(dynamicType = nil, dynamicProperty = [], pipeName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @pipeName = pipeName
  end
end

# {urn:vim2}VirtualDeviceConnectInfo
class VirtualDeviceConnectInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :startConnected
  attr_accessor :allowGuestControl
  attr_accessor :connected

  def initialize(dynamicType = nil, dynamicProperty = [], startConnected = nil, allowGuestControl = nil, connected = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @startConnected = startConnected
    @allowGuestControl = allowGuestControl
    @connected = connected
  end
end

# {urn:vim2}VirtualDevice
class VirtualDevice
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}ArrayOfVirtualDevice
class ArrayOfVirtualDevice < ::Array
end

# {urn:vim2}VirtualDeviceBackingOption
class VirtualDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}ArrayOfVirtualDeviceBackingOption
class ArrayOfVirtualDeviceBackingOption < ::Array
end

# {urn:vim2}VirtualDeviceFileBackingOption
class VirtualDeviceFileBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
  end
end

# {urn:vim2}VirtualDeviceDeviceBackingOption
class VirtualDeviceDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualDeviceRemoteDeviceBackingOption
class VirtualDeviceRemoteDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualDevicePipeBackingOption
class VirtualDevicePipeBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualDeviceConnectOption
class VirtualDeviceConnectOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :startConnected
  attr_accessor :allowGuestControl

  def initialize(dynamicType = nil, dynamicProperty = [], startConnected = nil, allowGuestControl = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @startConnected = startConnected
    @allowGuestControl = allowGuestControl
  end
end

# {urn:vim2}VirtualDeviceOption
class VirtualDeviceOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}ArrayOfVirtualDeviceOption
class ArrayOfVirtualDeviceOption < ::Array
end

# {urn:vim2}VirtualDeviceConfigSpec
class VirtualDeviceConfigSpec
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :operation
  attr_accessor :fileOperation
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], operation = nil, fileOperation = nil, device = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @operation = operation
    @fileOperation = fileOperation
    @device = device
  end
end

# {urn:vim2}ArrayOfVirtualDeviceConfigSpec
class ArrayOfVirtualDeviceConfigSpec < ::Array
end

# {urn:vim2}VirtualDiskSparseVer1BackingInfo
class VirtualDiskSparseVer1BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :spaceUsedInKB

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil, diskMode = nil, split = nil, writeThrough = nil, spaceUsedInKB = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @spaceUsedInKB = spaceUsedInKB
  end
end

# {urn:vim2}VirtualDiskSparseVer2BackingInfo
class VirtualDiskSparseVer2BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :spaceUsedInKB

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil, diskMode = nil, split = nil, writeThrough = nil, spaceUsedInKB = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @spaceUsedInKB = spaceUsedInKB
  end
end

# {urn:vim2}VirtualDiskFlatVer1BackingInfo
class VirtualDiskFlatVer1BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil, diskMode = nil, split = nil, writeThrough = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
  end
end

# {urn:vim2}VirtualDiskFlatVer2BackingInfo
class VirtualDiskFlatVer2BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :thinProvisioned

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil, diskMode = nil, split = nil, writeThrough = nil, thinProvisioned = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @thinProvisioned = thinProvisioned
  end
end

# {urn:vim2}VirtualDiskRawDiskVer2BackingInfo
class VirtualDiskRawDiskVer2BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :descriptorFileName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, descriptorFileName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @descriptorFileName = descriptorFileName
  end
end

# {urn:vim2}VirtualDiskPartitionedRawDiskVer2BackingInfo
class VirtualDiskPartitionedRawDiskVer2BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :descriptorFileName
  attr_accessor :partition

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, descriptorFileName = nil, partition = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @descriptorFileName = descriptorFileName
    @partition = partition
  end
end

# {urn:vim2}VirtualDiskRawDiskMappingVer1BackingInfo
class VirtualDiskRawDiskMappingVer1BackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore
  attr_accessor :lunUuid
  attr_accessor :deviceName
  attr_accessor :compatibilityMode
  attr_accessor :diskMode

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil, lunUuid = nil, deviceName = nil, compatibilityMode = nil, diskMode = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
    @lunUuid = lunUuid
    @deviceName = deviceName
    @compatibilityMode = compatibilityMode
    @diskMode = diskMode
  end
end

# {urn:vim2}VirtualDisk
class VirtualDisk
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :capacityInKB
  attr_accessor :shares

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, capacityInKB = nil, shares = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @capacityInKB = capacityInKB
    @shares = shares
  end
end

# {urn:vim2}VirtualDiskSparseVer1BackingOption
class VirtualDiskSparseVer1BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions
  attr_accessor :diskModes
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :growable

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil, diskModes = nil, split = nil, writeThrough = nil, growable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
    @diskModes = diskModes
    @split = split
    @writeThrough = writeThrough
    @growable = growable
  end
end

# {urn:vim2}VirtualDiskSparseVer2BackingOption
class VirtualDiskSparseVer2BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :growable

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil, diskMode = nil, split = nil, writeThrough = nil, growable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @growable = growable
  end
end

# {urn:vim2}VirtualDiskFlatVer1BackingOption
class VirtualDiskFlatVer1BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :growable

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil, diskMode = nil, split = nil, writeThrough = nil, growable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @growable = growable
  end
end

# {urn:vim2}VirtualDiskFlatVer2BackingOption
class VirtualDiskFlatVer2BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions
  attr_accessor :diskMode
  attr_accessor :split
  attr_accessor :writeThrough
  attr_accessor :growable

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil, diskMode = nil, split = nil, writeThrough = nil, growable = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
    @diskMode = diskMode
    @split = split
    @writeThrough = writeThrough
    @growable = growable
  end
end

# {urn:vim2}VirtualDiskRawDiskVer2BackingOption
class VirtualDiskRawDiskVer2BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :descriptorFileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, descriptorFileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @descriptorFileNameExtensions = descriptorFileNameExtensions
  end
end

# {urn:vim2}VirtualDiskPartitionedRawDiskVer2BackingOption
class VirtualDiskPartitionedRawDiskVer2BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :descriptorFileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, descriptorFileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @descriptorFileNameExtensions = descriptorFileNameExtensions
  end
end

# {urn:vim2}VirtualDiskRawDiskMappingVer1BackingOption
class VirtualDiskRawDiskMappingVer1BackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :descriptorFileNameExtensions
  attr_accessor :compatibilityMode
  attr_accessor :diskMode

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, descriptorFileNameExtensions = nil, compatibilityMode = nil, diskMode = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @descriptorFileNameExtensions = descriptorFileNameExtensions
    @compatibilityMode = compatibilityMode
    @diskMode = diskMode
  end
end

# {urn:vim2}VirtualDiskOption
class VirtualDiskOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :capacityInKB

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, capacityInKB = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @capacityInKB = capacityInKB
  end
end

# {urn:vim2}VirtualE1000
class VirtualE1000
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :addressType
  attr_accessor :macAddress
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, addressType = nil, macAddress = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @addressType = addressType
    @macAddress = macAddress
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualE1000Option
class VirtualE1000Option
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :supportedOUI
  attr_accessor :macType
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, supportedOUI = nil, macType = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @supportedOUI = supportedOUI
    @macType = macType
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualEnsoniq1371
class VirtualEnsoniq1371
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualEnsoniq1371Option
class VirtualEnsoniq1371Option
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualEthernetCardNetworkBackingInfo
class VirtualEthernetCardNetworkBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :network

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, network = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @network = network
  end
end

# {urn:vim2}VirtualEthernetCardLegacyNetworkBackingInfo
class VirtualEthernetCardLegacyNetworkBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualEthernetCard
class VirtualEthernetCard
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :addressType
  attr_accessor :macAddress
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, addressType = nil, macAddress = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @addressType = addressType
    @macAddress = macAddress
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualEthernetCardNetworkBackingOption
class VirtualEthernetCardNetworkBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualEthernetCardLegacyNetworkBackingOption
class VirtualEthernetCardLegacyNetworkBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualEthernetCardOption
class VirtualEthernetCardOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :supportedOUI
  attr_accessor :macType
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, supportedOUI = nil, macType = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @supportedOUI = supportedOUI
    @macType = macType
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualFloppyImageBackingInfo
class VirtualFloppyImageBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
  end
end

# {urn:vim2}VirtualFloppyDeviceBackingInfo
class VirtualFloppyDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualFloppyRemoteDeviceBackingInfo
class VirtualFloppyRemoteDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualFloppy
class VirtualFloppy
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualFloppyImageBackingOption
class VirtualFloppyImageBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
  end
end

# {urn:vim2}VirtualFloppyDeviceBackingOption
class VirtualFloppyDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualFloppyRemoteDeviceBackingOption
class VirtualFloppyRemoteDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualFloppyOption
class VirtualFloppyOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualIDEController
class VirtualIDEController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
  end
end

# {urn:vim2}VirtualIDEControllerOption
class VirtualIDEControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numIDEDisks
  attr_accessor :numIDECdroms

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numIDEDisks = nil, numIDECdroms = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numIDEDisks = numIDEDisks
    @numIDECdroms = numIDECdroms
  end
end

# {urn:vim2}VirtualKeyboard
class VirtualKeyboard
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualKeyboardOption
class VirtualKeyboardOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualLsiLogicController
class VirtualLsiLogicController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device
  attr_accessor :hotAddRemove
  attr_accessor :sharedBus
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [], hotAddRemove = nil, sharedBus = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
    @hotAddRemove = hotAddRemove
    @sharedBus = sharedBus
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualLsiLogicControllerOption
class VirtualLsiLogicControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numSCSIDisks
  attr_accessor :numSCSICdroms
  attr_accessor :numSCSIPassthrough
  attr_accessor :sharing
  attr_accessor :defaultSharedIndex
  attr_accessor :hotAddRemove
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numSCSIDisks = nil, numSCSICdroms = nil, numSCSIPassthrough = nil, sharing = [], defaultSharedIndex = nil, hotAddRemove = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numSCSIDisks = numSCSIDisks
    @numSCSICdroms = numSCSICdroms
    @numSCSIPassthrough = numSCSIPassthrough
    @sharing = sharing
    @defaultSharedIndex = defaultSharedIndex
    @hotAddRemove = hotAddRemove
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualPCIController
class VirtualPCIController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
  end
end

# {urn:vim2}VirtualPCIControllerOption
class VirtualPCIControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numSCSIControllers
  attr_accessor :numEthernetCards
  attr_accessor :numVideoCards
  attr_accessor :numSoundCards

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numSCSIControllers = nil, numEthernetCards = nil, numVideoCards = nil, numSoundCards = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numSCSIControllers = numSCSIControllers
    @numEthernetCards = numEthernetCards
    @numVideoCards = numVideoCards
    @numSoundCards = numSoundCards
  end
end

# {urn:vim2}VirtualPCNet32
class VirtualPCNet32
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :addressType
  attr_accessor :macAddress
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, addressType = nil, macAddress = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @addressType = addressType
    @macAddress = macAddress
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualPCNet32Option
class VirtualPCNet32Option
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :supportedOUI
  attr_accessor :macType
  attr_accessor :wakeOnLanEnabled
  attr_accessor :supportsMorphing

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, supportedOUI = nil, macType = nil, wakeOnLanEnabled = nil, supportsMorphing = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @supportedOUI = supportedOUI
    @macType = macType
    @wakeOnLanEnabled = wakeOnLanEnabled
    @supportsMorphing = supportsMorphing
  end
end

# {urn:vim2}VirtualPS2Controller
class VirtualPS2Controller
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
  end
end

# {urn:vim2}VirtualPS2ControllerOption
class VirtualPS2ControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numKeyboards
  attr_accessor :numPointingDevices

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numKeyboards = nil, numPointingDevices = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numKeyboards = numKeyboards
    @numPointingDevices = numPointingDevices
  end
end

# {urn:vim2}VirtualParallelPortFileBackingInfo
class VirtualParallelPortFileBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
  end
end

# {urn:vim2}VirtualParallelPortDeviceBackingInfo
class VirtualParallelPortDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualParallelPort
class VirtualParallelPort
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualParallelPortFileBackingOption
class VirtualParallelPortFileBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
  end
end

# {urn:vim2}VirtualParallelPortDeviceBackingOption
class VirtualParallelPortDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualParallelPortOption
class VirtualParallelPortOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualPointingDeviceDeviceBackingInfo
class VirtualPointingDeviceDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName
  attr_accessor :hostPointingDevice

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil, hostPointingDevice = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
    @hostPointingDevice = hostPointingDevice
  end
end

# {urn:vim2}VirtualPointingDevice
class VirtualPointingDevice
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualPointingDeviceBackingOption
class VirtualPointingDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :hostPointingDevice

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, hostPointingDevice = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @hostPointingDevice = hostPointingDevice
  end
end

# {urn:vim2}VirtualPointingDeviceOption
class VirtualPointingDeviceOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}ArrayOfVirtualSCSISharing
class ArrayOfVirtualSCSISharing < ::Array
end

# {urn:vim2}VirtualSCSIController
class VirtualSCSIController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device
  attr_accessor :hotAddRemove
  attr_accessor :sharedBus
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [], hotAddRemove = nil, sharedBus = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
    @hotAddRemove = hotAddRemove
    @sharedBus = sharedBus
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualSCSIControllerOption
class VirtualSCSIControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numSCSIDisks
  attr_accessor :numSCSICdroms
  attr_accessor :numSCSIPassthrough
  attr_accessor :sharing
  attr_accessor :defaultSharedIndex
  attr_accessor :hotAddRemove
  attr_accessor :scsiCtlrUnitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numSCSIDisks = nil, numSCSICdroms = nil, numSCSIPassthrough = nil, sharing = [], defaultSharedIndex = nil, hotAddRemove = nil, scsiCtlrUnitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numSCSIDisks = numSCSIDisks
    @numSCSICdroms = numSCSICdroms
    @numSCSIPassthrough = numSCSIPassthrough
    @sharing = sharing
    @defaultSharedIndex = defaultSharedIndex
    @hotAddRemove = hotAddRemove
    @scsiCtlrUnitNumber = scsiCtlrUnitNumber
  end
end

# {urn:vim2}VirtualSCSIPassthroughDeviceBackingInfo
class VirtualSCSIPassthroughDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualSCSIPassthrough
class VirtualSCSIPassthrough
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualSCSIPassthroughDeviceBackingOption
class VirtualSCSIPassthroughDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualSCSIPassthroughOption
class VirtualSCSIPassthroughOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualSIOController
class VirtualSIOController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [])
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
  end
end

# {urn:vim2}VirtualSIOControllerOption
class VirtualSIOControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :numFloppyDrives
  attr_accessor :numSerialPorts
  attr_accessor :numParallelPorts

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], numFloppyDrives = nil, numSerialPorts = nil, numParallelPorts = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @numFloppyDrives = numFloppyDrives
    @numSerialPorts = numSerialPorts
    @numParallelPorts = numParallelPorts
  end
end

# {urn:vim2}VirtualSerialPortFileBackingInfo
class VirtualSerialPortFileBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :fileName
  attr_accessor :datastore

  def initialize(dynamicType = nil, dynamicProperty = [], fileName = nil, datastore = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @fileName = fileName
    @datastore = datastore
  end
end

# {urn:vim2}VirtualSerialPortDeviceBackingInfo
class VirtualSerialPortDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualSerialPortPipeBackingInfo
class VirtualSerialPortPipeBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :pipeName
  attr_accessor :endpoint
  attr_accessor :noRxLoss

  def initialize(dynamicType = nil, dynamicProperty = [], pipeName = nil, endpoint = nil, noRxLoss = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @pipeName = pipeName
    @endpoint = endpoint
    @noRxLoss = noRxLoss
  end
end

# {urn:vim2}VirtualSerialPort
class VirtualSerialPort
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :yieldOnPoll

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, yieldOnPoll = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @yieldOnPoll = yieldOnPoll
  end
end

# {urn:vim2}VirtualSerialPortFileBackingOption
class VirtualSerialPortFileBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :fileNameExtensions

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, fileNameExtensions = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @fileNameExtensions = fileNameExtensions
  end
end

# {urn:vim2}VirtualSerialPortDeviceBackingOption
class VirtualSerialPortDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualSerialPortPipeBackingOption
class VirtualSerialPortPipeBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :endpoint
  attr_accessor :noRxLoss

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, endpoint = nil, noRxLoss = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @endpoint = endpoint
    @noRxLoss = noRxLoss
  end
end

# {urn:vim2}VirtualSerialPortOption
class VirtualSerialPortOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :yieldOnPoll

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, yieldOnPoll = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @yieldOnPoll = yieldOnPoll
  end
end

# {urn:vim2}VirtualSoundBlaster16
class VirtualSoundBlaster16
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualSoundBlaster16Option
class VirtualSoundBlaster16Option
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualSoundCardDeviceBackingInfo
class VirtualSoundCardDeviceBackingInfo
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :deviceName

  def initialize(dynamicType = nil, dynamicProperty = [], deviceName = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @deviceName = deviceName
  end
end

# {urn:vim2}VirtualSoundCard
class VirtualSoundCard
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualSoundCardDeviceBackingOption
class VirtualSoundCardDeviceBackingOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
  end
end

# {urn:vim2}VirtualSoundCardOption
class VirtualSoundCardOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualUSB
class VirtualUSB
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
  end
end

# {urn:vim2}VirtualUSBController
class VirtualUSBController
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :busNumber
  attr_accessor :device
  attr_accessor :autoConnectDevices

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, busNumber = nil, device = [], autoConnectDevices = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @busNumber = busNumber
    @device = device
    @autoConnectDevices = autoConnectDevices
  end
end

# {urn:vim2}VirtualUSBControllerOption
class VirtualUSBControllerOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :devices
  attr_accessor :supportedDevice
  attr_accessor :autoConnectDevices

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, devices = nil, supportedDevice = [], autoConnectDevices = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @devices = devices
    @supportedDevice = supportedDevice
    @autoConnectDevices = autoConnectDevices
  end
end

# {urn:vim2}VirtualUSBOption
class VirtualUSBOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
  end
end

# {urn:vim2}VirtualMachineVideoCard
class VirtualMachineVideoCard
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :videoRamSizeInKB

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, videoRamSizeInKB = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @videoRamSizeInKB = videoRamSizeInKB
  end
end

# {urn:vim2}VirtualVideoCardOption
class VirtualVideoCardOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :videoRamSizeInKB

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, videoRamSizeInKB = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @videoRamSizeInKB = videoRamSizeInKB
  end
end

# {urn:vim2}VirtualVmxnet
class VirtualVmxnet
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :key
  attr_accessor :deviceInfo
  attr_accessor :backing
  attr_accessor :connectable
  attr_accessor :controllerKey
  attr_accessor :unitNumber
  attr_accessor :addressType
  attr_accessor :macAddress
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], key = nil, deviceInfo = nil, backing = nil, connectable = nil, controllerKey = nil, unitNumber = nil, addressType = nil, macAddress = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @key = key
    @deviceInfo = deviceInfo
    @backing = backing
    @connectable = connectable
    @controllerKey = controllerKey
    @unitNumber = unitNumber
    @addressType = addressType
    @macAddress = macAddress
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}VirtualVmxnetOption
class VirtualVmxnetOption
  attr_accessor :dynamicType
  attr_accessor :dynamicProperty
  attr_accessor :type
  attr_accessor :connectOption
  attr_accessor :controllerType
  attr_accessor :autoAssignController
  attr_accessor :backingOption
  attr_accessor :defaultBackingOptionIndex
  attr_accessor :licensingLimit
  attr_accessor :deprecated
  attr_accessor :plugAndPlay
  attr_accessor :supportedOUI
  attr_accessor :macType
  attr_accessor :wakeOnLanEnabled

  def initialize(dynamicType = nil, dynamicProperty = [], type = nil, connectOption = nil, controllerType = nil, autoAssignController = nil, backingOption = [], defaultBackingOptionIndex = nil, licensingLimit = [], deprecated = nil, plugAndPlay = nil, supportedOUI = nil, macType = nil, wakeOnLanEnabled = nil)
    @dynamicType = dynamicType
    @dynamicProperty = dynamicProperty
    @type = type
    @connectOption = connectOption
    @controllerType = controllerType
    @autoAssignController = autoAssignController
    @backingOption = backingOption
    @defaultBackingOptionIndex = defaultBackingOptionIndex
    @licensingLimit = licensingLimit
    @deprecated = deprecated
    @plugAndPlay = plugAndPlay
    @supportedOUI = supportedOUI
    @macType = macType
    @wakeOnLanEnabled = wakeOnLanEnabled
  end
end

# {urn:vim2}ManagedObjectReference
class ManagedObjectReference < ::String
  def xmlattr_type
    (@__xmlattr ||= {})[XSD::QName.new(nil, "type")]
  end

  def xmlattr_type=(value)
    (@__xmlattr ||= {})[XSD::QName.new(nil, "type")] = value
  end

  def initialize(*arg)
    super
    @__xmlattr = {}
  end
end

# {urn:vim2}ArrayOfString
class ArrayOfString < ::Array
end

# {urn:vim2}ArrayOfAnyType
class ArrayOfAnyType < ::Array
end

# {urn:vim2}ArrayOfManagedObjectReference
class ArrayOfManagedObjectReference < ::Array
end

# {urn:vim2}ArrayOfInt
class ArrayOfInt < ::Array
end

# {urn:vim2}ArrayOfByte
class ArrayOfByte < ::Array
end

# {urn:vim2}ArrayOfShort
class ArrayOfShort < ::Array
end

# {urn:vim2}ArrayOfLong
class ArrayOfLong < ::Array
end

# {urn:vim2}ObjectUpdateKind
class ObjectUpdateKind < ::String
  Enter = ObjectUpdateKind.new("enter")
  Leave = ObjectUpdateKind.new("leave")
  Modify = ObjectUpdateKind.new("modify")
end

# {urn:vim2}PropertyChangeOp
class PropertyChangeOp < ::String
  Add = PropertyChangeOp.new("add")
  Assign = PropertyChangeOp.new("assign")
  IndirectRemove = PropertyChangeOp.new("indirectRemove")
  Remove = PropertyChangeOp.new("remove")
end

# {urn:vim2}DiagnosticManagerLogCreator
class DiagnosticManagerLogCreator < ::String
  Hostd = DiagnosticManagerLogCreator.new("hostd")
  Install = DiagnosticManagerLogCreator.new("install")
  Serverd = DiagnosticManagerLogCreator.new("serverd")
  VpxClient = DiagnosticManagerLogCreator.new("vpxClient")
  Vpxa = DiagnosticManagerLogCreator.new("vpxa")
  Vpxd = DiagnosticManagerLogCreator.new("vpxd")
end

# {urn:vim2}DiagnosticManagerLogFormat
class DiagnosticManagerLogFormat < ::String
  Plain = DiagnosticManagerLogFormat.new("plain")
end

# {urn:vim2}HostSystemConnectionState
class HostSystemConnectionState < ::String
  Connected = HostSystemConnectionState.new("connected")
  Disconnected = HostSystemConnectionState.new("disconnected")
  NotResponding = HostSystemConnectionState.new("notResponding")
end

# {urn:vim2}LicenseManagerLicenseKey
class LicenseManagerLicenseKey < ::String
  Backup = LicenseManagerLicenseKey.new("backup")
  Das = LicenseManagerLicenseKey.new("das")
  Drs = LicenseManagerLicenseKey.new("drs")
  EsxExpress = LicenseManagerLicenseKey.new("esxExpress")
  EsxFull = LicenseManagerLicenseKey.new("esxFull")
  EsxHost = LicenseManagerLicenseKey.new("esxHost")
  EsxVmtn = LicenseManagerLicenseKey.new("esxVmtn")
  GsxHost = LicenseManagerLicenseKey.new("gsxHost")
  Iscsi = LicenseManagerLicenseKey.new("iscsi")
  Nas = LicenseManagerLicenseKey.new("nas")
  San = LicenseManagerLicenseKey.new("san")
  Vc = LicenseManagerLicenseKey.new("vc")
  Vmotion = LicenseManagerLicenseKey.new("vmotion")
  Vsmp = LicenseManagerLicenseKey.new("vsmp")
end

# {urn:vim2}LicenseFeatureInfoUnit
class LicenseFeatureInfoUnit < ::String
  CpuCore = LicenseFeatureInfoUnit.new("cpuCore")
  CpuPackage = LicenseFeatureInfoUnit.new("cpuPackage")
  Host = LicenseFeatureInfoUnit.new("host")
  Server = LicenseFeatureInfoUnit.new("server")
  Vm = LicenseFeatureInfoUnit.new("vm")
end

# {urn:vim2}LicenseFeatureInfoState
class LicenseFeatureInfoState < ::String
  Disabled = LicenseFeatureInfoState.new("disabled")
  Enabled = LicenseFeatureInfoState.new("enabled")
  Optional = LicenseFeatureInfoState.new("optional")
end

# {urn:vim2}LicenseReservationInfoState
class LicenseReservationInfoState < ::String
  Licensed = LicenseReservationInfoState.new("licensed")
  NoLicense = LicenseReservationInfoState.new("noLicense")
  NotUsed = LicenseReservationInfoState.new("notUsed")
  UnlicensedUse = LicenseReservationInfoState.new("unlicensedUse")
end

# {urn:vim2}ManagedEntityStatus
class ManagedEntityStatus < ::String
  Gray = ManagedEntityStatus.new("gray")
  Green = ManagedEntityStatus.new("green")
  Red = ManagedEntityStatus.new("red")
  Yellow = ManagedEntityStatus.new("yellow")
end

# {urn:vim2}PerfFormat
class PerfFormat < ::String
  Csv = PerfFormat.new("csv")
  Normal = PerfFormat.new("normal")
end

# {urn:vim2}PerfSummaryType
class PerfSummaryType < ::String
  Average = PerfSummaryType.new("average")
  Latest = PerfSummaryType.new("latest")
  Maximum = PerfSummaryType.new("maximum")
  Minimum = PerfSummaryType.new("minimum")
  None = PerfSummaryType.new("none")
  Summation = PerfSummaryType.new("summation")
end

# {urn:vim2}PerfStatsType
class PerfStatsType < ::String
  Absolute = PerfStatsType.new("absolute")
  Delta = PerfStatsType.new("delta")
  Rate = PerfStatsType.new("rate")
end

# {urn:vim2}PerformanceManagerUnit
class PerformanceManagerUnit < ::String
  KiloBytes = PerformanceManagerUnit.new("kiloBytes")
  KiloBytesPerSecond = PerformanceManagerUnit.new("kiloBytesPerSecond")
  MegaBytes = PerformanceManagerUnit.new("megaBytes")
  MegaBytesPerSecond = PerformanceManagerUnit.new("megaBytesPerSecond")
  MegaHertz = PerformanceManagerUnit.new("megaHertz")
  Millisecond = PerformanceManagerUnit.new("millisecond")
  Number = PerformanceManagerUnit.new("number")
  Percent = PerformanceManagerUnit.new("percent")
  Second = PerformanceManagerUnit.new("second")
end

# {urn:vim2}ValidateMigrationTestType
class ValidateMigrationTestType < ::String
  CompatibilityTests = ValidateMigrationTestType.new("compatibilityTests")
  DiskAccessibilityTests = ValidateMigrationTestType.new("diskAccessibilityTests")
  ResourceTests = ValidateMigrationTestType.new("resourceTests")
  SourceTests = ValidateMigrationTestType.new("sourceTests")
end

# {urn:vim2}VMotionCompatibilityType
class VMotionCompatibilityType < ::String
  Cpu = VMotionCompatibilityType.new("cpu")
  Software = VMotionCompatibilityType.new("software")
end

# {urn:vim2}SharesLevel
class SharesLevel < ::String
  Custom = SharesLevel.new("custom")
  High = SharesLevel.new("high")
  Low = SharesLevel.new("low")
  Normal = SharesLevel.new("normal")
end

# {urn:vim2}TaskFilterSpecRecursionOption
class TaskFilterSpecRecursionOption < ::String
  All = TaskFilterSpecRecursionOption.new("all")
  Children = TaskFilterSpecRecursionOption.new("children")
  Self = TaskFilterSpecRecursionOption.new("self")
end

# {urn:vim2}TaskFilterSpecTimeOption
class TaskFilterSpecTimeOption < ::String
  CompletedTime = TaskFilterSpecTimeOption.new("completedTime")
  QueuedTime = TaskFilterSpecTimeOption.new("queuedTime")
  StartedTime = TaskFilterSpecTimeOption.new("startedTime")
end

# {urn:vim2}TaskInfoState
class TaskInfoState < ::String
  Error = TaskInfoState.new("error")
  Queued = TaskInfoState.new("queued")
  Running = TaskInfoState.new("running")
  Success = TaskInfoState.new("success")
end

# {urn:vim2}VirtualMachinePowerState
class VirtualMachinePowerState < ::String
  PoweredOff = VirtualMachinePowerState.new("poweredOff")
  PoweredOn = VirtualMachinePowerState.new("poweredOn")
  Suspended = VirtualMachinePowerState.new("suspended")
end

# {urn:vim2}VirtualMachineConnectionState
class VirtualMachineConnectionState < ::String
  Connected = VirtualMachineConnectionState.new("connected")
  Disconnected = VirtualMachineConnectionState.new("disconnected")
  Inaccessible = VirtualMachineConnectionState.new("inaccessible")
  Invalid = VirtualMachineConnectionState.new("invalid")
  Orphaned = VirtualMachineConnectionState.new("orphaned")
end

# {urn:vim2}VirtualMachineMovePriority
class VirtualMachineMovePriority < ::String
  DefaultPriority = VirtualMachineMovePriority.new("defaultPriority")
  HighPriority = VirtualMachineMovePriority.new("highPriority")
  LowPriority = VirtualMachineMovePriority.new("lowPriority")
end

# {urn:vim2}ActionParameter
class ActionParameter < ::String
  Alarm = ActionParameter.new("alarm")
  AlarmName = ActionParameter.new("alarmName")
  DeclaringSummary = ActionParameter.new("declaringSummary")
  EventDescription = ActionParameter.new("eventDescription")
  NewStatus = ActionParameter.new("newStatus")
  OldStatus = ActionParameter.new("oldStatus")
  Target = ActionParameter.new("target")
  TargetName = ActionParameter.new("targetName")
  TriggeringSummary = ActionParameter.new("triggeringSummary")
end

# {urn:vim2}StateAlarmOperator
class StateAlarmOperator < ::String
  IsEqual = StateAlarmOperator.new("isEqual")
  IsUnequal = StateAlarmOperator.new("isUnequal")
end

# {urn:vim2}MetricAlarmOperator
class MetricAlarmOperator < ::String
  IsAbove = MetricAlarmOperator.new("isAbove")
  IsBelow = MetricAlarmOperator.new("isBelow")
end

# {urn:vim2}DrsBehavior
class DrsBehavior < ::String
  FullyAutomated = DrsBehavior.new("fullyAutomated")
  Manual = DrsBehavior.new("manual")
  PartiallyAutomated = DrsBehavior.new("partiallyAutomated")
end

# {urn:vim2}DasVmPriority
class DasVmPriority < ::String
  Disabled = DasVmPriority.new("disabled")
  High = DasVmPriority.new("high")
  Low = DasVmPriority.new("low")
  Medium = DasVmPriority.new("medium")
end

# {urn:vim2}DrsRecommendationReasonCode
class DrsRecommendationReasonCode < ::String
  AntiAffin = DrsRecommendationReasonCode.new("antiAffin")
  FairnessCpuAvg = DrsRecommendationReasonCode.new("fairnessCpuAvg")
  FairnessMemAvg = DrsRecommendationReasonCode.new("fairnessMemAvg")
  HostMaint = DrsRecommendationReasonCode.new("hostMaint")
  JointAffin = DrsRecommendationReasonCode.new("jointAffin")
end

# {urn:vim2}EventCategory
class EventCategory < ::String
  Error = EventCategory.new("error")
  Info = EventCategory.new("info")
  User = EventCategory.new("user")
  Warning = EventCategory.new("warning")
end

# {urn:vim2}EventFilterSpecRecursionOption
class EventFilterSpecRecursionOption < ::String
  All = EventFilterSpecRecursionOption.new("all")
  Children = EventFilterSpecRecursionOption.new("children")
  Self = EventFilterSpecRecursionOption.new("self")
end

# {urn:vim2}AffinityType
class AffinityType < ::String
  Cpu = AffinityType.new("cpu")
  Memory = AffinityType.new("memory")
end

# {urn:vim2}AutoStartAction
class AutoStartAction < ::String
  GuestShutdown = AutoStartAction.new("guestShutdown")
  None = AutoStartAction.new("none")
  PowerOff = AutoStartAction.new("powerOff")
  PowerOn = AutoStartAction.new("powerOn")
  Suspend = AutoStartAction.new("suspend")
  SystemDefault = AutoStartAction.new("systemDefault")
end

# {urn:vim2}AutoStartWaitHeartbeatSetting
class AutoStartWaitHeartbeatSetting < ::String
  No = AutoStartWaitHeartbeatSetting.new("no")
  SystemDefault = AutoStartWaitHeartbeatSetting.new("systemDefault")
  Yes = AutoStartWaitHeartbeatSetting.new("yes")
end

# {urn:vim2}HostConfigChangeMode
class HostConfigChangeMode < ::String
  Modify = HostConfigChangeMode.new("modify")
  Replace = HostConfigChangeMode.new("replace")
end

# {urn:vim2}HostConfigChangeOperation
class HostConfigChangeOperation < ::String
  Add = HostConfigChangeOperation.new("add")
  Edit = HostConfigChangeOperation.new("edit")
  Remove = HostConfigChangeOperation.new("remove")
end

# {urn:vim2}DiagnosticPartitionStorageType
class DiagnosticPartitionStorageType < ::String
  DirectAttached = DiagnosticPartitionStorageType.new("directAttached")
  NetworkAttached = DiagnosticPartitionStorageType.new("networkAttached")
end

# {urn:vim2}DiagnosticPartitionType
class DiagnosticPartitionType < ::String
  MultiHost = DiagnosticPartitionType.new("multiHost")
  SingleHost = DiagnosticPartitionType.new("singleHost")
end

# {urn:vim2}HostDiskPartitionInfoType
class HostDiskPartitionInfoType < ::String
  Extended = HostDiskPartitionInfoType.new("extended")
  LinuxNative = HostDiskPartitionInfoType.new("linuxNative")
  LinuxSwap = HostDiskPartitionInfoType.new("linuxSwap")
  None = HostDiskPartitionInfoType.new("none")
  Ntfs = HostDiskPartitionInfoType.new("ntfs")
  Vmfs = HostDiskPartitionInfoType.new("vmfs")
  VmkDiagnostic = HostDiskPartitionInfoType.new("vmkDiagnostic")
end

# {urn:vim2}HostCpuPackageVendor
class HostCpuPackageVendor < ::String
  Amd = HostCpuPackageVendor.new("amd")
  Intel = HostCpuPackageVendor.new("intel")
  Unknown = HostCpuPackageVendor.new("unknown")
end

# {urn:vim2}FibreChannelPortType
class FibreChannelPortType < ::String
  Fabric = FibreChannelPortType.new("fabric")
  Loop = FibreChannelPortType.new("loop")
  PointToPoint = FibreChannelPortType.new("pointToPoint")
  Unknown = FibreChannelPortType.new("unknown")
end

# {urn:vim2}InternetScsiSnsDiscoveryMethod
class InternetScsiSnsDiscoveryMethod < ::String
  IsnsDhcp = InternetScsiSnsDiscoveryMethod.new("isnsDhcp")
  IsnsSlp = InternetScsiSnsDiscoveryMethod.new("isnsSlp")
  IsnsStatic = InternetScsiSnsDiscoveryMethod.new("isnsStatic")
end

# {urn:vim2}SlpDiscoveryMethod
class SlpDiscoveryMethod < ::String
  SlpAutoMulticast = SlpDiscoveryMethod.new("slpAutoMulticast")
  SlpAutoUnicast = SlpDiscoveryMethod.new("slpAutoUnicast")
  SlpDhcp = SlpDiscoveryMethod.new("slpDhcp")
  SlpManual = SlpDiscoveryMethod.new("slpManual")
end

# {urn:vim2}HostMountMode
class HostMountMode < ::String
  ReadOnly = HostMountMode.new("readOnly")
  ReadWrite = HostMountMode.new("readWrite")
end

# {urn:vim2}MultipathState
class MultipathState < ::String
  Active = MultipathState.new("active")
  Dead = MultipathState.new("dead")
  Disabled = MultipathState.new("disabled")
  Standby = MultipathState.new("standby")
  Unknown = MultipathState.new("unknown")
end

# {urn:vim2}PortGroupConnecteeType
class PortGroupConnecteeType < ::String
  Host = PortGroupConnecteeType.new("host")
  SystemManagement = PortGroupConnecteeType.new("systemManagement")
  Unknown = PortGroupConnecteeType.new("unknown")
  VirtualMachine = PortGroupConnecteeType.new("virtualMachine")
end

# {urn:vim2}HostFirewallRuleDirection
class HostFirewallRuleDirection < ::String
  Inbound = HostFirewallRuleDirection.new("inbound")
  Outbound = HostFirewallRuleDirection.new("outbound")
end

# {urn:vim2}HostFirewallRuleProtocol
class HostFirewallRuleProtocol < ::String
  Tcp = HostFirewallRuleProtocol.new("tcp")
  Udp = HostFirewallRuleProtocol.new("udp")
end

# {urn:vim2}ScsiLunType
class ScsiLunType < ::String
  Cdrom = ScsiLunType.new("cdrom")
  Communications = ScsiLunType.new("communications")
  Disk = ScsiLunType.new("disk")
  Enclosure = ScsiLunType.new("enclosure")
  MediaChanger = ScsiLunType.new("mediaChanger")
  OpticalDevice = ScsiLunType.new("opticalDevice")
  Printer = ScsiLunType.new("printer")
  Processor = ScsiLunType.new("processor")
  Scanner = ScsiLunType.new("scanner")
  StorageArrayController = ScsiLunType.new("storageArrayController")
  Tape = ScsiLunType.new("tape")
  Unknown = ScsiLunType.new("unknown")
  Worm = ScsiLunType.new("worm")
end

# {urn:vim2}ScsiLunState
class ScsiLunState < ::String
  Degraded = ScsiLunState.new("degraded")
  Error = ScsiLunState.new("error")
  LostCommunication = ScsiLunState.new("lostCommunication")
  Ok = ScsiLunState.new("ok")
  UnknownState = ScsiLunState.new("unknownState")
end

# {urn:vim2}HostServicePolicy
class HostServicePolicy < ::String
  Automatic = HostServicePolicy.new("automatic")
  Off = HostServicePolicy.new("off")
  On = HostServicePolicy.new("on")
end

# {urn:vim2}ArrayUpdateOperation
class ArrayUpdateOperation < ::String
  Add = ArrayUpdateOperation.new("add")
  Edit = ArrayUpdateOperation.new("edit")
  Remove = ArrayUpdateOperation.new("remove")
end

# {urn:vim2}DayOfWeek
class DayOfWeek < ::String
  Friday = DayOfWeek.new("friday")
  Monday = DayOfWeek.new("monday")
  Saturday = DayOfWeek.new("saturday")
  Sunday = DayOfWeek.new("sunday")
  Thursday = DayOfWeek.new("thursday")
  Tuesday = DayOfWeek.new("tuesday")
  Wednesday = DayOfWeek.new("wednesday")
end

# {urn:vim2}WeekOfMonth
class WeekOfMonth < ::String
  First = WeekOfMonth.new("first")
  Fourth = WeekOfMonth.new("fourth")
  Last = WeekOfMonth.new("last")
  Second = WeekOfMonth.new("second")
  Third = WeekOfMonth.new("third")
end

# {urn:vim2}VirtualMachinePowerOpType
class VirtualMachinePowerOpType < ::String
  Hard = VirtualMachinePowerOpType.new("hard")
  Preset = VirtualMachinePowerOpType.new("preset")
  Soft = VirtualMachinePowerOpType.new("soft")
end

# {urn:vim2}VirtualMachineStandbyActionType
class VirtualMachineStandbyActionType < ::String
  Checkpoint = VirtualMachineStandbyActionType.new("checkpoint")
  PowerOnSuspend = VirtualMachineStandbyActionType.new("powerOnSuspend")
end

# {urn:vim2}VirtualMachineHtSharing
class VirtualMachineHtSharing < ::String
  Any = VirtualMachineHtSharing.new("any")
  Internal = VirtualMachineHtSharing.new("internal")
  None = VirtualMachineHtSharing.new("none")
end

# {urn:vim2}VirtualMachineToolsStatus
class VirtualMachineToolsStatus < ::String
  ToolsNotInstalled = VirtualMachineToolsStatus.new("toolsNotInstalled")
  ToolsNotRunning = VirtualMachineToolsStatus.new("toolsNotRunning")
  ToolsOk = VirtualMachineToolsStatus.new("toolsOk")
  ToolsOld = VirtualMachineToolsStatus.new("toolsOld")
end

# {urn:vim2}VirtualMachineGuestState
class VirtualMachineGuestState < ::String
  NotRunning = VirtualMachineGuestState.new("notRunning")
  Resetting = VirtualMachineGuestState.new("resetting")
  Running = VirtualMachineGuestState.new("running")
  ShuttingDown = VirtualMachineGuestState.new("shuttingDown")
  Standby = VirtualMachineGuestState.new("standby")
  Unknown = VirtualMachineGuestState.new("unknown")
end

# {urn:vim2}VirtualMachineGuestOsFamily
class VirtualMachineGuestOsFamily < ::String
  LinuxGuest = VirtualMachineGuestOsFamily.new("linuxGuest")
  NetwareGuest = VirtualMachineGuestOsFamily.new("netwareGuest")
  OtherGuestFamily = VirtualMachineGuestOsFamily.new("otherGuestFamily")
  SolarisGuest = VirtualMachineGuestOsFamily.new("solarisGuest")
  WindowsGuest = VirtualMachineGuestOsFamily.new("windowsGuest")
end

# {urn:vim2}VirtualMachineGuestOsIdentifier
class VirtualMachineGuestOsIdentifier < ::String
  DarwinGuest = VirtualMachineGuestOsIdentifier.new("darwinGuest")
  DosGuest = VirtualMachineGuestOsIdentifier.new("dosGuest")
  Freebsd64Guest = VirtualMachineGuestOsIdentifier.new("freebsd64Guest")
  FreebsdGuest = VirtualMachineGuestOsIdentifier.new("freebsdGuest")
  Mandrake64Guest = VirtualMachineGuestOsIdentifier.new("mandrake64Guest")
  MandrakeGuest = VirtualMachineGuestOsIdentifier.new("mandrakeGuest")
  Netware4Guest = VirtualMachineGuestOsIdentifier.new("netware4Guest")
  Netware5Guest = VirtualMachineGuestOsIdentifier.new("netware5Guest")
  Netware6Guest = VirtualMachineGuestOsIdentifier.new("netware6Guest")
  Nld9Guest = VirtualMachineGuestOsIdentifier.new("nld9Guest")
  OesGuest = VirtualMachineGuestOsIdentifier.new("oesGuest")
  Os2Guest = VirtualMachineGuestOsIdentifier.new("os2Guest")
  Other24xLinux64Guest = VirtualMachineGuestOsIdentifier.new("other24xLinux64Guest")
  Other24xLinuxGuest = VirtualMachineGuestOsIdentifier.new("other24xLinuxGuest")
  Other26xLinux64Guest = VirtualMachineGuestOsIdentifier.new("other26xLinux64Guest")
  Other26xLinuxGuest = VirtualMachineGuestOsIdentifier.new("other26xLinuxGuest")
  OtherGuest = VirtualMachineGuestOsIdentifier.new("otherGuest")
  OtherGuest64 = VirtualMachineGuestOsIdentifier.new("otherGuest64")
  OtherLinux64Guest = VirtualMachineGuestOsIdentifier.new("otherLinux64Guest")
  OtherLinuxGuest = VirtualMachineGuestOsIdentifier.new("otherLinuxGuest")
  RedhatGuest = VirtualMachineGuestOsIdentifier.new("redhatGuest")
  Rhel2Guest = VirtualMachineGuestOsIdentifier.new("rhel2Guest")
  Rhel3Guest = VirtualMachineGuestOsIdentifier.new("rhel3Guest")
  Rhel3_64Guest = VirtualMachineGuestOsIdentifier.new("rhel3_64Guest")
  Rhel4Guest = VirtualMachineGuestOsIdentifier.new("rhel4Guest")
  Rhel4_64Guest = VirtualMachineGuestOsIdentifier.new("rhel4_64Guest")
  SjdsGuest = VirtualMachineGuestOsIdentifier.new("sjdsGuest")
  Sles64Guest = VirtualMachineGuestOsIdentifier.new("sles64Guest")
  SlesGuest = VirtualMachineGuestOsIdentifier.new("slesGuest")
  Solaris10Guest = VirtualMachineGuestOsIdentifier.new("solaris10Guest")
  Solaris10_64Guest = VirtualMachineGuestOsIdentifier.new("solaris10_64Guest")
  Solaris6Guest = VirtualMachineGuestOsIdentifier.new("solaris6Guest")
  Solaris7Guest = VirtualMachineGuestOsIdentifier.new("solaris7Guest")
  Solaris8Guest = VirtualMachineGuestOsIdentifier.new("solaris8Guest")
  Solaris9Guest = VirtualMachineGuestOsIdentifier.new("solaris9Guest")
  Suse64Guest = VirtualMachineGuestOsIdentifier.new("suse64Guest")
  SuseGuest = VirtualMachineGuestOsIdentifier.new("suseGuest")
  TurboLinuxGuest = VirtualMachineGuestOsIdentifier.new("turboLinuxGuest")
  Ubuntu64Guest = VirtualMachineGuestOsIdentifier.new("ubuntu64Guest")
  UbuntuGuest = VirtualMachineGuestOsIdentifier.new("ubuntuGuest")
  Win2000AdvServGuest = VirtualMachineGuestOsIdentifier.new("win2000AdvServGuest")
  Win2000ProGuest = VirtualMachineGuestOsIdentifier.new("win2000ProGuest")
  Win2000ServGuest = VirtualMachineGuestOsIdentifier.new("win2000ServGuest")
  Win31Guest = VirtualMachineGuestOsIdentifier.new("win31Guest")
  Win95Guest = VirtualMachineGuestOsIdentifier.new("win95Guest")
  Win98Guest = VirtualMachineGuestOsIdentifier.new("win98Guest")
  WinMeGuest = VirtualMachineGuestOsIdentifier.new("winMeGuest")
  WinNTGuest = VirtualMachineGuestOsIdentifier.new("winNTGuest")
  WinNetBusinessGuest = VirtualMachineGuestOsIdentifier.new("winNetBusinessGuest")
  WinNetEnterprise64Guest = VirtualMachineGuestOsIdentifier.new("winNetEnterprise64Guest")
  WinNetEnterpriseGuest = VirtualMachineGuestOsIdentifier.new("winNetEnterpriseGuest")
  WinNetStandard64Guest = VirtualMachineGuestOsIdentifier.new("winNetStandard64Guest")
  WinNetStandardGuest = VirtualMachineGuestOsIdentifier.new("winNetStandardGuest")
  WinNetWebGuest = VirtualMachineGuestOsIdentifier.new("winNetWebGuest")
  WinVista64Guest = VirtualMachineGuestOsIdentifier.new("winVista64Guest")
  WinVistaGuest = VirtualMachineGuestOsIdentifier.new("winVistaGuest")
  WinXPHomeGuest = VirtualMachineGuestOsIdentifier.new("winXPHomeGuest")
  WinXPPro64Guest = VirtualMachineGuestOsIdentifier.new("winXPPro64Guest")
  WinXPProGuest = VirtualMachineGuestOsIdentifier.new("winXPProGuest")
end

# {urn:vim2}VirtualMachineRelocateTransformation
class VirtualMachineRelocateTransformation < ::String
  Flat = VirtualMachineRelocateTransformation.new("flat")
  Sparse = VirtualMachineRelocateTransformation.new("sparse")
end

# {urn:vim2}VirtualMachineScsiPassthroughType
class VirtualMachineScsiPassthroughType < ::String
  Cdrom = VirtualMachineScsiPassthroughType.new("cdrom")
  Com = VirtualMachineScsiPassthroughType.new("com")
  Disk = VirtualMachineScsiPassthroughType.new("disk")
  Media = VirtualMachineScsiPassthroughType.new("media")
  Optical = VirtualMachineScsiPassthroughType.new("optical")
  Printer = VirtualMachineScsiPassthroughType.new("printer")
  Processor = VirtualMachineScsiPassthroughType.new("processor")
  Raid = VirtualMachineScsiPassthroughType.new("raid")
  Scanner = VirtualMachineScsiPassthroughType.new("scanner")
  Tape = VirtualMachineScsiPassthroughType.new("tape")
  Unknown = VirtualMachineScsiPassthroughType.new("unknown")
  Worm = VirtualMachineScsiPassthroughType.new("worm")
end

# {urn:vim2}VirtualMachineTargetInfoConfigurationTag
class VirtualMachineTargetInfoConfigurationTag < ::String
  ClusterWide = VirtualMachineTargetInfoConfigurationTag.new("clusterWide")
  Compliant = VirtualMachineTargetInfoConfigurationTag.new("compliant")
end

# {urn:vim2}CustomizationLicenseDataMode
class CustomizationLicenseDataMode < ::String
  PerSeat = CustomizationLicenseDataMode.new("perSeat")
  PerServer = CustomizationLicenseDataMode.new("perServer")
end

# {urn:vim2}CustomizationNetBIOSMode
class CustomizationNetBIOSMode < ::String
  DisableNetBIOS = CustomizationNetBIOSMode.new("disableNetBIOS")
  EnableNetBIOS = CustomizationNetBIOSMode.new("enableNetBIOS")
  EnableNetBIOSViaDhcp = CustomizationNetBIOSMode.new("enableNetBIOSViaDhcp")
end

# {urn:vim2}VirtualDeviceFileExtension
class VirtualDeviceFileExtension < ::String
  Dsk = VirtualDeviceFileExtension.new("dsk")
  Flp = VirtualDeviceFileExtension.new("flp")
  Iso = VirtualDeviceFileExtension.new("iso")
  Rdm = VirtualDeviceFileExtension.new("rdm")
  Vmdk = VirtualDeviceFileExtension.new("vmdk")
end

# {urn:vim2}VirtualDeviceConfigSpecOperation
class VirtualDeviceConfigSpecOperation < ::String
  Add = VirtualDeviceConfigSpecOperation.new("add")
  Edit = VirtualDeviceConfigSpecOperation.new("edit")
  Remove = VirtualDeviceConfigSpecOperation.new("remove")
end

# {urn:vim2}VirtualDeviceConfigSpecFileOperation
class VirtualDeviceConfigSpecFileOperation < ::String
  Create = VirtualDeviceConfigSpecFileOperation.new("create")
  Destroy = VirtualDeviceConfigSpecFileOperation.new("destroy")
  Replace = VirtualDeviceConfigSpecFileOperation.new("replace")
end

# {urn:vim2}VirtualDiskMode
class VirtualDiskMode < ::String
  Append = VirtualDiskMode.new("append")
  Independent_nonpersistent = VirtualDiskMode.new("independent_nonpersistent")
  Independent_persistent = VirtualDiskMode.new("independent_persistent")
  Nonpersistent = VirtualDiskMode.new("nonpersistent")
  Persistent = VirtualDiskMode.new("persistent")
  Undoable = VirtualDiskMode.new("undoable")
end

# {urn:vim2}VirtualDiskCompatibilityMode
class VirtualDiskCompatibilityMode < ::String
  PhysicalMode = VirtualDiskCompatibilityMode.new("physicalMode")
  VirtualMode = VirtualDiskCompatibilityMode.new("virtualMode")
end

# {urn:vim2}VirtualEthernetCardLegacyNetworkDeviceName
class VirtualEthernetCardLegacyNetworkDeviceName < ::String
  Bridged = VirtualEthernetCardLegacyNetworkDeviceName.new("bridged")
  Hostonly = VirtualEthernetCardLegacyNetworkDeviceName.new("hostonly")
  Nat = VirtualEthernetCardLegacyNetworkDeviceName.new("nat")
end

# {urn:vim2}VirtualEthernetCardMacType
class VirtualEthernetCardMacType < ::String
  Assigned = VirtualEthernetCardMacType.new("assigned")
  Generated = VirtualEthernetCardMacType.new("generated")
  Manual = VirtualEthernetCardMacType.new("manual")
end

# {urn:vim2}VirtualPointingDeviceHostChoice
class VirtualPointingDeviceHostChoice < ::String
  Autodetect = VirtualPointingDeviceHostChoice.new("autodetect")
  IntellimouseExplorer = VirtualPointingDeviceHostChoice.new("intellimouseExplorer")
  IntellimousePs2 = VirtualPointingDeviceHostChoice.new("intellimousePs2")
  LogitechMouseman = VirtualPointingDeviceHostChoice.new("logitechMouseman")
  Microsoft_serial = VirtualPointingDeviceHostChoice.new("microsoft_serial")
  MouseSystems = VirtualPointingDeviceHostChoice.new("mouseSystems")
  MousemanSerial = VirtualPointingDeviceHostChoice.new("mousemanSerial")
  Ps2 = VirtualPointingDeviceHostChoice.new("ps2")
end

# {urn:vim2}VirtualSCSISharing
class VirtualSCSISharing < ::String
  NoSharing = VirtualSCSISharing.new("noSharing")
  PhysicalSharing = VirtualSCSISharing.new("physicalSharing")
  VirtualSharing = VirtualSCSISharing.new("virtualSharing")
end

# {urn:vim2}VirtualSerialPortEndPoint
class VirtualSerialPortEndPoint < ::String
  Client = VirtualSerialPortEndPoint.new("client")
  Server = VirtualSerialPortEndPoint.new("server")
end

puts "**** TEST OK ****"
