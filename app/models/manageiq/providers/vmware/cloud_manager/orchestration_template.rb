class ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate < OrchestrationTemplate
  def parameter_groups
    # Define vApp's general purpose parameters.
    groups = [OrchestrationTemplate::OrchestrationParameterGroup.new(
      :label      => "vApp Parameters",
      :parameters => vapp_parameters,
    )]

    # Parse template's OVF file
    ovf_doc = MiqXml.load(content)
    # Collect VM-specific parameters from the OVF template if it is a valid one.
    groups.concat(vm_param_groups(ovf_doc.root)) unless ovf_doc.root.nil?

    groups
  end

  def vapp_parameters
    [
      OrchestrationTemplate::OrchestrationParameter.new(
        :name          => "deploy",
        :label         => "Deploy vApp",
        :data_type     => "boolean",
        :default_value => true,
        :constraints   => [
          OrchestrationTemplate::OrchestrationParameterBoolean.new
        ]
      ),
      OrchestrationTemplate::OrchestrationParameter.new(
        :name          => "powerOn",
        :label         => "Power On vApp",
        :data_type     => "boolean",
        :default_value => false,
        :constraints   => [
          OrchestrationTemplate::OrchestrationParameterBoolean.new
        ]
      )
    ]
  end

  def vm_param_groups(ovf)
    groups = []
    # Parse the XML template document for specific vCloud attributes.
    ovf.each_element("//vcloud:GuestCustomizationSection") do |el|
      vm_id = el.elements["vcloud:VirtualMachineId"].text
      vm_name = el.elements["vcloud:ComputerName"].text

      groups << OrchestrationTemplate::OrchestrationParameterGroup.new(
        :label      => vm_name,
        :parameters => [
          # Name of the provisioned instance.
          OrchestrationTemplate::OrchestrationParameter.new(
            :name          => "instance_name-#{vm_id}",
            :label         => "Instance name",
            :data_type     => "string",
            :default_value => vm_name
          ),

          # List of available VDC networks.
          OrchestrationTemplate::OrchestrationParameter.new(
            :name          => "vdc_network-#{vm_id}",
            :label         => "Network",
            :data_type     => "string",
            :default_value => "(default)",
            :constraints   => [
              OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(:fqname => "/Cloud/Orchestration/Operations/Methods/Available_Vdc_Networks")
            ]
          )
        ]
      )
    end

    groups
  end

  def self.eligible_manager_types
    [ManageIQ::Providers::Vmware::CloudManager]
  end

  def validate_format
    if content
      ovf_doc = MiqXml.load(content)
      !ovf_doc.root.nil? && nil
    end
  rescue REXML::ParseException => err
    err.message
  end
end
