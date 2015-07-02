$:.push("#{File.dirname(__FILE__)}/../VMwareWebService")
require 'MiqVim'
require 'MiqVimBroker'

class MiqFaultTolerantVim
  def initialize(*options)
    options = options.first if options.first.is_a?(Hash)
    @vim = nil

    @erec     = options[:ems]
    auth_type = options[:auth_type] || :ws
    ip        = options[:ip]        || @erec.address
    user      = options[:user]      || @erec.authentication_userid(auth_type)
    pass      = options[:pass]      || @erec.authentication_password(auth_type)
    @ems      = [ip, user, pass]

    @use_broker = options.has_key?(:use_broker) ? options[:use_broker] : true
    if @use_broker
      if options[:vim_broker_drb_port].respond_to?(:call)
        @vim_broker_drb_port_method = options[:vim_broker_drb_port]
        @vim_broker_drb_port        = @vim_broker_drb_port_method.call
      else
        @vim_broker_drb_port_method = nil
        @vim_broker_drb_port        = options[:vim_broker_drb_port]
      end
    end

    begin
      _connect
    rescue MiqException::MiqVimBrokerUnavailable
      retry if _handle_broker_port_change
      raise
    end
  end

  def execute(&block)
    _execute(&block)
  end

  def method_missing(m, *args)
    _execute(m == :disconnect ? :on_disconnect : :on_execute) {|vim| vim.send(m, *args) unless vim.nil? }
  end

  def _ems_name
    @erec.nil? ? _ems_address : @erec.name
  end

  def _ems_address
    @ems[0]
  end

  def _ems_userid
    @ems[1]
  end

  def _use_broker
    @use_broker
  end

  def _vim_broker_drb_port
    @vim_broker_drb_port
  end

  def _reconnect
    _disconnect
    _connect
  end

  private

  def _execute(state = :on_execute, &block)
    return unless block_given?
    $log.warn("MIQ(#{self.class.name}._execute) @vim handle is nil.") if $log && @vim.nil? && state != :on_connect
    meth = @use_broker ? :_execute_with_broker : :_execute_without_broker
    self.send(meth, state, &block)
  end

  def _execute_without_broker(state)
    yield @vim
  end

  def _execute_with_broker(state)
    log_header = "MIQ(#{self.class.name}._execute_with_broker)"
    retries = 0
    begin
      yield @vim
    rescue RangeError, DRb::DRbConnError, Handsoap::Fault, Errno::EMFILE => err
      modified_exception = nil

      if err.is_a?(Handsoap::Fault) 
        #
        # Raise all SOAP Errors, if executing
        #
        raise if state == :on_execute

        #
        #  Retry any SOAP Errors, except for authentication or authorization errors
        #   'Handsoap::FaultError: Permission to perform this operation was denied.'
        #   'Handsoap::FaultError: The session is not authenticated.'
        #
        raise if err.to_s !~ /Permission to perform this operation was denied/i && err.to_s !~ /^The session is not authenticated/i
      end

      #
      # If one of the following exceptions, broker could have been recycled and we are holding a stale object reference
      #   'RangeError: 0xdb1bbe8e is recycled object occurs'
      #   'RangeError: 0xdb4f902e is not id value'
      #
      if err.is_a?(RangeError)
        raise unless err.to_s =~ /is recycled object/i || err.to_s =~ /is not id value/i
        modified_exception = MiqException::MiqVimBrokerStaleHandle
      end

      #
      # Cannot establish DRb connection to broker
      #   'DRb::DRbConnError: druby://localhost:9001 - #<Errno::ECONNREFUSED: Connection refused - connect(2)>'
      #
      if err.kind_of?(DRb::DRbConnError)
        if _handle_broker_port_change
          _connect
          retry
        end
        modified_exception = MiqException::MiqVimBrokerUnavailable
      end

      #
      # Broker is overwhelmed with too many open sockets
      #
      modified_exception = MiqException::MiqVimBrokerUnavailable if err.kind_of?(Errno::EMFILE)

      exception_class_name = modified_exception ? modified_exception.name : err.class.name

      #
      # When disconnecting, only warn about any errors encountered
      #
      if state == :on_disconnect
        $log.warn("#{log_header} The following issue was detected and skipped while disconnecting from [#{_ems_address}]: [#{exception_class_name}] [#{_classify_error(err)}]") if $log
        return
      end

      #
      # Retry once, if possible
      #
      if state == :on_execute && retries == 0
        $log.warn("#{log_header} Retrying communication via VimBroker to [#{_ems_address}] because [#{exception_class_name}] [#{_classify_error(err)}]") if $log
        _reconnect
        retries += 1
        retry
      end

      #
      # Log an error message
      #
      $log.error("#{log_header} Error communicating via VimBroker to [#{_ems_address}] because [#{exception_class_name}] [#{_classify_error(err)}]") if $log

      #
      # Raise the original error, if we did not modify it
      #
      raise if modified_exception.nil?

      #
      # Raise our modified error
      #
      raise modified_exception, _classify_error(err)
    end
  end

  def _connect
    log_header = "MIQ(#{self.class.name}._connect) EMS: [#{_ems_name}]"
    log_header << " [Broker]" if @use_broker

    _execute(:on_connect) do
      $log.info("#{log_header} Connecting with address: [#{_ems_address}], userid: [#{_ems_userid}]...") if $log
      @use_broker ? _connect_with_broker : _connect_without_broker
      $log.info("#{log_header} #{@vim.server} is #{(@vim.isVirtualCenter? ? 'VC' : 'ESX')}, API version: #{@vim.apiVersion}") if $log
      $log.info("#{log_header} Connected") if $log
    end
  end

  def _connect_without_broker
    @vim = MiqVim.new(*@ems)
  end

  def _connect_with_broker
    _connect_broker_client

    begin
      @vim = _broker_client.getMiqVim(*@ems)
    rescue DRb::DRbConnError, Errno::EMFILE => err
      # Instead of connecting directly when the broker is not available, log an error and raise the exception
      $log.error("MIQ(#{self.class.name}._connect) EMS: [#{_ems_name}] [Broker] Unable to connect to: [#{_ems_address}] because #{_classify_error(err)}") if $log
      raise MiqException::MiqVimBrokerUnavailable, _classify_error(err)
    end
  end

  def _disconnect
    @vim.disconnect if @vim.respond_to?(:disconnect) rescue nil
    @vim = nil
  end

  def _broker_client
    $vim_broker_client
  end

  def _connect_broker_client
    return unless $vim_broker_client.nil?
    raise MiqException::MiqVimBrokerUnavailable, "Broker is not available (not running)." if @vim_broker_drb_port.blank?
    $vim_broker_client = MiqVimBroker.new(:client, @vim_broker_drb_port)
    $vim_broker_client_port = @vim_broker_drb_port
  end

  def _disconnect_broker_client
    $vim_broker_client = nil
  end

  def _classify_error(err)
    if @use_broker
      case err
      when DRb::DRbConnError
        return "Broker is not available (connection error)."
      when Errno::EMFILE
        return "Broker is not available (too many open files)."
      when RangeError
        # If the broker is now started but our handle is no longer valid
        return "Broker has been restarted."
      end
    end

    return err.to_s
  end

  def _handle_broker_port_change
    log_header = "MIQ(#{self.class.name}._handle_broker_port_change)"
    if @vim_broker_drb_port_method
      new_port = @vim_broker_drb_port_method.call
      if new_port != $vim_broker_client_port
        $log.warn("#{log_header} Retrying communication via VimBroker to [#{_ems_address}] because [Broker DRb Port changed from #{$vim_broker_client_port} to #{new_port}]") if $log && !new_port.blank?
        @vim_broker_drb_port = new_port
        _disconnect
        _disconnect_broker_client
        return (new_port.blank? ? false : true)
      end
    end
    return false
  end
end
