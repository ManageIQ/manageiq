module ServiceTemplate::Copy
  extend ActiveSupport::Concern

  def template_copy(new_name = "Copy of " + name + Time.zone.now.to_s)
    if template_valid? && type != 'ServiceTemplateAnsiblePlaybook'
      ActiveRecord::Base.transaction do
        dup.tap do |template|
          template.update_attributes(:name => new_name, :display => false)
          service_resources.each { |sr| resource_copy(sr, template) }
          custom_buttons.each { |cb| custom_button_copy(cb, template) }
          custom_button_sets.each { |cbs| custom_button_set_copy(cbs, template) }
        end.save!
      end
    end
  end

  def resource_copy(sr, template)
    resource = sr.resource.respond_to?(:service_template_resource_copy) ? sr.resource.service_template_resource_copy : sr.resource
    template.add_resource(resource, sr)
  end

  def custom_button_copy(custom_button, template)
    custom_button.copy(:applies_to => template)
  end

  def custom_button_set_copy(cbs, template)
    cbs.deep_copy(:owner => template)
  end
end
