module ManageIQ
  module API
    class BaseController
      module Software
        #
        # Software Subcollection Supporting Methods
        #
        def software_query_resource(object)
          object.guest_applications
        end
      end
    end
  end
end
