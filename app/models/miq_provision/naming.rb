module MiqProvision::Naming
  extend ActiveSupport::Concern

  NAME_SEQUENCE_REGEX = /\$n\{(\d+)\}/
  SOURCE_IDENTIFIER = "provisioning".freeze # a unique name for the source column in custom_attributes table

  module ClassMethods
    def get_next_vm_name(prov_obj, determine_index = true)
      unresolved_vm_name = vm_name_from_automate(prov_obj)

      # Check if we need to force a unique target name
      if prov_obj.get_option(:miq_force_unique_name) == true && unresolved_vm_name !~ NAME_SEQUENCE_REGEX
        unresolved_vm_name += '$n{4}'
        _log.info("Forced unique provision name to #{unresolved_vm_name} for #{prov_obj.class}:#{prov_obj.id}")
      end

      get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
    end

    def get_vm_full_name(unresolved_vm_name, prov_obj, determine_index)
      return unresolved_vm_name unless unresolved_vm_name =~ NAME_SEQUENCE_REGEX

      name = {:prefix => $`, :suffix => $', :index => $&, :index_length => Regexp.last_match(1).to_i}

      # if we are just building a sample of what the vm_name will look like use '#' inplace of actual number.
      return "#{name[:prefix]}#{'#' * name[:index_length]}#{name[:suffix]}" if determine_index == false

      resolve_vm_name(name, unresolved_vm_name, prov_obj)
    end

    def resolve_vm_name(name, unresolved_vm_name, prov_obj)
      index_length = name[:index_length]
      loop do
        next_number = MiqRegion.my_region.next_naming_sequence(unresolved_vm_name, SOURCE_IDENTIFIER)
        idx_str = next_number.to_s.rjust(index_length, '0')
        if idx_str.length > index_length
          index_length += 1
          unresolved_vm_name = "#{name[:prefix]}$n{#{index_length}}#{name[:suffix]}"
          next
        end

        fullname = "#{name[:prefix]}#{idx_str}#{name[:suffix]}"
        return fullname if vm_name_unique?(fullname, prov_obj)
      end
    end

    def vm_name_unique?(fullname, prov_obj)
      ems = prov_obj&.vm_template&.ext_management_system
      return true if ems.nil?
      !VmOrTemplate.find_by("ems_id = ? and lower(name) = ?", ems.id, fullname.downcase)
    end
  end

  def get_next_vm_name
    self.class.get_next_vm_name(self)
  end
end
