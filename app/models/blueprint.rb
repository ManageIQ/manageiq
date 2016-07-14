class Blueprint < ApplicationRecord
  has_many :service_templates
  private  :service_templates, :service_templates=

  # the top of the service_templates, a bundle that contains child items
  def bundle
    service_templates.find { |st| st.parent_services.blank? }
  end

  # The new blueprint is saved before returning
  def deep_copy(new_attributes = {})
    self.class.transaction do
      dup.tap do |blueprint|
        # TODO: there may be other attributes that need to be reset for the new template
        new_attributes.reverse_merge(:status => nil).each do |attr, value|
          blueprint.send("#{attr}=", value)
        end
        copy_service_template(blueprint, bundle, true)
        blueprint.save!
      end
    end
  end

  private

  # Copy a service template and link its blueprint;
  # It can be used to copy service_templates into a new blueprint
  # or copy the bundle from one blueprint to another
  # The resulting service template is saved before returning;
  # is_top is true only when copying the bundle of a blueprint
  def copy_service_template(blueprint, service_template, is_top = false, new_attributes = {})
    service_template.dup.tap do |new_template|
      duplicate_resource_actions(service_template, new_template, is_top)
      duplicate_service_resources(blueprint, service_template, new_template)
      update_copied_service_template(blueprint, new_template, new_attributes)
    end
  end

  def duplicate_resource_actions(old_template, new_template, is_top)
    dialog_map = {}
    new_template.resource_actions = old_template.resource_actions.collect do |old_action|
      old_action.dup.tap do |new_action|
        old_dialog = old_action.dialog
        new_dialog = ensure_new_dialog(dialog_map, old_dialog) if old_dialog && is_top
        new_action.dialog = new_dialog # either a new dialog or nil
      end
    end
  end

  def ensure_new_dialog(dialog_map, old_dialog)
    new_dialog = dialog_map[old_dialog.id]
    unless new_dialog
      new_dialog = old_dialog.deep_copy(:name => random_dialog_name(old_dialog.name)).tap(&:save!)
      dialog_map[old_dialog.id] = new_dialog
    end
    new_dialog
  end

  def random_dialog_name(prefix)
    "#{prefix}_#{rand(36**8).to_s(36)}"
  end

  def duplicate_service_resources(blueprint, old_template, new_template)
    new_template.service_resources = old_template.service_resources.collect do |sr|
      sr.dup.tap do |new_sr|
        resource = sr.resource
        if resource.kind_of?(ServiceTemplate)
          new_sr.resource = copy_service_template(blueprint, resource)
        elsif !provider_resource?(resource)
          new_sr.resource = resource.dup.tap(&:save!)
        end
      end
    end
  end

  def provider_resource?(resource)
    resource.respond_to?(:ems_ref) || resource.kind_of?(ExtManagementSystem)
  end

  def update_copied_service_template(blueprint, new_template, new_attributes)
    new_template.blueprint = blueprint
    new_template.display = false

    new_attributes.each do |attr, value|
      new_template.send("#{attr}=", value)
    end

    new_template.save!
  end
end
