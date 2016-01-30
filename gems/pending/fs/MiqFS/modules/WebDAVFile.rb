require 'net/http'

class WebDAVFile
  def initialize(uri, verify_mode, headers)
    @uri = uri
    @headers = headers
    @offset = 0
    @connection = Net::HTTP.start(
      @uri.host,
      @uri.port,
      :use_ssl     => @uri.scheme == 'https',
      :verify_mode => verify_mode
    )
  end

  def seek(offset, whence)
    case whence
    when IO::SEEK_SET
      @offset = offset
    when IO::SEEK_CUR
      @offset += offset
    else
      raise NotImplementedError
    end
  end

  def read(length)
    @next_offset = @offset + length

    request = Net::HTTP::Get.new(@uri, @headers)
    request.set_range(@offset, @next_offset)

    response = @connection.request(request)

    case response
    when Net::HTTPOK
      # In this case (server not supporting ranges) the communication
      # is highly inefficient.
      data = response.body[@offset..@next_offset]
    when Net::HTTPPartialContent
      data = response.body
    else
      raise Errno::ENOENT
    end

    @offset = @next_offset
    data
  end

  def size
    self.class.file_size(@connection, @uri, @headers)
  end

  def self.head_response(connection, uri, headers)
    request = Net::HTTP::Head.new(uri, headers)
    connection.request(request)
  end

  def self.file_size(connection, uri, headers)
    response = head_response(connection, uri, headers)
    raise Errno::ENOENT unless response.kind_of?(Net::HTTPOK)
    raise Errno::EINVAL if response["content-length"].nil?
    response["content-length"].to_i
  end

  def close
    @connection.finish
  end
end
