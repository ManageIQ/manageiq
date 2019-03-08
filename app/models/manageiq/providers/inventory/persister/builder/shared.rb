module ManageIQ::Providers::Inventory::Persister::Builder::Shared
  extend ActiveSupport::Concern

  included do
    INVENTORY_RECONNECT_BLOCK = lambda do |inventory_collection, inventory_objects_index, attributes_index|
      relation = inventory_collection.model_class.where(:ems_id => nil)

      return if relation.count <= 0

      inventory_objects_index.each_slice(100) do |batch|
        batch_refs = batch.map(&:first)
        relation.where(inventory_collection.manager_ref.first => batch_refs).order(:id => :asc).each do |record|
          index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)

          # We need to delete the record from the inventory_objects_index
          # and attributes_index, otherwise it would be sent for create.
          inventory_object = inventory_objects_index.delete(index)
          hash             = attributes_index.delete(index)

          # Skip if hash is blank, which can happen when having several archived entities with the same ref
          next unless hash

          record.assign_attributes(hash.except(:id, :type))
          if !inventory_collection.check_changed? || record.changed?
            record.save!
            inventory_collection.store_updated_records(record)
          end

          inventory_object.id = record.id
        end
      end
    end.freeze

    def vendor
      ::ManageIQ::Providers::Inflector.provider_name(@persister_class).downcase
    rescue
      'unknown'
    end

    def ext_management_system
      add_properties(
        :manager_ref       => %i(guid),
        :custom_save_block => lambda do |ems, inventory_collection|
          ems_attrs = inventory_collection.data.first&.attributes
          ems.update_attributes!(ems_attrs) if ems_attrs
        end
      )
    end

    def vms
      vm_template_shared
    end

    def miq_templates
      vm_template_shared
      add_default_values(
        :template => true
      )
    end

    def vm_template_shared
      add_properties(
        :delete_method          => :disconnect_inv,
        :attributes_blacklist   => %i(genealogy_parent),
        :use_ar_object          => true, # Because of raw_power_state setter and hooks are needed for settings user
        :saver_strategy         => :default,
        :batch_extra_attributes => %i(power_state state_changed_on previous_state),
        :custom_reconnect_block => INVENTORY_RECONNECT_BLOCK
      )

      add_default_values(
        :ems_id => ->(persister) { persister.manager.id }
      )
    end

    def hardwares
      add_properties(
        :manager_ref                  => %i(vm_or_template),
        :parent_inventory_collections => %i(vms miq_templates),
        :use_ar_object                => true, # TODO(lsmola) just because of default value on cpu_sockets, this can be fixed by separating instances_hardwares and images_hardwares
      )
    end

    def operating_systems
      custom_save_block = lambda do |_ems, inventory_collection|
        vms_and_templates_ids   = inventory_collection.data.map { |os| os.vm_or_template&.id }.compact
        vms_and_templates_index = VmOrTemplate.includes(:operating_system).where(:id => vms_and_templates_ids).index_by(&:id)

        drift_states = DriftState.where(:resource_type => "VmOrTemplate", :resource_id => vms_and_templates_ids)
                                 .select(:resource_id).distinct.index_by(&:resource_id)

        inventory_collection.each do |inventory_object|
          vm_or_template = vms_and_templates_index[inventory_object.vm_or_template.id]

          # If a VM has had smartstate run on it (drift_states are present) then don't overwrite the
          # operating system record with one from the provider.  This is because typically far more
          # details and correct information can be found from smartstate.
          next unless drift_states[vm_or_template.id].nil? || vm_or_template.operating_system.nil? ||
                      vm_or_template.operating_system.product_name.blank?

          operating_system = vm_or_template.operating_system || inventory_object.model_class.new
          operating_system.update_attributes!(inventory_object.attributes)
        end
      end

      add_properties(
        :manager_ref                  => %i(vm_or_template),
        :parent_inventory_collections => %i(vms miq_templates),
        :custom_save_block            => custom_save_block
      )
    end

    def networks
      add_properties(
        :manager_ref                  => %i(hardware description),
        :parent_inventory_collections => %i(vms)
      )
    end

    def disks
      add_properties(
        :manager_ref                  => %i(hardware device_name),
        :parent_inventory_collections => %i(vms)
      )
    end

    def service_offerings
      add_common_default_values
    end

    def service_instances
      add_common_default_values
    end

    def service_parameters_sets
      add_common_default_values
    end

    protected

    def add_common_default_values
      add_default_values(:ems_id => ->(persister) { persister.manager.id })
    end
  end
end
