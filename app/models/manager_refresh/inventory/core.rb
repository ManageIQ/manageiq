module ManagerRefresh::Inventory::Core
  extend ActiveSupport::Concern

  class_methods do
    def provider_module
      @provider_module ||= ManageIQ::Providers::Inflector.provider_module(self)
    end

    def has_authentications(options = {})
      has_inventory({
        :model_class                 => ::Authentication,
        :manager_ref                 => [:manager_ref],
        :inventory_object_attributes => %i(name userid type options),
      }.merge(options))
    end

    def has_configuration_scripts(options = {})
      has_inventory({
        :model_class                 => ::ConfigurationScript,
        :manager_ref                 => [:manager_ref],
        :inventory_object_attributes => %i(name description survey_spec variables inventory_root_group authentications),
      }.merge(options))
    end

    def has_configuration_script_sources(options = {})
      has_inventory({
        :model_class                 => ::ConfigurationScriptSource,
        :manager_ref                 => [:manager_ref],
        :inventory_object_attributes => %i(name description),
      }.merge(options))
    end

    def has_configuration_script_payloads(options = {})
      has_inventory({
        :model_class                 => ::ConfigurationScriptPayload,
        :manager_ref                 => [:configuration_script_source, :manager_ref],
        :inventory_object_attributes => %i(name),
      }.merge(options))
    end

    def has_configured_systems(options = {})
      has_inventory({
        :model_class                 => ::ConfiguredSystem,
        :manager_ref                 => [:manager_ref],
        :inventory_object_attributes => %i(hostname virtual_instance_ref counterpart inventory_root_group),
      }.merge(options))
    end

    def has_ems_folders(options = {})
      has_inventory({
        :model_class                 => ::EmsFolder,
        :inventory_object_attributes => %i(name),
      }.merge(options))
    end

    def has_vms(options = {})
      has_inventory({
        :model_class                 => ::Vm,
        :manager_ref                 => [:uid_ems],
        :inventory_object_attributes => %i(),
      }.merge(options))
    end
  end
end
