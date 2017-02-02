module Api
  class ServiceTemplatesController < BaseController
    include Shared::DialogFields
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::ResourceActions
    include Subcollections::ServiceRequests
  end
end
