module Api
  class BlueprintsController < BaseController
    include Subcollections::Tags

    before_action :set_additional_attributes, :only => [:index, :show]

    def publish_resource(type, id, data)
      blueprint = resource_search(id, type, Blueprint)
      begin
        blueprint.publish(data['bundle_name'])
      rescue => err
        raise BadRequestError, "Failed to publish blueprint - #{err}"
      end
      blueprint
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(content)
    end
  end
end
