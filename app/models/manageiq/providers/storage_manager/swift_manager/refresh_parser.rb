module ManageIQ::Providers
  class StorageManager::SwiftManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
    include Vmdb::Logging

    attr_accessor :data, :parser

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      log_header = "MIQ(#{self.class.name}.#{__method__}) Initializing Swift for EMS name: [#{@ems.name}] id: [#{@ems.id}]"
      $fog_log.info("#{log_header}...")
      @ems               = ems
      @connection        = ems.connect
      @options           = options || {}
      @data              = {}
      @data_index        = {}

      @os_handle         = ems.openstack_handle
      @swift_service     = @os_handle.detect_storage_service

      validate_required_services
      $fog_log.info("#{log_header}...Complete")
    end

    def validate_required_services
      unless @swift_service
        raise MiqException::MiqSwiftServiceMissing, "Required service Swift is missing."
      end
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      get_object_store

      $fog_log.info("#{log_header}...Complete")

      @data
    end

    def get_object_store
      return if @swift_service.blank? || @swift_service.name != :swift

      @swift_service.handled_list(:directories).each do |dir|
        result = process_collection_item(dir, :cloud_object_store_containers) { |c| parse_container(c, dir.project) }
        files = safe_list { dir.files }
        process_collection(files, :cloud_object_store_objects) { |o| parse_object(o, result, dir.project) }
      end
    end

    private

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

    def get_object_content(obj)
      obj.body
    end
  end
end
