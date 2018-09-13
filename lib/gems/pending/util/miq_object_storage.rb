require 'util/miq_file_storage'

class MiqObjectStorage < MiqFileStorage::Interface
  require 'util/object_storage/miq_s3_storage'
  require 'util/object_storage/miq_ftp_storage'

  attr_accessor :settings
  attr_writer   :logger

  def initialize(settings)
    raise "URI missing" unless settings.key?(:uri)
    @settings = settings.dup
  end

  def logger
    @logger ||= $log.nil? ? :: Logger.new(STDOUT) : $log
  end
end
