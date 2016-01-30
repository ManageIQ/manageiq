module MiqProvision::Naming
  extend ActiveSupport::Concern

  NAME_VIA_AUTOMATE = true
  NAME_SEQUENCE_REGEX = /\$n\{(\d+)\}/
  SOURCE_IDENTIFIER = "provisioning"  # a unique name for the source column in custom_attributes table

  module ClassMethods
    def get_next_vm_name(prov_obj, determine_index = true)
      unresolved_vm_name = nil

      if NAME_VIA_AUTOMATE == true
        prov_obj.save
        attrs = {'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname'}
        MiqAeEngine.set_automation_attributes_from_objects([prov_obj.get_user], attrs)
        ws = MiqAeEngine.resolve_automation_object("REQUEST", prov_obj.get_user, attrs, :vmdb_object => prov_obj)

        unresolved_vm_name = ws.root("vmname")
        prov_obj.reload
      end

      if unresolved_vm_name.blank?
        options        = prov_obj.options
        options[:tags] = prov_obj.get_tags

        load File.join(File.expand_path(Rails.root), 'db/fixtures/miq_provision_naming.rb')
        unresolved_vm_name = MiqProvisionNaming.naming(options)
      end

      # Check if we need to force a unique target name
      if prov_obj.get_option(:miq_force_unique_name) == true && unresolved_vm_name !~ NAME_SEQUENCE_REGEX
        unresolved_vm_name += '_' unless unresolved_vm_name.ends_with?('_')
        unresolved_vm_name += '$n{4}'
        _log.info "Forced unique provision name to #{unresolved_vm_name} for #{prov_obj.class}:#{prov_obj.id}"
      end

      vm_name = get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
      vm_name
    end

    def get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
      # Split name to find the index substitution string
      if unresolved_vm_name =~ NAME_SEQUENCE_REGEX
        name = {:prefix => $`, :suffix => $', :index => $&, :index_length => Regexp.last_match(1).to_i}
      else
        # If we did not find the index substitution string just return what was passed in
        return unresolved_vm_name
      end

      # if we are just building a sample of what the vm_name will look like use '#' inplace of actual number.
      return "#{name[:prefix]}#{'#' * name[:index_length]}#{name[:suffix]}" if determine_index == false

      index_length = name[:index_length]
      loop do
        next_number = MiqRegion.my_region.next_naming_sequence(unresolved_vm_name, SOURCE_IDENTIFIER)
        idx_str  = "%0#{index_length}d" % next_number
        if idx_str.length > index_length
          index_length += 1
          unresolved_vm_name = "#{name[:prefix]}$n{#{index_length}}#{name[:suffix]}"
          next
        end

        fullname = "#{name[:prefix]}#{idx_str}#{name[:suffix]}"
        vm       = check_vm_name_uniqueness(fullname, prov_obj)
        return fullname if vm.nil?
      end
    end

    def check_vm_name_uniqueness(fullname, prov_obj)
      return nil if prov_obj.vm_template.nil?
      ems = prov_obj.vm_template.ext_management_system
      return nil if ems.nil?
      VmOrTemplate.find_by("ems_id = ? and lower(name) = ?", ems.id, fullname.downcase)
    end
  end

  def get_next_vm_name
    self.class.get_next_vm_name(self)
  end
end
