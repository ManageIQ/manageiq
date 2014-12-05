class ApiController
  module Generic
    #
    # Primary Methods
    #

    def show_generic(type)
      if @req[:subcollection]
        render_collection_type @req[:subcollection].to_sym, @req[:s_id], true
      else
        render_collection_type type, @req[:c_id]
      end
    end

    def update_generic(type)
      validate_api_action
      if @req[:subcollection]
        render_normal_update type, update_collection(@req[:subcollection].to_sym, @req[:s_id], true)
      else
        render_normal_update type, update_collection(type, @req[:c_id])
      end
    end

    def destroy_generic(type)
      validate_api_action
      if @req[:subcollection]
        delete_subcollection_resource @req[:subcollection].to_sym, @req[:s_id]
      else
        send(target_resource_method(false, type, :delete), type, @req[:c_id])
      end
      render_normal_destroy
    end

    #
    # Action Helper Methods
    #
    # Name: <action>_resource
    # Args: collection type, resource id, optional data
    #
    # For type specified, name is <action>_resource_<collection>
    # Same signature.
    #
    def add_resource(type, _id, data)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new #{type} resource"
      end
      subcollections     = cspec[:subcollections]
      subcollection_data = subcollections.each_with_object({}) do |sc, hash|
        if data.key?(sc.to_s)
          hash[sc] = data[sc.to_s]
          data.delete(sc.to_s)
        end
      end
      rsc = klass.create(data)
      raise BadRequestError, "Failed to add a new #{type} resource" if rsc.id.nil?
      rsc.save
      add_subcollection_data_to_resource(rsc, type, subcollection_data)
      klass.find(rsc.id)
    end

    def edit_resource(type, id, data)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      resource = resource_search(id, type, klass)
      resource.update_attributes(data.except("id", "href"))
      resource
    end

    def delete_resource(type, id = nil, _data = nil)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      id  ||= @req[:c_id]
      raise BadRequestError, "Must specify and id for deleting a #{type} resource" unless id
      api_log_info("Deleting #{type} id #{id}")
      resource_search(id, type, klass)
      delete_resource_action(klass, type, id)
    end

    def retire_resource(type, id, data = nil)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      if id
        msg = "Retiring #{type} id #{id}"
        resource = resource_search(id, type, klass)
        if data && data["date"]
          opts = {}
          opts[:date] = data["date"]
          opts[:warn] = data["warn"] if data["warn"]
          msg << " on: #{opts}"
          api_log_info(msg)
          resource.retire(opts)
        else
          msg << " immediately."
          api_log_info(msg)
          resource.retire_now
        end
        resource
      else
        raise BadRequestError, "Must specify and id for retiring a #{type} resource"
      end
    end

    private

    def add_subcollection_data_to_resource(resource, type, subcollection_data)
      subcollection_data.each do |sc, sc_data|
        typed_target = "#{sc}_assign_resource"
        raise BadRequestError, "Cannot assign #{sc} to a #{type} resource" unless respond_to?(typed_target)
        sc_data.each do |sr|
          unless sr.blank?
            collection, rid = parse_href(sr["href"])
            if collection == sc && rid
              sr.delete("id")
              sr.delete("href")
            end
            send(typed_target, resource, type, rid.to_i, sr)
          end
        end
      end
    end

    def delete_resource_action(klass, type, id)
      result = begin
          klass.destroy(id)
          action_result(true, "#{type} id: #{id} deleting")
        rescue => err
          action_result(false, err.to_s)
        end
      add_href_to_result(result, type, id)
      log_result(result)
      result
    end
  end
end
