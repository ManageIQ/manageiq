module Api
  class AlertStatusesController < BaseController
    include Subcollections::AlertStatusStates
  end
end
