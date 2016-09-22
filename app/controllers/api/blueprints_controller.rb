module Api
  class BlueprintsController < BaseController
    include Subcollections::Tags

    before_action :set_additional_attributes, :only => [:show]

    def publish_resource(type, id, data)
      blueprint = resource_search(id, type, Blueprint)
      blueprint.publish(data['bundle_name'])
      blueprint
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(content)
    end
  end
end
