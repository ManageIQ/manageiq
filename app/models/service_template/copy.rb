module ServiceTemplate::Copy
  extend ActiveSupport::Concern

  def template_copy(new_name = "Copy of " + name + Time.zone.now.to_s)
    if template_valid? && type != 'ServiceTemplateAnsiblePlaybook'
      ActiveRecord::Base.transaction do
        dup.tap do |template|
          template.update_attributes(:name => new_name, :display => false)
          service_resources.each { |service_resource| resource_copy(service_resource, template) }
          custom_buttons.each { |custom_button| custom_button_copy(custom_button, template) }
          custom_button_sets.each { |custom_button_set| custom_button_set_copy(custom_button_set, template) }
        end.save!
      end
    end
  end

  def resource_copy(service_resource, template)
    resource = service_resource.resource.respond_to?(:service_template_resource_copy) ? service_resource.resource.service_template_resource_copy : service_resource.resource
    template.add_resource(resource, service_resource)
  end

  def custom_button_copy(custom_button, template)
    custom_button.copy(:applies_to => template)
  end

  def custom_button_set_copy(custom_button_set, template)
    custom_button_set.deep_copy(:owner => template)
  end
end
