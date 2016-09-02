module Api
  class TemplatesController < BaseController
    include Subcollections::Policies
    include Subcollections::PolicyProfiles
  end
end
