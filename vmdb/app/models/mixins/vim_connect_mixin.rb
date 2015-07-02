module VimConnectMixin
  def connect(options = {})
    options[:auth_type] ||= :ws
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    options[:fault_tolerant] = true unless options.has_key?(:fault_tolerant)

    options[:use_broker] = (self.class.respond_to?(:use_vim_broker?) ? self.class.use_vim_broker? : ManageIQ::Providers::Vmware::InfraManager.use_vim_broker?) if options[:fault_tolerant] && !options.has_key?(:use_broker)
    options[:check_broker_worker] = !!options[:use_broker] unless options.has_key?(:check_broker_worker)
    if options[:check_broker_worker] && !MiqVimBrokerWorker.available?
      msg = "Broker Worker is not available"
      _log.error(msg)
      raise MiqException::MiqVimBrokerUnavailable, msg
    end
    options[:vim_broker_drb_port] ||= MiqVimBrokerWorker.method(:drb_port) if options[:use_broker]

    # The following require pulls in both MiqFaultTolerantVim and MiqVim
    require 'miq_fault_tolerant_vim'

    if options[:fault_tolerant]
      options[:ems] = self
      MiqFaultTolerantVim.new(options)
    else
      ip   = options[:ip]   || self.address
      user = options[:user] || self.authentication_userid(options[:auth_type])
      pass = options[:pass] || self.authentication_password(options[:auth_type])
      MiqVim.new(ip, user, pass)
    end
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{self.name}]")
    begin
      vim = self.connect(options)
      yield vim
    rescue MiqException::MiqVimBrokerUnavailable => err
      MiqVimBrokerWorker.broker_unavailable(err.class.name, err.to_s)
      _log.warn("Reported the broker unavailable")
      raise
    ensure
      vim.try(:disconnect) rescue nil
    end
  end
end
