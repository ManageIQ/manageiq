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
    Qpid::Messaging::Connection.new(:url => connection_url, :options => connection_options)
  end

  def connection_options
    connection_opts = {}
    if @options[:port] == 5671
      connection_opts[:transport]     = "ssl"
      connection_opts[:ssl_cert_name] = @options[:hostname]
    end
    if @options.key?(:username)
      connection_opts[:sasl_mechanism] = "PLAIN"
      connection_opts[:username]       = @options[:username]
      connection_opts[:password]       = @options[:password]
    end
    connection_opts
  end

  def connection_url
    # The qpid "url" is not a URL at all!  It's something that's *called* a URL
    # but doesn't follow the same format as a standard URL ... it looks like:
    #
    #   hostname:port
    #
    # In full, the URL could look like:
    #
    #   scheme:protocol:user/pass@host:port:queue_name
    #
    #   or,
    #
    #   amqp:tcp:username/password@host:port:queue
    #
    # But, the rest of the arguments are passed as "options" to the connection
    # constructor.  This method will only format the host and port portion of
    # the "url".
    #
    # Also, this is going to use the ruby URI module in order to confidently
    # handle ipv6 ip addresses that might find their way here.
    uri = URI::Generic.build(:host => @options[:hostname], :port => @options[:port])

    # uri.to_s will result in //hostname:port when no scheme is set
    # strip off the leading "//" and return what's left
    uri.to_s.sub(%r{^//}, '')
  end
end
