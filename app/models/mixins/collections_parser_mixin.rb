module CollectionsParserMixin
  extend ActiveSupport::Concern

  # The "&block" defined here may have two behaviors:
  #   (item) -> (new_result) : new_result will be collected to @data under key.
  #   (item) -> (uid, new_result) : Will also insert new_result to @data_index to the path [key][uid]
  def process_collection(collection, key, &block)
    @data[key] ||= []
    return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
    # safe_call catches and ignores all Fog relation calls inside processing, causing allowed excon errors
    collection.each { |item| safe_call { process_collection_item(item, key, &block) } }
  end

  def process_collection_item(item, key)
    @data[key] ||= []

    uid, new_result = yield(item)
    if new_result
      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    else
      new_result = uid
      @data[key] << new_result
    end
    new_result
  end

  def safe_call
    # Safe call wrapper for any Fog call not going through handled_list
    yield
  rescue Excon::Errors::Forbidden => err
    # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
    _log.warn "Forbidden response code returned in provider: #{(@os_handle || @ems).address}. Message=#{err.message}"
    _log.warn err.backtrace.join("\n")
    nil
  rescue Excon::Errors::NotFound => err
    # It can happen that some data do not exist anymore,, in that case log warning but continue refresh
    _log.warn "Not Found response code returned in provider: #{(@os_handle || @ems).address}. Message=#{err.message}"
    _log.warn err.backtrace.join("\n")
    nil
  end

  alias safe_get safe_call

  def safe_list(&block)
    safe_call(&block) || []
  end
end
