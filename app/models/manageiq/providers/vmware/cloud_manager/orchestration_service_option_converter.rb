module ManageIQ::Providers
  class Vmware::CloudManager::OrchestrationServiceOptionConverter < ::ServiceOrchestration::OptionConverter
    include Vmdb::Logging

    def stack_create_options
      options = {
        :deploy  => stack_parameters['deploy'] == 't',
        :powerOn => stack_parameters['powerOn'] == 't'
      }
      options[:vdc_id] = @dialog_options['dialog_availability_zone'] unless @dialog_options['dialog_availability_zone'].blank?

      options.merge!(customize_vapp_template(collect_vm_params))
    end

    private

    # customize_vapp_template will prepare the options in a format suitable for the fog-vcloud-director.
    # This mainly results in creating two top level objects in a hash. The :InstantiationParams, contains
    # a single :NetworkConfig element with the array of all references to the networks used in the
    # deployed vApp. We are using IDs here and let fog library create concrete HREFs that are required
    # by the vCloud director. The second object is an array of source items. Each source item references
    # a single VM from the vApp template, customises its name and optionally sets network info.
    def customize_vapp_template(vm_params)
      network_config = {}

      source_vms = vm_params.collect do |vm_id, vm_opts|
        src_vm = { :vm_id => "vm-#{vm_id}" }
        src_vm[:name] = vm_opts["instance_name"] if vm_opts.key?("instance_name")

        network_id = vm_opts["vdc_network"]
        unless network_id.nil?
          # Create new network config if it hasn't been created before.
          network_config[network_id] ||= {
            :networkName => network_id,
            :networkId   => network_id,
            :fenceMode   => "bridged"
          }

          # Add network configuration to the source VM.
          src_vm[:networks] = [
            :networkName             => network_id,
            :IsConnected             => true,
            :IpAddressAllocationMode => "DHCP"
          ]
        end

        src_vm
      end

      # Create options suitable for VMware vCloud provider.
      custom_opts = {
        :source_vms => source_vms
      }
      custom_opts[:InstantiationParams] = {
        :NetworkConfig => network_config.values
      } unless network_config.empty?

      custom_opts
    end

    def collect_vm_params
      allowed_vm_params = %w(instance_name vdc_network)
      stack_parameters.each_with_object({}) do |(key, value), vm_params|
        allowed_vm_params.each do |param|
          # VM-specific parameters are named as instance_name-<VM_ID>. The
          # following will test the param name for this kind of pattern and use
          # the <VM_ID> to store the configuration about this VM.
          param_match = key.match(/#{param}-([0-9a-f-]*)/)
          next if param_match.nil?

          vm_id = param_match.captures.first
          vm_params[vm_id] ||= {}
          # Store the parameter value.
          vm_params[vm_id][param] = value
        end
      end
    end
  end
end
