require 'actionwebservice'

module VmdbwsSupport
  class MiqActionWebServiceStruct < ActionWebService::Struct
    def to_h
      ret = {}
      self.each_pair { |k, v| ret[k] = v }
      ret
    end
    alias to_hash to_h
  end

  # Create a Datastore and Cluster structures that can be returned by the WS interface
  class Datastore < Storage; end
  class Cluster   < EmsCluster; end

  class NameGuidStruct < MiqActionWebServiceStruct
    member :guid,         :string
    member :name,         :string
  end

  class DescriptionIdStruct < MiqActionWebServiceStruct
    member :id,           :string
    member :description,  :string
  end

  class NameIdStruct < MiqActionWebServiceStruct
    member :id,           :string
    member :name,         :string
  end

  class KeyValueStruct < MiqActionWebServiceStruct
    member :key,          :string
    member :value,        :string
  end

  class WSAttributes < MiqActionWebServiceStruct
    member :name,          :string
    member :data_type,     :string
    member :value,         :string
  end

  class VmList           < NameGuidStruct; end
  class HostList         < NameGuidStruct; end
  class EmsList          < NameGuidStruct; end
  class EventList        < NameGuidStruct; end
  class ConditionList    < NameGuidStruct; end
  class ActionList       < NameGuidStruct; end
  class ClusterList      < NameIdStruct; end
  class ResourcePoolList < NameIdStruct; end
  class DatastoreList    < NameIdStruct; end

  class PolicyList < NameGuidStruct
    member :description,  :string
  end

  class MiqProvisionTaskList < DescriptionIdStruct; end

  class GenericResultStruct < MiqActionWebServiceStruct
    member :result,       :string
    member :reason,       :string
  end

  class VmRsop      < GenericResultStruct ;end
  class VmCmdResult < GenericResultStruct ;end


  class VmSoftware < MiqActionWebServiceStruct
    member :name,         :string
    member :vendor,       :string
    member :description,  :string
    member :version,      :string
  end

  class VmAccounts < MiqActionWebServiceStruct
    member :name,         :string
    member :type,         :string
  end

  class VmInvokeTasksOptions < MiqActionWebServiceStruct
    member :ids,          [:string]
    member :task,         :string
    member :userid,       :string
  end

  class ProvisionOptions < MiqActionWebServiceStruct
    member :values,                :string
    member :ems_custom_attributes, :string
    member :miq_custom_attributes, :string
  end

  class Tag < MiqActionWebServiceStruct
    member :category,               :string
    member :category_display_name,  :string
    member :tag_name,               :string
    member :tag_display_name,       :string
    member :tag_path,               :string
    member :display_name,           :string
  end

  #
  # Proxy AR structs
  #

  SKIP_PROXY_ATTRS = ['memory_exceeds_current_host_headroom']
  WS_PROXY_NAMES   = { 'Storage'    => 'Datastore',
                       'EmsCluster' => 'Cluster'   }

  # Create a Proxy webservice struct for each ActiveRecord class, that will
  # expose all non-serialized columns and all virtual columns.
  [ExtManagementSystem, Host, Vm, EmsCluster, ResourcePool, Storage, CustomAttribute, MiqProvisionRequest, MiqProvision, AutomationRequest, AutomationTask, Hardware].each do |ar_klass|
    proxy_class_name = WS_PROXY_NAMES.has_key?(ar_klass.name) ? WS_PROXY_NAMES[ar_klass.name] : ar_klass.name
    proxy = self.const_set("Proxy#{proxy_class_name}", Class.new(MiqActionWebServiceStruct))


    ar_klass.columns_hash.collect do |k, v|
      next if SKIP_PROXY_ATTRS.include?(k)
      next if ar_klass.serialized_attributes.has_key?(k) # Skip serialized columns
      next if k.include?("password")
      next if k =~ /custom_\d/

      if k == 'id' || k.ends_with?('_id')
        type = :string
      else
        type = case v.type
        when :string_set  then [:string]
        # Use :float for numeric values because :integer will not support
        # Bignum values and will generate invalid XML
        when :numeric_set then [:float]
        when :integer     then :float
        when :symbol      then :string
        when :timestamp   then :datetime
        else v.type
        end
      end

      proxy.member k, type
    end

    [:ipaddresses, :hostnames].each do |key|
      proxy.member key, [:string] if ar_klass.virtual_column?(key)
    end
  end

  # Further extend proxy classes with relationships or method results

  class ProxyExtManagementSystem < MiqActionWebServiceStruct
    member :hosts,                  [HostList]
    member :clusters,               [ClusterList]
    member :resource_pools,         [ResourcePoolList]
    member :vms,                    [VmList]
    member :ws_attributes,          [WSAttributes]
    member :datastores,             [DatastoreList]
  end

  class ProxyHost < MiqActionWebServiceStruct
    member :custom_attributes,      [ProxyCustomAttribute]
    member :ext_management_system,  EmsList
    member :parent_cluster,         ClusterList
    member :resource_pools,         [ResourcePoolList]
    member :default_resource_pool,  ResourcePoolList
    member :datastores,             [DatastoreList]
    member :vms,                    [VmList]
    member :ws_attributes,          [WSAttributes]
    member :hardware,               ProxyHardware
  end

  class ProxyCluster < MiqActionWebServiceStruct
    member :ext_management_system,  EmsList
    member :hosts,                  [HostList]
    member :resource_pools,         [ResourcePoolList]
    member :default_resource_pool,  ResourcePoolList
    member :vms,                    [VmList]
    member :ws_attributes,          [WSAttributes]
    member :datastores,             [DatastoreList]
  end

  class ProxyResourcePool < MiqActionWebServiceStruct
    member :vms,                    [VmList]
    member :ext_management_system,  EmsList
    member :ws_attributes,          [WSAttributes]
    member :parent_cluster,         ClusterList
  end

  class ProxyDatastore < MiqActionWebServiceStruct
    member :vms,                    [VmList]
    member :all_vms,                [VmList]
    member :hosts,                  [HostList]
    member :ws_attributes,          [WSAttributes]
    member :ext_management_systems, [EmsList]
  end

  class ProxyVm < MiqActionWebServiceStruct
    member :custom_attributes,      [ProxyCustomAttribute]
    member :host,                   HostList
    member :ext_management_system,  EmsList
    member :parent_cluster,         ClusterList
    member :datastores,             [DatastoreList]
    member :ws_attributes,          [WSAttributes]
    member :hardware,               ProxyHardware
    member :parent_resource_pool,   ResourcePoolList
  end

  class ProxyMiqProvisionRequest < MiqActionWebServiceStruct
    member :source,                 VmList
    member :vms,                    [VmList]
    member :miq_request_tasks,      [MiqProvisionTaskList]
    member :request_options,        [KeyValueStruct]
    member :request_tags,           [Tag]
  end

  class ProxyMiqProvision < MiqActionWebServiceStruct
    member :source,                 VmList
    member :destination,            VmList
    member :request_options,        [KeyValueStruct]
    member :request_tags,           [Tag]
  end

  class ProxyMiqProvisionTask < ProxyMiqProvision; end;

  class AutomationTaskSummary < DescriptionIdStruct
  end

  class ProxyAutomationRequest < MiqActionWebServiceStruct
    member :automation_tasks,      [AutomationTaskSummary]
  end

  class AutomationRequestSummary < DescriptionIdStruct
  end

  class ProxyAutomationTask < MiqActionWebServiceStruct
    member :automation_request,    AutomationRequestSummary
  end

end
