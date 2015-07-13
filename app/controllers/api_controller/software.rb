class ApiController
  module Software
    #
    # Software Subcollection Supporting Methods
    #
    def software_query_resource(object)
      object.send("guest_applications")
    end
  end
end
