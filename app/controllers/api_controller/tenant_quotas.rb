class ApiController
  INVALID_QUOTA_ATTRS = %w(id href tenant_id unit).freeze

  module TenantQuotas
    #
    # Tenant Quotas Subcollection Supporting Methods
    #

    def quotas_create_resource(object, type, _id, data)
      bad_attrs = data_includes_invalid_attrs(data)
      if bad_attrs.present?
        raise BadRequestError,
              "Attribute(s) #{bad_attrs} should not be specified for creating a new tenant resource"
      end

      data['tenant_id'] = object.id
      quota = collection_class(type).create(data)
      if quota.invalid?
        raise BadRequestError, "Failed to add a new tenant quota resource - #{quota.errors.full_messages.join(', ')}"
      end
      quota
    end

    def quotas_query_resource(object)
      klass = collection_class(:quotas)
      object ? klass.where(:tenant_id => object.id) : {}
    end

    def quotas_edit_resource(_object, type, id, data)
      bad_attrs = data_includes_invalid_attrs(data)
      if bad_attrs.present?
        raise BadRequestError, "Attributes #{bad_attrs} should not be specified for updating a quota resource"
      end
      edit_resource(type, id, data)
    end

    def delete_resource_quotas(_object, type, id, data)
      delete_resource(type, id, data)
    end

    def quotas_delete_resource(_object, type, id, data)
      delete_resource(type, id, data)
    end

    private

    def data_includes_invalid_attrs(data)
      data.keys.select { |k| INVALID_QUOTA_ATTRS.include?(k) }.compact.join(", ") if data
    end
  end
end
