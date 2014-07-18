class ApiController
  module Manager
    def update_collection(type, id, is_subcollection = false)
      if @req[:method] == :put || @req[:method] == :patch
        raise BadRequestError,
              "Must specify a resource id for the #{@req[:method]} HTTP method" if id.blank?
        return send("#{@req[:method]}_resource", type, id)
      end

      action = @req[:action]
      target = target_resource_method(is_subcollection, type, action)
      raise BadRequestError,
            "Unimplemented Action #{action} for #{type} resources" unless respond_to?(target)

      if id
        get_and_update_one_collection(is_subcollection, target, type, id)
      else
        get_and_update_multiple_collections(is_subcollection, target, type)
      end
    end

    def parent_resource_obj
      type  = @req[:collection].to_sym
      klass = collection_config[type][:klass].constantize
      resource_search(@req[:c_id], type, klass)
    end

    def put_resource(type, id)
      edit_resource(type, id, json_body)
    end

    #
    # Patching a resource, post syntax
    #
    # [
    #   {
    #     "action" : "add" | "edit" | "remove"
    #     "path" : "attribute_name",
    #     "value" : "value to add or edit"
    #   }
    #   ...
    # ]
    #
    def patch_resource(type, id)
      patched_attrs = {}
      json_body.each do |patch_cmd|
        action = patch_cmd["action"]
        path   = patch_cmd["path"]
        value  = patch_cmd["value"]
        if action.nil?
          api_log_info("Must specify an attribute action for each path command for the resource #{type}/#{id}")
        elsif path.nil?
          api_log_info("Must specify an attribute path for each patch method action for the resource #{type}/#{id}")
        elsif path.split('/').size > 1
          api_log_info("Can only patch attributes of the resource #{type}/#{id}")
        else
          attr = path.split('/')[0]
          patched_attrs[attr] = value if %w(edit add).include?(action)
          patched_attrs[attr] = nil if action == "remove"
        end
      end
      edit_resource(type, id, patched_attrs)
    end

    def delete_subcollection_resource(type, id = nil)
      raise BadRequestError,
            "Must specify and id for destroying a #{type} subcollection resource" if id.nil?

      parent_resource = parent_resource_obj
      typed_target    = "delete_resource_#{type}"
      raise BadRequestError,
            "Cannot delete subcollection resources of type #{type}" unless respond_to?(typed_target)

      resource = json_body["resource"]
      resource = {"href" => "#{@req[:base]}#{@req[:path]}"} if !resource || resource.empty?
      send(typed_target, parent_resource, type, id.to_i, resource)
    end

    private

    def target_resource_method(is_subcollection, type, action)
      if is_subcollection
        "#{type}_#{action}_resource"
      else
        target = "#{action}_resource"
        typed_target = "#{target}_#{type}"
        respond_to?(typed_target) ? typed_target : target
      end
    end

    def get_and_update_one_collection(is_subcollection, target, type, id)
      resource = json_body_resource
      update_one_collection(is_subcollection, target, type, id, resource) unless resource.blank?
    end

    def get_and_update_multiple_collections(is_subcollection, target, type)
      resources = []
      if json_body.key?("resources")
        resources += json_body["resources"]
      else
        resources << json_body_resource
      end
      update_multiple_collections(is_subcollection, target, type, resources)
    end

    def json_body_resource
      resource = json_body["resource"]
      unless resource
        resource = json_body.dup
        resource.delete("action")
      end
      resource
    end

    def update_one_collection(is_subcollection, target, type, id, resource)
      parent_resource = parent_resource_obj if is_subcollection
      if is_subcollection
        send(target, parent_resource, type, id.to_i, resource)
      else
        send(target, type, id.to_i, resource)
      end
    end

    def update_multiple_collections(is_subcollection, target, type, resources)
      action = @req[:action]

      processed = 0
      results = resources.each.collect do |r|
        next if r.blank?

        collection, rid = parse_href(r["href"])
        r.except!("id", "href") if collection == type && rid
        processed += 1
        update_one_collection(is_subcollection, target, type, rid, r)
      end
      raise BadRequestError, "No #{type} resources were specified for the #{action} action" if processed == 0
      {"results" => results}
    end
  end
end
