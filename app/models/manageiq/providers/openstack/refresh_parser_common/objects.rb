module ManageIQ::Providers
  module Openstack
    module RefreshParserCommon
      module Objects
        def get_object_store
          return if @storage_service.blank? || @storage_service.name != :swift
          # TODO(lsmola) convert to handled_list, we will probably need tenant setter on Fog::Model, so we can pass it
          # in object
          @os_handle.service_for_each_accessible_tenant('Storage') do |svc, tenant|
            svc.directories.each do |dir|
              result = process_collection_item(dir, :cloud_object_store_containers) { |c| parse_container(c, tenant) }
              process_collection(dir.files, :cloud_object_store_objects) { |o| parse_object(o, result, tenant) }
            end
          end
        end

        def parse_container(container, tenant)
          uid = "#{tenant.id}/#{container.key}"
          new_result = {
            :ems_ref      => uid,
            :key          => container.key,
            :object_count => container.count,
            :bytes        => container.bytes,
            :tenant       => @data_index.fetch_path(:cloud_tenants, tenant.id)
          }
          return uid, new_result
        end

        def parse_object(obj, container, tenant)
          uid = obj.key
          new_result = {
            :ems_ref        => uid,
            :etag           => obj.etag,
            :last_modified  => obj.last_modified,
            :content_length => obj.content_length,
            :key            => obj.key,
            :content_type   => obj.content_type,
            :container      => container,
            :tenant         => @data_index.fetch_path(:cloud_tenants, tenant.id)
          }
          content = get_object_content(obj)
          new_result.merge!(:content => content) if content

          return uid, new_result
        end

        def get_object_content(_obj)
          # By default we don't want to fetch content of objects, redefine in parser as needed
          nil
        end
      end
    end
  end
end
