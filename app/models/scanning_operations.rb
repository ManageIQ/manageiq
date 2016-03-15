require 'xmldata_helper'
require 'yaml'

# TODO: Determine if this file can be removed.
module ScanningOperations
  include Vmdb::Logging

  # TODO: Remove this method, ScanningOperationsMixin's copy of this method
  # should be used by methods in that module
  def self.reconnect_to_db
    _log.info("Reconnecting to database after error...")
    ActiveRecord::Base.connection.reconnect!
    _log.info("Reconnecting to database after error...Successful")
  rescue Exception => err
    _log.error("Error during reconnect: #{err.message}")
  end
end
