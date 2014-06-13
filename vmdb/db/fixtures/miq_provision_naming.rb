module MiqProvisionNaming
  def self.naming(options)
    vm_name = options[:vm_name].to_s.strip
    number_of_vms_being_provisioned = options[:number_of_vms]
    number_of_vms_being_provisioned = number_of_vms_being_provisioned.first if number_of_vms_being_provisioned.kind_of?(Array)
    tags = options[:tags]

    # Construct VM name here
    # Use $n{#} to indicate a sequence number where # is the 0-char padding.
    #     Example: $n{3} would result in "001" added to the vm name
    # Reference tags by the category name
    #     Example - Add selected environment to vm name: "#{tags['environment']}v#{vm_name}$n{3}"
    #     Result for dev environment with "miq" entered as the vm name: devmiq001

    # Sample:
    # Create random VM name
    # "miq_vm_#{rand(20000)}"

    # Default naming:
    #   Single VM: Pass name from dialog through without modifying
    #   Multi-VM : Append 3 digit sequence number to the end of the name from the dialog
    if number_of_vms_being_provisioned == 1
      "#{vm_name}"
    else
      "#{vm_name}$n{3}"
    end
  end
end
