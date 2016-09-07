module Api
  class ServiceCatalogsController < BaseController
    include Subcollections::ServiceTemplates
  end
end
