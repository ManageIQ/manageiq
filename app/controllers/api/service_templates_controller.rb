module Api
  class ServiceTemplatesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::ResourceActions
    include Subcollections::ServiceRequests

    before_action :set_additional_attributes, :only => [:index, :show]

    private

    def set_additional_attributes
      @additional_attributes = %w(config_info)
    end
  end
end
