module MiqSearch::ImportExport
  extend ActiveSupport::Concern

  def export_to_array
    export_attributes = attributes.except('id')
    [self.class.to_s => export_attributes]
  end
end
