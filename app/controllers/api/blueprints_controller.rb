module Api
  class BlueprintsController < BaseController
    include Subcollections::Tags

    before_action :set_additional_attributes, :only => [:show]

    def create_resource(_type, _id, data)
      raise BadRequestError unless data['ui_properties']
      validate_ui_properties(data['ui_properties'])
      Blueprint.create!(data)
    end

    def edit_resource(type, id, data)
      validate_ui_properties(data['ui_properties']) if data['ui_properties']
      blueprint = resource_search(id, type, Blueprint)
      blueprint.update!(data)
      blueprint
    end

    def publish_resource(type, id, data)
      blueprint = resource_search(id, type, Blueprint)
      blueprint.publish(data['bundle_name'])
      blueprint
    end

    private

    def validate_ui_properties(ui_properties)
      raise BadRequestError unless ui_properties.key?('service_catalog') &&
                                   ui_properties.key?('service_dialog') &&
                                   ui_properties.key?('automate_entrypoints') && ui_properties.key?('ChartDataModel')
    end

    def set_additional_attributes
      @additional_attributes = %w(content)
    end

  end
end
