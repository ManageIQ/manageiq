module Api
  class ServiceCatalogsController < BaseController
    include Shared::DialogFields
    include Subcollections::ServiceTemplates
  end
end
