class ApiController
  module ServiceDialogs
    #
    # Service Dialogs
    #

    def service_dialogs_query_resource(object)
      object ? object.dialogs : []
    end

    def show_service_dialogs
      @req[:additional_attributes] = %w(content) if attribute_selection == "all"
      show_generic(:service_dialogs)
    end
  end
end
