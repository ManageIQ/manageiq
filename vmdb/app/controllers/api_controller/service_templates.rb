class ApiController
  module ServiceTemplates
    #
    # ServiceTemplates Subcollection Supporting Methods
    #

    def service_templates_query_resource(object)
      klass = collection_config[:service_templates][:klass].constantize
      object ? klass.where(:service_template_catalog_id => object.id) : {}
    end

    def service_templates_create_resource(object, _type, id = nil, _data = nil)
      service_templates_assign_resource(object, _type, id, _data)
    end

    def service_templates_assign_resource(object, _type, id = nil, _data = nil)
      klass = collection_config[:service_templates][:klass].constantize
      st    = klass.find(id)
      stcid = st.service_template_catalog_id
      if stcid
        raise BadRequestError, "Service Template #{id} is already assigned to Service Catalog #{stcid}"
      else
        st.update_attributes(:service_template_catalog_id => object.id)
      end

      if _data.has_key?('href')
        st['href'] = _data['href']
      end
      st
    end

    def service_templates_delete_resource(object, _type, id = nil, _data = nil)
      service_templates_unassign_resource(object, _type, id, _data)
    end

    def service_templates_unassign_resource(object, _type, id = nil, _data = nil)
      klass = collection_config[:service_templates][:klass].constantize
      st    = klass.find(id)
      stcid = st.service_template_catalog_id
      if stcid
        if stcid != object.id
          raise BadRequestError,
                "Service Template #{id} is not currently assigned to Service Catalog #{stcid}"
        else
          st.update_attributes(:service_template_catalog_id => nil)
        end
      end
      return st, :service_templates
    end

    # Method is called only when service_templates is a subcollection
    def service_templates_create_resource(_object, _type, id = nil, data = nil)
      service_templates_order_resource(_object, _type, id, data)
    end

    # Method for when service templates is a collection
    def order_resource_service_templates(_type, id = nil, data = nil)
      # first argument is nil since there is no parent object
      service_templates_order_resource(nil, _type, id, data)
    end

    def service_templates_order_resource(_object, _type, id = nil, data = nil)
      klass = collection_config[:service_templates][:klass].constantize
      st    = klass.find(id)

      requester_id     = @auth_user
      options          = {}
      options[:dialog] = {}

      unless data.nil?
        data.each do |key, value|
          dkey = "dialog_#{key}"
          options[:dialog][dkey] = value unless value.empty?
        end
      end

      request_type  = st.request_type.to_s
      request       = st.request_class.create!(:options      => options,
                                               :userid       => requester_id,
                                               :request_type => request_type,
                                               :source_id    => st.id)
      request.set_description
      request.create_request

      event_name    = "#{st.name.underscore}_created"
      event_message = "Request by [#{requester_id}] for #{st.class.name}:#{st.id}"
      AuditEvent.success(:event  => event_name,   :target_class => klass,
                         :userid => requester_id, :message      => event_message)

      request.call_automate_event_queue("request_created")
      request
    end
  end
end
