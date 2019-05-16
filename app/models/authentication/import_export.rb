module Authentication::ImportExport
  extend ActiveSupport::Concern

  def export_to_array
    export_attributes = attributes.except('id', 'created_on', 'updated_on', 'resource_id', 'resource_type', 'credentials_changed_on', 'last_invalid_on', 'status', 'status_details', 'password')
    export_attributes['miq_group_description'] = MiqGroup.find(export_attributes['miq_group_id'])&.description
    export_attributes['tenant_name'] = Tenant.find(export_attributes['tenant_id'])&.name

    [self.class.to_s => export_attributes]
  end
end
