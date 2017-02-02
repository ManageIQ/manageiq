module Api
  class BaseController
    module Generic
      #
      # Primary Methods
      #

      def index
        klass = collection_class(@req.subject)
        res = collection_search(@req.subcollection?, @req.subject, klass)
        opts = {
          :name             => @req.subject,
          :is_subcollection => @req.subcollection?,
          :expand_actions   => true,
          :count            => klass.count,
          :expand_resources => @req.expand?(:resources),
          :subcount         => res.length
        }

        render_collection(@req.subject, res, opts)
      end

      def show
        klass = collection_class(@req.subject)
        opts  = {:name => @req.subject, :is_subcollection => @req.subcollection?, :expand_actions => true}
        render_resource(@req.subject, resource_search(@req.subject_id, @req.subject, klass), opts)
      end

      def update
        render_normal_update @req.collection.to_sym, update_collection(@req.subject.to_sym, @req.subject_id)
      end

      def destroy
        if @req.subcollection?
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
        resource = klass.new(data)
        if resource.save
          add_subcollection_data_to_resource(resource, type, subcollection_data)
          resource
        else
          raise BadRequestError, "Failed to add a new #{type} resource - #{resource.errors.full_messages.join(', ')}"
        end
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
          :expand_resources => true,
          :expand_actions   => true
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

      def validate_id(id, klass)
        raise NotFoundError, "Invalid #{klass} id #{id} specified" unless id.kind_of?(Integer) || id =~ /\A\d+\z/
      end
    end
  end
end
