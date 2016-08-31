module Api
  class PoliciesController < BaseController
    include Subcollections::Conditions
    include Subcollections::Events
    include Subcollections::PolicyActions
  end
end
