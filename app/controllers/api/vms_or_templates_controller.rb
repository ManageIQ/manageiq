module Api
  class VmsOrTemplatesController < BaseController
    include Subcollections::Policies
    include Subcollections::PolicyProfiles
    include Subcollections::Tags
  end
end
