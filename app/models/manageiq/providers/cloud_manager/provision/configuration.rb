module ManageIQ::Providers::CloudManager::Provision::Configuration
  def userdata_payload
    return nil unless customization_template
    options = prepare_customization_template_substitution_options
    customization_template.script_with_substitution(options)
  end
end
