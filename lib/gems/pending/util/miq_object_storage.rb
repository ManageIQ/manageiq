require 'net/protocol'
require 'util/miq_file_storage'

class MiqObjectStorage < MiqFileStorage::Interface
  require 'util/object_storage/miq_s3_storage'
  require 'util/object_storage/miq_ftp_storage'
  require 'util/object_storage/miq_swift_storage'

  attr_accessor :settings
  attr_writer   :logger

  DEFAULT_CHUNKSIZE = Net::BufferedIO::BUFSIZE

  def initialize(settings)
    raise "URI missing" unless settings.key?(:uri)
    @settings = settings.dup
  end

  def logger
    @logger ||= $log.nil? ? :: Logger.new(STDOUT) : $log
  end

  private

  DONE_READING = ""
  def read_single_chunk(chunksize = DEFAULT_CHUNKSIZE)
    @buf_left ||= byte_count
    return DONE_READING unless @buf_left.nil? || @buf_left.positive?
    cur_readsize = if (@buf_left.nil? || @buf_left - chunksize >= 0)
                     chunksize
                   else
                     @buf_left
                   end
    buf = source_input.read(cur_readsize)
    @buf_left -= chunksize if @buf_left
    buf.to_s
  end

  def write_single_split_file_for(file_io)
    loop do
      input_data = read_single_chunk
      break if input_data.empty?
      file_io.write(input_data)
    end
    clear_split_vars
  end

  def clear_split_vars
    @buf_left = nil
  end
end
