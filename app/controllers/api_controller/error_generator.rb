class ApiController
  module ErrorGenerator
    def raise_failed_to_add_resource_error(type, resource)
      raise BadRequestError, "Failed to add a new #{type} resource - #{resource.errors.full_messages.join(', ')}"
    end

    def raise_resource_id_or_href_specified_error(type)
      raise BadRequestError, "Resource id or href should not be specified for creating a new #{type} resource"
    end

    def raise_could_not_find_resource_error(type, data)
      resource_rep = data.map { |k, v| "#{k} = #{v}"}.join(', ')
      raise BadRequestError, "Could not find #{type} with data #{resource_rep}"
    end

    def raise_could_not_find_resource_by_id_error(type, id)
      raise BadRequestError, "Failed to find #{type}/#{id} resource"
    end

    def raise_parent_id_or_href_not_specified_error(parent_type, type)
      raise BadRequestError,
            "#{parent_type.to_s.capitalize} id or href needs to be specified for creating a new #{type} resource"
    end

    def raise_must_specify_id_for_deletion_error(type)
      raise BadRequestError, "Must specify an id for deleting a #{type} resource"
    end

    def raise_must_specify_id_for_retiring_error(type)
      raise BadRequestError, "Must specify an id for retiring a #{type} resource"
    end

    def raise_must_specify_id_for_custom_action_error(action, type)
      raise BadRequestError, "Must specify an id for invoking the custom action #{action} on a #{type} resource"
    end

    def raise_unsupported_custom_action_error(action, type)
      raise BadRequestError, "Unsupported Custom Action #{action} for the #{type} resource specified"
    end

    def raise_must_specify_id_for_setting_ownership_error(type)
      raise BadRequestError, "Must specify an id for setting ownership of a #{type} resource"
    end

    def raise_must_specify_owner_for_setting_ownership_error(data)
      raise BadRequestError, "Must specify an owner or group for setting ownership data = #{data}"
    end

    def raise_cannot_assign_subcollection_error(subcollection, type)
      raise BadRequestError, "Cannot assign #{subcollection} to a #{type} resource"
    end
  end
end
