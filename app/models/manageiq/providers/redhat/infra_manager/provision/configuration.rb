module ManageIQ::Providers::Redhat::InfraManager::Provision::Configuration
  extend ActiveSupport::Concern

  include_concern 'Container'
  include_concern 'Network'

  def attach_floppy_payload
    return unless content = customization_template_content
    filename = customization_template.default_filename
    get_provider_destination.attach_floppy(filename => content)
  end

  def configure_cloud_init
    return unless content = customization_template_content
    get_provider_destination.cloud_init = content

    if Gem::Version.new(source.ext_management_system.api_version) >= Gem::Version.new("3.5.5.0")
      phase_context[:boot_with_cloud_init] = true
    end
  end

  def configure_container
    rhevm_vm = get_provider_destination

    configure_container_description(rhevm_vm)
    configure_memory(rhevm_vm)
    configure_memory_reserve(rhevm_vm)
    configure_cpu(rhevm_vm)
    configure_host_affinity(rhevm_vm)
    configure_network_adapters
    configure_cloud_init
  end

  private

  def customization_template_content
    return unless customization_template
    options = prepare_customization_template_substitution_options
    customization_template.script_with_substitution(options)
  end
end
