module VimConnectMixin
  extend ActiveSupport::Concern

  def connect(options = {})
    options[:auth_type] ||= :ws
    raise _("no credentials defined") if missing_credentials?(options[:auth_type])

    options[:use_broker] = (self.class.respond_to?(:use_vim_broker?) ? self.class.use_vim_broker? : ManageIQ::Providers::Vmware::InfraManager.use_vim_broker?) unless options.key?(:use_broker)
    if options[:use_broker] && !MiqVimBrokerWorker.available?
      msg = "Broker Worker is not available"
      _log.error(msg)
      raise MiqException::MiqVimBrokerUnavailable, _("Broker Worker is not available")
    end
    options[:vim_broker_drb_port] ||= MiqVimBrokerWorker.method(:drb_port) if options[:use_broker]

    # The following require pulls in both MiqFaultTolerantVim and MiqVim
    require 'VMwareWebService/miq_fault_tolerant_vim'

    options[:ems] = self
    MiqFaultTolerantVim.new(options)
  end

  def with_provider_connection(options = {})
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    begin
      vim = connect(options)
      yield vim
    rescue MiqException::MiqVimBrokerUnavailable => err
      MiqVimBrokerWorker.broker_unavailable(err.class.name, err.to_s)
      _log.warn("Reported the broker unavailable")
      raise
    ensure
      vim.try(:disconnect) rescue nil
    end
  end

  module ClassMethods
    def raw_connect(options)
      options[:pass] = MiqPassword.try_decrypt(options[:pass])
      validate_connection do
        MiqFaultTolerantVim.new(options)
      end
    end

    def validate_connection
      yield
    rescue SocketError, Errno::EHOSTUNREACH, Errno::ENETUNREACH
      _log.warn($!.inspect)
      raise MiqException::MiqUnreachableError, $!.message
    rescue Handsoap::Fault
      _log.warn($!.inspect)
      if $!.respond_to?(:reason)
        raise MiqException::MiqInvalidCredentialsError, $!.reason if $!.reason =~ /Authorize Exception|incorrect user name or password/
        raise $!.reason
      end
      raise $!.message
    rescue Exception
      _log.warn($!.inspect)
      raise "Unexpected response returned from Provider, see log for details"
    end
  end
end
