class Api::BaseController
  module Software
    #
    # Software Subcollection Supporting Methods
    #
    def software_query_resource(object)
      object.guest_applications
    end
  end
end
