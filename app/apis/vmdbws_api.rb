require 'actionwebservice'

class VmdbwsApi < ActionWebService::API::Base
  include VmdbwsSupport

  #
  # Automate web services
  #

  api_method :EVM_get,
    :expects => [{:token => :string}, {:uri => :string}],
    :returns => [:string]

  api_method :EVM_set,
    :expects => [{:token => :string}, {:uri => :string}, {:value => :string}],
    :returns => [:string]

  #
  # Insight web services
  #

  api_method :EVM_ping,
    :expects => [{:data => :string}],
    :returns => [:bool]

  api_method :EVM_vm_list,
    :expects => [{:hostGuid => :string}],
    :returns => [[VmList]]

  api_method :EVM_host_list,
    :returns => [[HostList]]

  api_method :EVM_cluster_list,
    :returns => [[ClusterList]]

  api_method :EVM_resource_pool_list,
    :returns => [[ResourcePoolList]]

  api_method :EVM_datastore_list,
    :returns => [[DatastoreList]]

  api_method :EVM_vm_software,
    :expects => [{:vmGuid => :string}],
    :returns => [[VmSoftware]]

  api_method :EVM_vm_accounts,
    :expects => [{:vmGuid => :string}],
    :returns => [[VmAccounts]]

  api_method :EVM_get_host,
    :expects => [{:hostGuid => :string}],
    :returns => [Host]

  api_method :EVM_get_hosts,
    :expects => [{:emsGuid => :string}],
    :returns => [[Host]]

  api_method :EVM_get_cluster,
    :expects => [{:clusterId => :string}],
    :returns => [Cluster]

  api_method :EVM_get_clusters,
    :expects => [{:emsGuid => :string}],
    :returns => [[Cluster]]

  api_method :EVM_get_resource_pool,
    :expects => [{:resourcepoolId => :string}],
    :returns => [ResourcePool]

  api_method :EVM_get_resource_pools,
    :expects => [{:emsGuid => :string}],
    :returns => [[ResourcePool]]

  api_method :EVM_get_datastore,
    :expects => [{:datastoreId => :string}],
    :returns => [Datastore]

  api_method :EVM_get_datastores,
    :expects => [{:emsGuid => :string}],
    :returns => [[Datastore]]

  api_method :EVM_get_vm,
    :expects => [{:vmGuid => :string}],
    :returns => [Vm]

  api_method :EVM_get_vms,
    :expects => [{:hostGuid => :string}],
    :returns => [[Vm]]

  api_method :EVM_delete_vm_by_name,
    :expects => [{:vmName => :string}],
    :returns => [:bool]

  #
  # Control web services
  #

  api_method :EVM_smart_start,
    :expects => [{:vmGuid => :string}],
    :returns => [VmCmdResult]

  api_method :EVM_smart_stop,
    :expects => [{:vmGuid => :string}],
    :returns => [VmCmdResult]

  api_method :EVM_smart_suspend,
    :expects => [{:vmGuid => :string}],
    :returns => [VmCmdResult]

  api_method :EVM_get_policy,
    :expects => [{:policyName => :string}],
    :returns => [MiqPolicy]

  api_method :EVM_event_list,
    :expects => [{:policyGuid => :string}],
    :returns => [[EventList]]

  api_method :EVM_condition_list,
    :expects => [{:policyGuid => :string}],
    :returns => [[ConditionList]]

  api_method :EVM_action_list,
    :expects => [{:policyGuid => :string}],
    :returns => [[ActionList]]

  api_method :EVM_policy_list,
    :expects => [{:hostGuid => :string}],
    :returns => [[PolicyList]]

  api_method :EVM_vm_rsop,
    :expects => [{:vmGuid => :string}, {:policyName => :string}],
    :returns => [VmRsop]

  api_method :EVM_assign_policy,
    :expects => [{:policyGuid => :string}, {:hostGuid => :string}],
    :returns => [:bool]

  api_method :EVM_unassign_policy,
    :expects => [{:policyGuid => :string}, {:hostGuid => :string}],
    :returns => [:bool]

  # Add a single lifecycle event for a VM given a GUID or full location
  api_method :EVM_add_lifecycle_event,
    :expects => [{:event => :string}, {:status => :string}, {:message => :string}, {:vmGuid => :string}, {:vmLocation => :string}, {:createdBy => :string}],
    :returns => [:bool]

  api_method :EVM_provision_request,
    :expects => [{:sourceName => :string}, {:targetName => :string}, {:autoApprove => :bool}, {:tags => :string}, {:additionalValues => :string}],
    :returns => [:bool]

  api_method :EVM_provision_request_ex,
    :expects => [{:version => :string}, {:templateFields => :string}, {:vmFields => :string}, {:requester => :string},
                 {:tags => :string}, {:additionalValues => :string}, {:emsCustomAttributes => :string}, {:miqCustomAttributes => :string}],
    :returns => [:bool]

  api_method :EVM_host_provision_request,
    :expects => [{:version => :string}, {:templateFields => :string}, {:hostFields => :string}, {:requester => :string},
                 {:tags => :string}, {:additionalValues => :string}, {:emsCustomAttributes => :string}, {:miqCustomAttributes => :string}],
    :returns => [:bool]

  api_method :EVM_vm_scan_by_property,
    :expects => [{:property => :string}, {:value => :string}],
    :returns => [:bool]

  api_method :EVM_vm_event_by_property,
    :expects => [{:property => :string}, {:value => :string}, {:eventType => :string}, {:eventMessage => :string}, {:eventTime => :string}],
    :returns => [:bool]

  api_method :GetEmsList,
    :returns => [[EmsList]]

  api_method :GetHostList,
    :expects => [{:emsGuid => :string}],
    :returns => [[HostList]]

  api_method :GetClusterList,
    :expects => [{:emsGuid => :string}],
    :returns => [[ClusterList]]

  api_method :GetResourcePoolList,
    :expects => [{:emsGuid => :string}],
    :returns => [[ResourcePoolList]]

  api_method :GetDatastoreList,
    :expects => [{:emsGuid => :string}],
    :returns => [[DatastoreList]]

  api_method :GetVmList,
    :expects => [{:hostGuid => :string}],
    :returns => [[VmList]]

  api_method :FindEmsByGuid,
    :expects => [{:emsGuid => :string}],
    :returns => [ProxyExtManagementSystem]

  api_method :FindHostsByGuid,
    :expects => [{:hostGuids => [:string]}],
    :returns => [[ProxyHost]]

  api_method :FindHostByGuid,
    :expects => [{:hostGuid => :string}],
    :returns => [ProxyHost]

  api_method :FindClustersById,
    :expects => [{:clusterIds => [:string]}],
    :returns => [[ProxyCluster]]

  api_method :FindClusterById,
    :expects => [{:clusterId => :string}],
    :returns => [ProxyCluster]

  api_method :FindDatastoresById,
    :expects => [{:datastoreIds => [:string]}],
    :returns => [[ProxyDatastore]]

  api_method :FindDatastoreById,
    :expects => [{:datastoreId => :string}],
    :returns => [ProxyDatastore]

  api_method :FindResourcePoolsById,
    :expects => [{:resourcepoolIds => [:string]}],
    :returns => [[ProxyResourcePool]]

  api_method :FindResourcePoolById,
    :expects => [{:resourcepoolId => :string}],
    :returns => [ProxyResourcePool]

  api_method :FindVmsByGuid,
    :expects => [{:vmGuids => [:string]}],
    :returns => [[ProxyVm]]

  api_method :FindVmByGuid,
    :expects => [{:vmGuid => :string}],
    :returns => [ProxyVm]

  api_method :GetEmsByList,
    :expects => [{:emsList => [EmsList]}],
    :returns => [[ProxyExtManagementSystem]]

  api_method :GetHostsByList,
    :expects => [{:hostList => [HostList]}],
    :returns => [[ProxyHost]]

  api_method :GetClustersByList,
    :expects => [{:clusterList => [ClusterList]}],
    :returns => [[ProxyCluster]]

  api_method :GetDatastoresByList,
    :expects => [{:datastoreList => [DatastoreList]}],
    :returns => [[ProxyDatastore]]

  api_method :GetResourcePoolsByList,
    :expects => [{:resourcepoolList => [ResourcePoolList]}],
    :returns => [[ProxyResourcePool]]

  api_method :GetVmsByList,
    :expects => [{:vmList => [VmList]}],
    :returns => [[ProxyVm]]

  api_method :GetVmsByTag,
    :expects => [{:tag => :string}],
    :returns => [[ProxyVm]]

  api_method :GetTemplatesByTag,
    :expects => [{:tag => :string}],
    :returns => [[ProxyVm]]

  api_method :GetClustersByTag,
    :expects => [{:tag => :string}],
    :returns => [[ProxyCluster]]

  api_method :GetResourcePoolsByTag,
    :expects => [{:tag => :string}],
    :returns => [[ProxyResourcePool]]

  api_method :GetDatastoresByTag,
    :expects => [{:tag => :string}],
    :returns => [[ProxyDatastore]]

  api_method :VmAddCustomAttributeByFields,
    :expects => [{:vmGuid => :string}, {:name => :string}, {:value => :string}, {:section => :string}, {:source => :string}],
    :returns => [[ProxyCustomAttribute]]

  api_method :VmAddCustomAttribute,
    :expects => [{:vmGuid => :string}, {:customAttribute=>ProxyCustomAttribute}],
    :returns => [[ProxyCustomAttribute]]

  api_method :VmAddCustomAttributes,
    :expects => [{:vmGuid => :string}, {:customAttribute=>[ProxyCustomAttribute]}],
    :returns => [[ProxyCustomAttribute]]

  api_method :VmDeleteCustomAttribute,
    :expects => [{:vmGuid => :string}, {:customAttribute=>ProxyCustomAttribute}],
    :returns => [[ProxyCustomAttribute]]

  api_method :VmDeleteCustomAttributes,
    :expects => [{:vmGuid => :string}, {:customAttribute=>[ProxyCustomAttribute]}],
    :returns => [[ProxyCustomAttribute]]

  api_method :Version,
    :returns => [[:string]]

  api_method :VmProvisionRequest,
    :expects => [{:version => :string}, {:templateFields => :string}, {:vmFields => :string}, {:requester => :string},
                 {:tags => :string}, {:options => ProvisionOptions}],
    :returns => [ProxyMiqProvisionRequest]

  api_method :VmSetOwner,
    :expects => [{:vmGuid => :string}, {:owner=>:string}],
    :returns => [:bool]

  api_method :VmSetTag,
    :expects => [{:vmGuid => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :VmGetTags,
    :expects => [{:vmGuid => :string}],
    :returns => [[Tag]]

  api_method :HostSetTag,
    :expects => [{:hostGuid => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :HostGetTags,
    :expects => [{:hostGuid => :string}],
    :returns => [[Tag]]

  api_method :ClusterSetTag,
    :expects => [{:clusterId => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :ClusterGetTags,
    :expects => [{:clusterId => :string}],
    :returns => [[Tag]]

  api_method :EmsSetTag,
    :expects => [{:emsGuid => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :EmsGetTags,
    :expects => [{:emsGuid => :string}],
    :returns => [[Tag]]

  api_method :DatastoreSetTag,
    :expects => [{:datastoreId => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :DatastoreGetTags,
    :expects => [{:datastoreId => :string}],
    :returns => [[Tag]]

  api_method :ResourcePoolSetTag,
    :expects => [{:resourcepoolId => :string}, {:category=>:string}, {:name=>:string}],
    :returns => [:bool]

  api_method :ResourcePoolGetTags,
    :expects => [{:resourcepoolId => :string}],
    :returns => [[Tag]]

  api_method :GetVmProvisionRequest,
    :expects => [{:requestId => :string}],
    :returns => [ProxyMiqProvisionRequest]

  api_method :GetVmProvisionTask,
    :expects => [{:taskId => :string}],
    :returns => [ProxyMiqProvisionTask]

  api_method :CreateAutomationRequest,
    :expects => [{:version => :string}, {:uri_parts => :string}, {:parameters => :string}, {:requester => :string}],
    :returns => [:string]

  api_method :GetAutomationRequest,
    :expects => [{:requestId => :string}],
    :returns => [ProxyAutomationRequest]

  api_method :GetAutomationTask,
    :expects => [{:taskId => :string}],
    :returns => [ProxyAutomationTask]

  #
  # System methods
  #

  api_method :vm_invoke_tasks,
    :expects => [{:options => VmInvokeTasksOptions}],
    :returns => [:bool]

end
