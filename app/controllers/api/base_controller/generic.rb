module Api
  class BaseController
    module Generic
      #
      # Primary Methods
      #

      def show
        if @req.subcollection
          render_collection_type @req.subcollection.to_sym, @req.s_id, true
        else
          render_collection_type @req.collection.to_sym, @req.c_id
        end
      end

      def update
        if @req.subcollection
          render_normal_update @req.collection.to_sym, update_collection(@req.subcollection.to_sym, @req.s_id, true)
        else
          render_normal_update @req.collection.to_sym, update_collection(@req.collection.to_sym, @req.c_id)
        end
      end

      def destroy
        if @req.subcollection
          delete_subcollection_resource @req.subcollection.to_sym, @req.s_id
        else
          delete_resource(@req.collection.to_sym, @req.c_id)
        end
        render_normal_destroy
      end

      def options
        render_options(@req.collection)
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
        assert_id_not_specified(data, "#{type} resource")
        klass = collection_class(type)
        subcollection_data = collection_config.subcollections(type).each_with_object({}) do |sc, hash|
          if data.key?(sc.to_s)
            hash[sc] = data[sc.to_s]
            data.delete(sc.to_s)
          end
        end
        rsc = klass.create(data)
        if rsc.id.nil?
          raise BadRequestError, "Failed to add a new #{type} resource - #{rsc.errors.full_messages.join(', ')}"
        end
        rsc.save
        add_subcollection_data_to_resource(rsc, type, subcollection_data)
        klass.find(rsc.id)
      end

      alias_method :create_resource, :add_resource

      def query_resource(type, id, data)
        unless id
          data_spec = data.collect { |key, val| "#{key}=#{val}" }.join(", ")
          raise NotFoundError, "Invalid #{type} resource specified - #{data_spec}"
        end
        resource = resource_search(id, type, collection_class(type))
        opts = {
          :name             => type.to_s,
          :is_subcollection => false,
          :resource_actions => "resource_actions_#{type}",
          :expand_resources => true
        }
        resource_to_jbuilder(type, type, resource, opts).attributes!
      end

      def edit_resource(type, id, data)
        klass = collection_class(type)
        resource = resource_search(id, type, klass)
        resource.update_attributes!(data.except(*ID_ATTRS))
        resource
      end

      def delete_resource(type, id = nil, _data = nil)
        klass = collection_class(type)
        id ||= @req.c_id
        raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id
        api_log_info("Deleting #{type} id #{id}")
        resource_search(id, type, klass)
        delete_resource_action(klass, type, id)
      end

      def retire_resource(type, id, data = nil)
        klass = collection_class(type)
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
          raise BadRequestError, "Must specify an id for retiring a #{type} resource"
        end
      end
      alias generic_retire_resource retire_resource

      def custom_action_resource(type, id, data = nil)
        action = @req.action.downcase
        id ||= @req.c_id
        if id.blank?
          raise BadRequestError, "Must specify an id for invoking the custom action #{action} on a #{type} resource"
        end

        api_log_info("Invoking #{action} on #{type} id #{id}")
        resource = resource_search(id, type, collection_class(type))
        unless resource_custom_action_names(resource).include?(action)
          raise BadRequestError, "Unsupported Custom Action #{action} for the #{type} resource specified"
        end
        invoke_custom_action(type, resource, action, data)
      end

      def set_ownership_resource(type, id, data = nil)
        raise BadRequestError, "Must specify an id for setting ownership of a #{type} resource" unless id
        raise BadRequestError, "Must specify an owner or group for setting ownership data = #{data}" if data.blank?

        api_action(type, id) do |klass|
          resource_search(id, type, klass)
          api_log_info("Setting ownership to #{type} #{id}")
          ownership = parse_ownership(data)
          set_ownership_action(klass, type, id, ownership)
        end
      end

      def refresh_dialog_fields_action(dialog, refresh_fields, resource_ident)
        result = {}
        refresh_fields.each do |field|
          dynamic_field = dialog.field(field)
          return action_result(false, "Unknown dialog field #{field} specified") unless dynamic_field
          result[field] = dynamic_field.update_and_serialize_values
        end
        action_result(true, "Refreshing dialog fields for #{resource_ident}", :result => result)
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

      def invoke_custom_action(type, resource, action, data)
        custom_button = resource_custom_action_button(resource, action)
        if custom_button.resource_action.dialog_id
          return invoke_custom_action_with_dialog(type, resource, action, data, custom_button)
        end

        result = begin
                   custom_button.invoke(resource)
                   action_result(true, "Invoked custom action #{action} for #{type} id: #{resource.id}")
                 rescue => err
                   action_result(false, err.to_s)
                 end
        add_href_to_result(result, type, resource.id)
        log_result(result)
        result
      end

      def invoke_custom_action_with_dialog(type, resource, action, data, custom_button)
        result = begin
                   wf_result = submit_custom_action_dialog(resource, custom_button, data)
                   action_result(true,
                                 "Invoked custom dialog action #{action} for #{type} id: #{resource.id}",
                                 :result => wf_result[:request])
                 rescue => err
                   action_result(false, err.to_s)
                 end
        add_href_to_result(result, type, resource.id)
        log_result(result)
        result
      end

      def submit_custom_action_dialog(resource, custom_button, data)
        wf = ResourceActionWorkflow.new({}, @auth_user_obj, custom_button.resource_action, :target => resource)
        data.each { |key, value| wf.set_value(key, value) } if data.present?
        wf_result = wf.submit_request
        raise StandardError, Array(wf_result[:errors]).join(", ") if wf_result[:errors].present?
        wf_result
      end

      def resource_custom_action_button(resource, action)
        resource.custom_action_buttons.find { |b| b.name.downcase == action.downcase }
      end

      def set_ownership_action(klass, type, id, ownership)
        if ownership.blank?
          action_result(false, "Must specify a valid owner or group for setting ownership")
        else
          result = klass.set_ownership([id], ownership)
          details = ownership.each.collect { |key, obj| "#{key}: #{obj.name}" }.join(", ")
          desc = "setting ownership of #{type} id #{id} to #{details}"
          result == true ? action_result(true, desc) : action_result(false, result.values.join(", "))
        end
      rescue => err
        action_result(false, err.to_s)
      end

      def service_template_workflow(service_template, service_request)
        resource_action = service_template.resource_actions.find_by_action("Provision")
        workflow = ResourceActionWorkflow.new({}, @auth_user_obj, resource_action, :target => service_template)
        service_request.each { |key, value| workflow.set_value(key, value) } if service_request.present?
        workflow
      end

      def validate_id(id, klass)
        raise NotFoundError, "Invalid #{klass} id #{id} specified" unless id.kind_of?(Integer) || id =~ /\A\d+\z/
      end
    end
  end
end
