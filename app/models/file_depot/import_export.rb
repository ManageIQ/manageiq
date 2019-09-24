module FileDepot::ImportExport
  extend ActiveSupport::Concern

  def export_to_array
    export_attributes = attributes.except('id', 'created_at', 'updated_at')
    export_attributes['AuthenticationsContent'] = authentications.map(&:export_to_array)
    [self.class.to_s => export_attributes]
  end
end
