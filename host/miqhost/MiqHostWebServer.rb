class MiqWebServer < SOAP::RPC::HTTPServer
  def self.create_webserver(options, servant_klass)
    # Configure and start web server
    root_dir = File.dirname(File.expand_path(__FILE__))

    begin
      webserver = MiqWebServer.new(
        :BindAddress => "0.0.0.0",
        :Port => options.wsListenPort,
        :AccessLog => [],
        :SSLEnable => options.webservices[:provider_protocol].downcase == "https",
        :SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
        :SSLCACertificateFile => File.join(root_dir, 'certs/ca.cer'),
        :SSLCertificate => self.cert(File.join(root_dir, 'certs/client.cer')),
        :SSLPrivateKey => self.key(File.join(root_dir, 'certs/client.cer.key')),
        :DocumentRoot    => File.join(root_dir, 'public')
      )
    rescue Errno::EBADF => err
      raise "Failed to bind to port [#{options.wsListenPort}].  [#{err}]"
    end
    webserver.default_namespace = 'urn:Miqws'
    
    # Watch for shutdown signals
    webserver.trap_shutdown()
    
    # Expose all public methods of the ExposeService class
    webserver.add_rpc_servant(servant_klass.new(options))

    # Create a pid file for this process in the temp folder
    File.open(File.join($miqExtDir, "miqhost.pid"), "w") {|f| f.write(Process.pid); f.close} if $miqExtDir
    
    return webserver
  end
  
	def shutdown(restart=false, &blk)
    $log.info "Miqhost: Shutdown initiated..." if $log
    unless MiqThreadCtl.exiting?
			@servant_wait = true
      super()
      $log.info "Miqhost: web server shutdown completed." if $log

      @servant.host_shutdown(restart, &blk)
			@servant_wait = false
    else
      $log.info "Miqhost: Shutdown is already in progress..." if $log
    end
	end
  
  def restart(&blk)
    shutdown(true, &blk)
  end
    
  def add_rpc_servant(obj)
    @servant = obj
    super
  end
	
	def wait_servant()
		1.upto(60) do |x|
			sleep(0.5)
			break unless @servant_wait
    end
	end
	
  def trap_shutdown()
    # Watch for Ctrl-C to shutdown
    [:INT].each {|s| trap(s) {self.shutdown}}
    # Test code for Windows - [:INT,:TERM,:SEGV,:KILL,:EXIT,:FPE,:ABRT,:ILL].each {|s| trap(s) {$miqHostServer.shutdown}}

    # This "should be" temporary code to check for a signal file to exit.
    # When running as a NT service we have been unable to signal the ruby process
    # to end.  This is a work-around of that issue so miqhost can end cleanly.
    if Platform::OS == :win32 && ENV["HOMEDRIVE"].nil? && $miqExtDir
      exitFile = File.join($miqExtDir, "miq.#{Process.pid}"); exitFile.gsub!("\\", "/")
      MiqThreadCtl << Thread.new do
        begin
          loop do
            sleep(5)
            MiqThreadCtl.quiesceExit
            if File.exist?(exitFile)
              $log.info "Shutdown file detected.  File:[#{exitFile}]"
              File.delete(exitFile)
              self.shutdown
            end
          end
        rescue => e
          $log.summary e
        end
      end
    end
  end
    
  def self.cert(filename)
    OpenSSL::X509::Certificate.new(File.open(filename) { |f| f.read })
  end

  def self.key(filename)
    OpenSSL::PKey::RSA.new(File.open(filename) { |f| f.read })
  end
end
