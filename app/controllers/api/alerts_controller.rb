module Api
  class AlertsController < BaseController
    include Subcollections::AlertActions
  end
end
