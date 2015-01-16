module MiqProvision::Naming
  extend ActiveSupport::Concern

  NAME_VIA_AUTOMATE = true
  NAME_SEQUENCE_REGEX = /\$n\{(\d+)\}/

  module ClassMethods
    def get_next_vm_name(prov_obj, determine_index=true)
      log_header = "MiqProvision.get_next_vm_name"

      unresolved_vm_name = nil

      if NAME_VIA_AUTOMATE == true
        prov_obj.save
        attrs = { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname' }
        attrs[MiqAeEngine.create_automation_attribute_key(prov_obj.get_user)] = MiqAeEngine.create_automation_attribute_value(prov_obj.get_user) unless prov_obj.get_user.nil?
        uri = MiqAeEngine.create_automation_object("REQUEST", attrs, :vmdb_object => prov_obj)
        ws  = MiqAeEngine.resolve_automation_object(uri)
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
        $log.info "#{log_header} Forced unique provision name to #{unresolved_vm_name} for #{prov_obj.class}:#{prov_obj.id}"
      end

      vm_name = get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
      return vm_name
    end

    def get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
      # Split name to find the index substitution string
      if unresolved_vm_name =~ NAME_SEQUENCE_REGEX
        name = {:prefix => $`, :suffix => $', :index => $&, :index_length => $1.to_i}
      else
        # If we did not find the index substitution string just return what was passed in
        return unresolved_vm_name
      end

      # if we are just building a sample of what the vm_name will look like use '#' inplace of actual number.
      return "#{name[:prefix]}#{'#' * name[:index_length]}#{name[:suffix]}" if determine_index == false

      # Determine starting index based on already assigned names in miq_provision table.
      start_idx = 0
      reg_val = Regexp.new("(#{name[:prefix]})(\\d{#{name[:index_length]}})(#{name[:suffix]})")

      MiqProvision.find(:all).each do |p|
        if p.options[:vm_target_name].to_s.strip =~ reg_val
          name_prefix, name_idx, name_suffix = $1.to_s, $2.to_i, $3
          # If the name prefix and suffix match record the highest index number
          if name[:prefix].downcase == name_prefix.downcase && name[:suffix].to_s.downcase == name_suffix.to_s.downcase
            start_idx = name_idx if name_idx > start_idx
          end
        end
      end
      start_idx += 1

      start_idx.upto(9999) do |x|
        idx_str  = format("%0#{name[:index_length]}d", x)
        fullname = "#{name[:prefix]}#{idx_str}#{name[:suffix]}"
        vm       = check_vm_name_uniqueness(fullname, prov_obj)
        return fullname if vm.nil?
      end
      return nil
    end

    def check_vm_name_uniqueness(fullname, prov_obj)
      return nil if prov_obj.vm_template.nil?
      ems = prov_obj.vm_template.ext_management_system
      return nil if ems.nil?
      VmOrTemplate.where("ems_id = ? and lower(name) = ?", ems.id, fullname.downcase).first
    end
  end

  def get_next_vm_name()
    self.class.get_next_vm_name(self)
  end



end
