module Api
  class TemplatesController < BaseController
    include Shared::Ownable
    include Subcollections::Policies
    include Subcollections::PolicyProfiles
    include Subcollections::Tags
  end
end
