module MiqAeMethodService
  class MiqAeServiceExtManagementSystem < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_inflector_mixin"
    include MiqAeServiceInflectorMixin
    require_relative "mixins/miq_ae_service_custom_attribute_mixin"
    include MiqAeServiceCustomAttributeMixin

    expose :storages,             :association => true
    expose :hosts,                :association => true
    expose :vms,                  :association => true
    expose :ems_events,           :association => true
    expose :ems_clusters,         :association => true
    expose :ems_folders,          :association => true
    expose :resource_pools,       :association => true
    expose :tenant,               :association => true
    expose :miq_templates,        :association => true
    expose :customization_specs,  :association => true
    expose :to_s
    expose :authentication_userid
    expose :authentication_password
    expose :authentication_password_encrypted
    expose :authentication_key
    expose :refresh, :method => :refresh_ems
    expose :provider, :association => true
  end
end
