#
# An AMQP connection object wrapper that uses Qpid to build an AMQP connection.
#

class OpenstackQpidConnection
  # Checks whether the qpid_messaging gem is available.
  def self.available?
    return @available if defined?(@available)

    require 'qpid_messaging'
    @available = true
  rescue LoadError => e
    $log.info("MIQ(#{name}).#{__method__}) Failed to load qpid_messaging gem.  Qpid AMQP messaging will not be available.  Enable debug logging to see the associated exception.") if $log
    $log.debug("MIQ(#{name}).#{__method__}) Qpid Gem LoadError: #{e}") if $log
    @available = false
  end

  # options
  # * :hostname     => openstack server hostname [REQUIRED]
  # * :port         => openstack server amqp port [REQUIRED]
  # * :username     => amqp username [REQUIRED - if authentication is enabled]
  # * :password     => amqp password [REQUIRED - if authentication is enabled]
  def initialize(options = {})
    raise "qpid_messaging is not available" unless self.class.available?

    @options = options
  end

  # Opens the qpid connection
  def open
    unless open?
      connection.open
    end
    self
  end

  # Checks whether the qpid connection is open
  def open?
    @connection && @connection.open?
  end

  # Closes the qpid connection
  def close
    if open?
      @session.close if @session
      connection.close
    end
  end

  # Retrieves a session for this connection
  def session
    unless @session
      unless open?
        open
      end
      @session = connection.create_session
    end
    @session
  end

  private
  def connection # :nodoc:
    unless @connection
      if @options.has_key?(:hostname) and @options.has_key?(:port)
        @connection = create_connection
      else
        raise "Host and port required for OpenStack Qpid connection"
      end
    end
    @connection
  end

  def create_connection
    url = "#{@options[:hostname]}:#{@options[:port]}"
    opts = @options.select { |k, v| [:username, :password].include? k }
    opts[:transport] = "ssl" if @options[:port] == 5671
    Qpid::Messaging::Connection.new(:url => url, :options => opts)
  end
end
