module MiqAeEngine
  class MiqAeMethod
    AE_ROOT_DIR    = File.expand_path(File.join(Rails.root,  'product/automate'))
    Dir.mkdir(AE_ROOT_DIR) unless File.directory?(AE_ROOT_DIR)
    AE_METHODS_DIR = File.expand_path(File.join(AE_ROOT_DIR, 'methods'))
    Dir.mkdir(AE_METHODS_DIR) unless File.directory?(AE_METHODS_DIR)

    def self.invoke_inline(aem, obj, inputs)
      return invoke_inline_ruby(aem, obj, inputs) if aem.language.downcase.strip == "ruby"
      raise  MiqAeException::InvalidMethod, "Inline Method Language [#{aem.language}] not supported"
    end

    def self.invoke_uri(aem, obj, _inputs)
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(aem.data)
      raise  MiqAeException::MethodNotFound, "Specified URI [#{aem.data}] in Method [#{aem.name}] has unsupported scheme of #{scheme}; supported scheme is file" unless scheme.downcase == "file"
      raise  MiqAeException::MethodNotFound, "Invalid file specification -- #{aem.data}" if path.nil?
      # Create the filename corresponding to the URI specification
      fname = File.join(AE_METHODS_DIR, path)
      raise  MiqAeException::MethodNotFound, "Method [#{aem.data}] Not Found (fname=#{fname})" unless File.exist?(fname)
      cmd = "#{aem.language} #{fname}"
      invoke_external(cmd, obj.workspace)
    end

    def self.invoke_builtin(aem, obj, inputs)
      mname = "miq_#{aem.data.blank? ? aem.name.downcase : aem.data.downcase}"
      raise  MiqAeException::MethodNotFound, "Built-In Method [#{mname}] does not exist" unless MiqAeBuiltinMethod.public_methods.collect(&:to_s).include?(mname)

      # Create service, since built-in method may be calling things that assume there is one
      svc = MiqAeMethodService::MiqAeService.new(obj.workspace)

      begin
        return MiqAeBuiltinMethod.send(mname, obj, inputs)
      rescue => err
        raise MiqAeException::AbortInstantiation, err.message
      ensure
        # Destroy service to avoid storing object references
        svc.destroy
      end
    end

    def self.invoke(obj, aem, args)
      inputs = {}

      aem.inputs.each do |f|
        key   = f.name
        value = args[key]
        value = obj.attributes[key] || f.default_value if value.nil?
        inputs[key] = MiqAeObject.convert_value_based_on_datatype(value, f["datatype"])

        if obj.attributes[key] && f["datatype"] != "string"
          # the attributes data in the object start as string
          # if the datatype of the value stored in the object should be converted,
          # then update the object with the converted value
          obj.attributes[key] = MiqAeObject.convert_value_based_on_datatype(obj.attributes[key], f["datatype"])
        end

        raise MiqAeException::MethodParmMissing, "Method [#{aem.fqname}] requires parameter [#{f.name}]" if inputs[key].nil?
      end

      if obj.workspace.readonly?
        $miq_ae_logger.info("Workspace Instantiation is READONLY -- skipping method [#{aem.fqname}] with inputs [#{inputs.inspect}]")
      elsif ["inline", "builtin", "uri"].include?(aem.location.downcase.strip)
        $miq_ae_logger.info("Invoking [#{aem.location}] method [#{aem.fqname}] with inputs [#{inputs.inspect}]")
        return MiqAeEngine::MiqAeMethod.send("invoke_#{aem.location.downcase.strip}", aem, obj, inputs)
      end

      nil
    end

    def self.invoke_external(cmd, workspace, serialize_workspace = false)
      ws = nil

      if serialize_workspace
        ws, = Benchmark.realtime_block(:method_invoke_external_ws_create_time) { MiqAeWorkspace.create(:workspace => workspace) }
        $miq_ae_logger.debug("Invoking External Method with MIQ_TOKEN=#{ws.guid} and command=#{cmd}")
      end

      # Release connection to thread that will be used by method process. It will return it when it is done
      ActiveRecord::Base.connection_pool.release_connection

      # Spawn separate Ruby process to run method

      ENV['MIQ_TOKEN'] = ws.guid unless ws.nil?

      rc, msg = run_method(*cmd)
      if ws
        ws.reload
        ws.setters.each { |uri, value| workspace.varset(uri, value) } unless ws.setters.nil?
        ws.delete
      end
      process_ruby_method_results(rc, msg)
    end
    private_class_method :invoke_external

    MIQ_OK    = 0
    MIQ_WARN  = 4
    MIQ_STOP  = 8
    MIQ_ABORT = 16

    def self.open_transactions_threshold
      @open_transactions_threshold ||= Rails.env.test? ? 1 : 0
    end
    private_class_method :open_transactions_threshold

    def self.verbose_rc(rc)
      case rc
      when MIQ_OK    then 'MIQ_OK'
      when MIQ_WARN  then 'MIQ_WARN'
      when MIQ_STOP  then 'MIQ_STOP'
      when MIQ_ABORT then 'MIQ_ABORT'
      else                "Unknown RC: [#{rc}]"
      end
    end
    private_class_method :verbose_rc

    def self.run_ruby_method(*code)
      ActiveRecord::Base.connection_pool.release_connection
      Bundler.with_clean_env do
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          run_method(Gem.ruby) do |stdin|
            stdin.puts(code)
          end
        end
      end
    end
    private_class_method :run_ruby_method

    def self.process_ruby_method_results(rc, msg)
      case rc
      when MIQ_OK
        $miq_ae_logger.info(msg)
      when MIQ_WARN
        $miq_ae_logger.warn(msg)
      when MIQ_STOP
        raise MiqAeException::StopInstantiation,  msg
      when MIQ_ABORT
        raise MiqAeException::AbortInstantiation, msg
      else
        raise MiqAeException::UnknownMethodRc, msg
      end
      rc
    end
    private_class_method :process_ruby_method_results

    def self.ruby_method_runnable?(aem)
      return false if aem.data.blank?

      raise MiqAeException::Error, "Unable to launch Automate Method because currently in SQL transaction" if ActiveRecord::Base.connection.open_transactions > open_transactions_threshold

      true
    end
    private_class_method :ruby_method_runnable?

    def self.invoke_inline_ruby(aem, obj, inputs)
      if ruby_method_runnable?(aem)
        obj.workspace.invoker ||= MiqAeEngine::DrbRemoteInvoker.new(obj.workspace)
        obj.workspace.invoker.with_server(inputs, aem.data) do |code|
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Starting ")
          rc, msg = run_ruby_method(code)
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Ending")
          process_ruby_method_results(rc, msg)
        end
      end
    end
    private_class_method :invoke_inline_ruby

    def self.run_method(cmd)
      require 'open4'
      rc = nil
      threads = []
      method_pid = nil
      begin
        status = Open4.popen4(*cmd) do |pid, stdin, stdout, stderr|
          method_pid = pid
          yield stdin if block_given?
          stdin.close
          threads << Thread.new do
            stdout.each_line { |msg| $miq_ae_logger.info "Method STDOUT: #{msg.strip}" }
          end
          threads << Thread.new do
            stderr.each_line { |msg| $miq_ae_logger.error "Method STDERR: #{msg.strip}" }
          end
          threads.each(&:join)
        end
        rc  = status.exitstatus
        msg = "Method exited with rc=#{verbose_rc(rc)}"
        method_pid = nil
        threads = []
      rescue => err
        STDERR.puts "** AUTOMATE ** Method exec failed because #{err.class}:#{err.message}" if ENV.key?("CI")
        $miq_ae_logger.error("Method exec failed because (#{err.class}:#{err.message})")
        rc = MIQ_ABORT
        msg = "Method execution failed"
      ensure
        cleanup(method_pid, threads)
      end
      return rc, msg
    end
    private_class_method :run_method

    def self.cleanup(method_pid, threads)
      if method_pid
        begin
          $miq_ae_logger.error("Terminating non responsive method with pid #{method_pid.inspect}")
          Process.kill("TERM", method_pid)
          Process.wait(method_pid)
        rescue Errno::ESRCH, RangeError => err
          $miq_ae_logger.error("Error terminating #{method_pid.inspect} exception #{err}")
        end
      end
      threads.each(&:exit)
    end
    private_class_method :cleanup
  end
end
