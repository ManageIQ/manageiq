module Api
  class TemplatesController < BaseController
    include Subcollections::Policies
    include Subcollections::PolicyProfiles
    include Subcollections::Tags
  end
end
