class ApiController
  module ServiceTemplates
    #
    # ServiceTemplates Subcollection Supporting Methods
    #

    def service_templates_query_resource(object)
      klass = collection_class(:service_templates)
      object ? klass.where(:service_template_catalog_id => object.id) : {}
    end

    def service_templates_assign_resource(object, type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for Assigning a #{type} resource" unless id

      service_template_subcollection_action(type, id) do |st|
        api_log_info("Assigning #{service_template_ident(st)}")

        assign_service_template(object, st)
      end
    end

    def service_templates_unassign_resource(object, type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for Unassigning a #{type} resource" unless id

      service_template_subcollection_action(type, id) do |st|
        api_log_info("Unassigning #{service_template_ident(st)}")

        unassign_service_template(object, st)
      end
    end

    def service_templates_order_resource(_object, _type, id = nil, data = nil)
      klass = collection_class(:service_templates)
      options = {:dialog => {}, :src_id => id}
      unless data.nil?
        data.each do |key, value|
          dkey = "dialog_#{key}"
          options[:dialog][dkey] = value unless value.empty?
        end
      end

      klass.new.request_class.make_request(nil, options, @auth_user_obj)
    end

    private

    def service_template_ident(st)
      "Service Template id:#{st.id} name:'#{st.name}'"
    end

    def service_template_subcollection_action(type, id)
      klass = collection_class(:service_templates)
      result =
        begin
          st = resource_search(id, type, klass)
          yield(st) if block_given?
        rescue => err
          action_result(false, err.to_s)
        end
      add_subcollection_resource_to_result(result, type, st) if st
      add_parent_href_to_result(result)
      log_result(result)
      result
    end

    def assign_service_template(object, st)
      stcid = st.service_template_catalog_id
      if stcid
        action_result(stcid == object.id, "Service Template #{st.id} is currently assigned to Service Catalog #{stcid}")
      else
        object.service_templates << st
        action_result(true, "Assigning #{service_template_ident(st)}")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def unassign_service_template(object, st)
      stcid = st.service_template_catalog_id
      if stcid
        if stcid != object.id
          action_result(false, "Service Template #{st.id} is not currently assigned to Service Catalog #{stcid}")
        else
          object.service_templates -= Array.wrap(st)
          action_result(true, "Unassigning #{service_template_ident(st)}")
        end
      else
        action_result(true, "Service Template #{st.id} is not currently assigned to a Service Catalog")
      end
    rescue => err
      action_result(false, err)
    end
  end
end
