class ManageIQ::Providers::StorageManager::Inventory::Collector::SwiftManager < ManageIQ::Providers::StorageManager::Inventory::Collector
  def swift_service
    @swift_service ||= manager.parent_manager&.swift_service
  end

  def directories
    @directories ||= swift_service.handled_list(:directories)
  end

  def files(directory)
    safe_list { directory.files }
  end

  private

  def safe_call
    # Safe call wrapper for any Fog call not going through handled_list
    yield
  rescue Excon::Errors::Forbidden => err
    # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
    _log.warn("Forbidden response code returned in provider: #{manager.address}. Message=#{err.message}")
    _log.log_backtrace(err, :warn)
    nil
  rescue Excon::Errors::NotFound => err
    # It can happen that some data do not exist anymore, in that case log warning but continue refresh
    _log.warn("Not Found response code returned in provider: #{manager.address}. Message=#{err.message}")
    _log.log_backtrace(err, :warn)
    nil
  end

  def safe_list(&block)
    safe_call(&block) || []
  end
end
