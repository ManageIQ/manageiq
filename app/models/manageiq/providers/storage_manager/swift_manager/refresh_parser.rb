module ManageIQ::Providers
  class StorageManager::SwiftManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
    extend ActiveSupport::Concern
    include Vmdb::Logging

    attr_accessor :data

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems               = ems
      @connection        = ems.connect
      @options           = options || {}
      @data              = {}
      @data_index        = {}

      @swift_service     = ems.parent_manager.swift_service
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      object_store

      $fog_log.info("#{log_header}...Complete")

      CrossLinkers.cross_link(@ems, @data)
      cleanup

      @data
    end

    def object_store
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

        # Temporarily add the tenant ID - for the cross-linkers.
        :tenant_id    => tenant.id # Because tenant comes from container.
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

        # Temporarily add the tenant ID - for the cross-linkers.
        :tenant_id      => tenant.id # Because tenant comes from container.
      }
      content = get_object_content(obj)
      new_result[:content] = content if content

      return uid, new_result
    end

    def get_object_content(_obj)
      # By default we don't want to fetch content of objects, redefine in parser as needed
      nil
    end

    def process_collection(collection, key, &block)
      @data[key] ||= []
      return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
      # save_call catches and ignores all Fog relation calls inside processing, causing allowed excon errors
      collection.each { |item| safe_call { process_collection_item(item, key, &block) } }
    end

    def process_collection_item(item, key)
      @data[key] ||= []

      uid, new_result = yield(item)

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
      new_result
    end

    def safe_call
      # Safe call wrapper for any Fog call not going through handled_list
      yield
    rescue Excon::Errors::Forbidden => err
      # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
      _log.warn("Forbidden response code returned in provider: #{@ems.address}. Message=#{err.message}")
      _log.log_backtrace(err, :warn)
      nil
    rescue Excon::Errors::NotFound => err
      # It can happen that some data do not exist anymore, in that case log warning but continue refresh
      _log.warn("Not Found response code returned in provider: #{@ems.address}. Message=#{err.message}")
      _log.log_backtrace(err, :warn)
      nil
    end

    alias safe_get safe_call

    def safe_list(&block)
      safe_call(&block) || []
    end

    def cleanup
      @data[:cloud_object_store_containers]&.each { |c| c.delete(:tenant_id) }
      @data[:cloud_object_store_objects]&.each    { |c| c.delete(:tenant_id) }
    end
  end
end
