module Api
  class ServiceTemplatesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::ResourceActions
    include Subcollections::ServiceRequests

    before_action :set_additional_attributes, :only => [:show]

    def create_resource(_type, _id, data)
      catalog_item_type = ServiceTemplate.class_from_request_data(data)
      catalog_item_type.create_catalog_item(data.deep_symbolize_keys, @auth_user)
    rescue => err
      raise BadRequestError, "Could not create Service Template - #{err}"
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(config_info)
    end
  end
end
