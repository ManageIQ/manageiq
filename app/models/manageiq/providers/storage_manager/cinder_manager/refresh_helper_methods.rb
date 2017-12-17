module ManageIQ::Providers::StorageManager::CinderManager::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key, &block)
    @data[key] ||= []
    return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
    # safe_call catches and ignores all Fog relation calls inside processing, causing allowed excon errors
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
    _log.warn("Forbidden response code returned in provider: #{@os_handle.address}. Message=#{err.message}")
    _log.log_backtrace(err, :warn)
    nil
  rescue Excon::Errors::NotFound => err
    # It can happen that some data do not exist anymore,, in that case log warning but continue refresh
    _log.warn("Not Found response code returned in provider: #{@os_handle.address}. Message=#{err.message}")
    _log.log_backtrace(err, :warn)
    nil
  end

  alias safe_get safe_call

  def safe_list(&block)
    safe_call(&block) || []
  end
end
