module ServiceTemplate::Copy
  extend ActiveSupport::Concern

  def template_copy(new_name = "Copy of " + name + Time.zone.now.to_s)
    if template_valid? && type != 'ServiceTemplateAnsiblePlaybook'
      ActiveRecord::Base.transaction do
        dup.tap do |template|
          template.update_attributes(:name => new_name, :display => false)
          service_resources.each do |sr|
            resource = sr.resource.respond_to?(:service_template_resource_copy) ? sr.resource.service_template_resource_copy : sr.resource
            template.add_resource(resource, sr)
          end
        end.save!
      end
    end
  end
end
