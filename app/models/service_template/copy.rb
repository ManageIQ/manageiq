module ServiceTemplate::Copy
  extend ActiveSupport::Concern

  def template_copy(new_name = "Copy of " + name + Time.zone.now.to_s, copy_tags: false)
    if template_valid? && type != 'ServiceTemplateAnsiblePlaybook'
      ActiveRecord::Base.transaction do
        dup.tap do |template|
          template.update!(:name => new_name, :display => false, :options => {:button_order => []})
          service_resources.each { |service_resource| resource_copy(service_resource, template) }
          resource_action_copy(template)
          additional_tenant_copy(template)
          picture_copy(template) if picture
          tags_copy(template) if copy_tags
          direct_custom_buttons.each { |custom_button| custom_button_copy(custom_button, template) }
          custom_button_sets.each { |custom_button_set| custom_button_set_copy(custom_button_set, template) }
          template.save!
        end
      end
    end
  end

  private

  def additional_tenant_copy(template)
    template.additional_tenants << additional_tenants.dup
  end

  def custom_button_copy(custom_button, template)
    new_cb = custom_button.copy(:applies_to => template)
    template[:options][:button_order] << "cb-#{new_cb.id}"
  end

  def custom_button_set_copy(custom_button_set, template)
    new_cbs = custom_button_set.deep_copy(:owner => template)
    template[:options][:button_order] << "cbg-#{new_cbs.id}"
  end

  def picture_copy(template)
    template.picture = picture.dup
  end

  def resource_copy(service_resource, template)
    resource = service_resource.resource.respond_to?(:service_template_resource_copy) ? service_resource.resource.service_template_resource_copy : service_resource.resource
    template.add_resource(resource, service_resource)
  end

  def resource_action_copy(template)
    template.resource_actions << resource_actions.collect(&:dup)
  end

  def tags_copy(template)
    template.tags << tags.dup
  end
end
