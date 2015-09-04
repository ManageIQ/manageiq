require 'drb'
require 'engine/miq_ae_executor'
require 'connection_pool'

module MiqAeEngine
  class MiqAeMethod
    AE_ROOT_DIR    = File.expand_path(File.join(Rails.root,  'product/automate'))
    Dir.mkdir(AE_ROOT_DIR) unless File.directory?(AE_ROOT_DIR)
    AE_METHODS_DIR = File.expand_path(File.join(AE_ROOT_DIR, 'methods'))
    Dir.mkdir(AE_METHODS_DIR) unless File.directory?(AE_METHODS_DIR)

    def self.invoke_inline(aem, obj, inputs)
      return self.invoke_inline_ruby(aem, obj, inputs) if aem.language.downcase.strip == "ruby"
      raise  MiqAeException::InvalidMethod, "Inline Method Language [#{aem.language}] not supported"
    end

    def self.invoke_uri(aem, obj, inputs)
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(aem.data)
      raise  MiqAeException::MethodNotFound, "Specified URI [#{aem.data}] in Method [#{aem.name}] has unsupported scheme of #{scheme}; supported scheme is file" unless scheme.downcase == "file"
      raise  MiqAeException::MethodNotFound, "Invalid file specification -- #{aem.data}" if path.nil?
      # Create the filename corresponding to the URI specification
      fname = File.join(AE_METHODS_DIR, path)
      raise  MiqAeException::MethodNotFound, "Method [#{aem.data}] Not Found (fname=#{fname})" unless File.exist?(fname)
      cmd = "#{aem.language} #{fname}"
      return MiqAeEngine::MiqAeMethod.invoke_external(cmd, obj.workspace)
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
      inputs = Hash.new

      aem.inputs.each { |f|
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
      }

      if obj.workspace.readonly?
        $miq_ae_logger.info("Workspace Instantiation is READONLY -- skipping method [#{aem.fqname}] with inputs [#{inputs.inspect}]")
      elsif ["inline", "builtin", "uri"].include?(aem.location.downcase.strip)
        $miq_ae_logger.info("Invoking [#{aem.location}] method [#{aem.fqname}] with inputs [#{inputs.inspect}]")
        return MiqAeEngine::MiqAeMethod.send("invoke_#{aem.location.downcase.strip}", aem, obj, inputs)
      end

      return nil
    end

    private

    def self.invoke_external(cmd, workspace, serialize_workspace = false)
      ws = nil

      if serialize_workspace
        ws, = Benchmark.realtime_block(:method_invoke_external_ws_create_time) { MiqAeWorkspace.create(:workspace => workspace) }
        $miq_ae_logger.debug("Invoking External Method with MIQ_TOKEN=#{ws.guid} and command=#{cmd}")
      end

      rc = nil
      final_stderr = nil
      begin
        code = ""
        code << "ENV['MIQ_TOKEN'] = #{ws.guid.to_s.inspect}\n" unless ws.nil?
        code << "exec(*#{cmd.inspect})"

        rc, _stdout, stderr = executor_pool.with { |exe| exe.run_ruby(code) }
        final_stderr = stderr.each_line.map(&:strip)

        unless ws.nil?
          ws.reload unless ws.nil?
          ws.setters.each { |uri, value| workspace.varset(uri, value) } unless ws.setters.nil?
          ws.delete
        end
        msg = "Method exited with rc=#{verbose_rc(rc)}"
      rescue => err
        $miq_ae_logger.error("Method exec failed because (#{err.class}:#{err.message})")
        rc = MIQ_ABORT
        msg = "Method execution failed"
      end

      process_ruby_method_results(rc, msg, final_stderr)
    end

    MIQ_OK    = 0
    MIQ_WARN  = 4
    MIQ_STOP  = 8
    MIQ_ABORT = 16

    def self.open_transactions_threshold
      @open_transactions_threshold ||= Rails.env.test? ? 1 : 0
    end

    def self.verbose_rc(rc)
      case rc
      when MIQ_OK    then 'MIQ_OK'
      when MIQ_WARN  then 'MIQ_WARN'
      when MIQ_STOP  then 'MIQ_STOP'
      when MIQ_ABORT then 'MIQ_ABORT'
      else                "Unknown RC: [#{rc}]"
      end
    end

    def self.executor_pool
      @executor_pool ||= ConnectionPool.new(:size => 5, :timeout => 3) { MiqAeEngine::MiqAeExecutor.new }
    end

    def self.run_ruby_method(body, preamble = nil)
      rc, msg, final_stderr = nil
      begin
        # HACK: We return our DB connection to the pool, mid-
        # transaction(!), so that the DRb thread will get it (!!!).
        #
        # When it's done, it'll do likewise, and we'll get it back
        # again.
        #
        # Naturally, this is all incredibly un-threadsafe. But, we only
        # do it for the test suite, so it's only moderately terrible.

        if open_transactions_threshold > 0
          ActiveRecord::Base.connection_pool.release_connection
        end

        args = [body]

        if preamble && preamble =~ /^MIQ_URI = '(.*)'/
          args << $1

          if preamble =~ /^MIQ_ID = (.*)/
            args << $1.to_i
          end
        end

        rc, _stdout, stderr = executor_pool.with { |exe| exe.run_ruby(*args) }
        final_stderr = stderr.each_line.map(&:strip)

        msg = "Method exited with rc=#{verbose_rc(rc)}"
      rescue => err
        $miq_ae_logger.error("Method exec failed because (#{err.class}:#{err.message})")
        rc = MIQ_ABORT
        msg = "Method execution failed"
      end
      return rc, msg, final_stderr
    end

    def self.process_ruby_method_results(rc, msg, stderr)
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
        raise MiqAeException::UnknownMethodRc, msg, stderr
      end
      return rc
    end

    def self.method_preamble(miq_uri, miq_id)
      preamble  = "MIQ_URI = '#{miq_uri}'\n"
      preamble << "MIQ_ID = #{miq_id}\n"
      preamble
    end

    def self.ruby_method_runnable?(aem)
      return false if aem.data.blank?

      raise MiqAeException::Error, "Unable to launch Automate Method because currently in SQL transaction" if ActiveRecord::Base.connection.open_transactions > self.open_transactions_threshold

      return true
    end

    def self.setup_drb_for_ruby_method
      drb_front  = MiqAeMethodService::MiqAeServiceFront.new
      drb        = DRb.start_service("druby://127.0.0.1:0", drb_front)
    end

    def self.teardown_drb_for_ruby_method
      DRb.stop_service
    end

    def self.invoke_inline_ruby(aem, obj, inputs)
      if ruby_method_runnable?(aem)
        begin
          setup_drb_for_ruby_method if obj.workspace.num_drb_methods == 0
          obj.workspace.num_drb_methods += 1
          svc            = MiqAeMethodService::MiqAeService.new(obj.workspace)
          svc.inputs     = inputs
          svc.preamble   = method_preamble(DRb.uri, svc.object_id)
          svc.body       = aem.data
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Starting ")
          rc, msg, stderr = run_ruby_method(svc.body, svc.preamble)
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Ending")

          process_ruby_method_results(rc, msg, stderr)
        ensure
          svc.destroy  # Reset inputs to empty to avoid storing object references
          obj.workspace.num_drb_methods -= 1
          teardown_drb_for_ruby_method if obj.workspace.num_drb_methods == 0
        end
      end
    end
  end
end
