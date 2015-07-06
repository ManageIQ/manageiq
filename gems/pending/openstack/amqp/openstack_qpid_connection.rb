#
# An AMQP connection object wrapper that uses Qpid to build an AMQP connection.
#

class OpenstackQpidConnection
  attr_reader :hostname, :port

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

  # * hostname :openstack server hostname
  # * port     :openstack server amqp port
  # * username :amqp username
  # * password :amqp password
  def initialize(hostname, port, username = nil, password = nil)
    raise "qpid_messaging is not available" unless self.class.available?

    @hostname = hostname
    @port     = port
    @username = username
    @password = password
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
    @connection ||= create_connection
  end

  def create_connection
    url     = "#{@hostname}:#{@port}"
    options = {:username => @username, :password => @password}.delete_nils
    options[:transport] = "ssl" if @port == 5671
    Qpid::Messaging::Connection.new(:url => url, :options => options)
  end
end
