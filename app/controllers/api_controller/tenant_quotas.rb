class ApiController
  INVALID_QUOTA_ATTRS = %w(id href tenant_id unit).freeze

  module TenantQuotas
    #
    # Tenant Quotas Subcollection Supporting Methods
    #

    def quotas_create_resource(object, type, _id, data)
      bad_attrs = data.keys & INVALID_QUOTA_ATTRS
      errmsg = "Attributes %s should not be specified for creating a new tenant quota resource"
      raise(BadRequestError, errmsg % bad_attrs.join(", ")) if bad_attrs.any?

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
      bad_attrs = data.keys & INVALID_QUOTA_ATTRS
      errmsg = "Attributes %s should not be specified for updating a quota resource"
      raise(BadRequestError, errmsg % bad_attrs.join(", ")) if bad_attrs.any?

      edit_resource(type, id, data)
    end

    def delete_resource_quotas(_object, type, id, data)
      delete_resource(type, id, data)
    end

    def quotas_delete_resource(_object, type, id, data)
      delete_resource(type, id, data)
    end
  end
end
