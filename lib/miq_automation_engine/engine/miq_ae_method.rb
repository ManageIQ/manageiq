require 'drb'

module MiqAeEngine
  class MiqAeMethod
    AE_ROOT_DIR    = File.expand_path(File.join(Rails.root,  'product/automate'))
    Dir.mkdir(AE_ROOT_DIR) unless File.directory?(AE_ROOT_DIR)
    AE_METHODS_DIR = File.expand_path(File.join(AE_ROOT_DIR, 'methods'))
    Dir.mkdir(AE_METHODS_DIR) unless File.directory?(AE_METHODS_DIR)

    def self.invoke_inline(aem, obj, inputs)
      #return invoke_inline_ruby(aem, obj, inputs) if aem.language.downcase.strip == "ruby"
      return invoke_rest_method(aem, obj, inputs) if aem.language.downcase.strip == "ruby"
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
      MiqAeEngine::MiqAeMethod.invoke_external(cmd, obj.workspace)
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

    private

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

      rc, msg, final_stderr = run_method(*cmd)
      if ws
        ws.reload
        ws.setters.each { |uri, value| workspace.varset(uri, value) } unless ws.setters.nil?
        ws.delete
      end
      process_ruby_method_results(rc, msg, final_stderr)
    end

    MIQ_OK    = 0
    MIQ_WARN  = 4
    MIQ_STOP  = 8
    MIQ_ABORT = 16

    RUBY_METHOD_PREAMBLE = <<-RUBY
class AutomateMethodException < StandardError
end

begin
  require 'date'
  require 'rubygems'
  $:.unshift("#{Gem.loaded_specs['activesupport'].full_gem_path}/lib")
  require 'active_support/all'
  require 'socket'
  Socket.do_not_reverse_lookup = true  # turn off reverse DNS resolution

  require 'drb'
  require 'yaml'

  Time.zone = 'UTC'

  MIQ_OK    = 0
  MIQ_WARN  = 4
  MIQ_ERROR = 8
  MIQ_STOP  = 8
  MIQ_ABORT = 16

  DRbObject.send(:undef_method, :inspect)
  DRbObject.send(:undef_method, :id) if DRbObject.respond_to?(:id)

  DRb.start_service("druby://127.0.0.1:0")
  $evmdrb = DRbObject.new(nil, MIQ_URI)
  raise AutomateMethodException,"Cannot create DRbObject for uri=\#{MIQ_URI}" if $evmdrb.nil?
  $evm = $evmdrb.find(MIQ_ID)
  raise AutomateMethodException,"Cannot find Service for id=\#{MIQ_ID} and uri=\#{MIQ_URI}" if $evm.nil?
  MIQ_ARGS = $evm.inputs
rescue Exception => err
  STDERR.puts('The following error occurred during inline method preamble evaluation:')
  STDERR.puts("  \#{err.class}: \#{err.message}")
  STDERR.puts("  \#{err.backtrace.join('\n')}") unless err.kind_of?(AutomateMethodException)
  raise
end

class Exception
  def backtrace_with_evm
    value = backtrace_without_evm
    value ? $evm.backtrace(value) : value
  end

  alias backtrace_without_evm backtrace
  alias backtrace backtrace_with_evm
end

begin
RUBY

    RUBY_METHOD_POSTSCRIPT = <<-RUBY
rescue Exception => err
  unless err.kind_of?(SystemExit)
    $evm.log('error', 'The following error occurred during method evaluation:')
    $evm.log('error', "  \#{err.class}: \#{err.message}")
    $evm.log('error', "  \#{err.backtrace[0..-2].join('\n')}")
  end
  raise
ensure
  # $evm.disconnect_sql
  $evm.save_workspace
end
RUBY

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

    def self.run_ruby_method(body, preamble = nil)
      ActiveRecord::Base.connection_pool.release_connection
      Bundler.with_clean_env do
        run_method(Gem.ruby) do |stdin|
          stdin.puts(preamble.to_s)
          stdin.puts(body)
          stdin.puts(RUBY_METHOD_POSTSCRIPT) unless preamble.blank?
        end
      end
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
      rc
    end

    def self.method_preamble(miq_uri, miq_id)
      preamble  = "MIQ_URI = '#{miq_uri}'\n"
      preamble << "MIQ_ID = #{miq_id}\n"
      preamble << RUBY_METHOD_PREAMBLE
      preamble
    end


    def self.ruby_method_runnable?(aem)
      return false if aem.data.blank?

      raise MiqAeException::Error, "Unable to launch Automate Method because currently in SQL transaction" if ActiveRecord::Base.connection.open_transactions > open_transactions_threshold

      true
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

    def self.run_method(cmd)
      require 'open4'
      rc = nil
      final_stderr = []
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
            stderr.each_line do |msg|
              msg = msg.chomp
              final_stderr << msg
              $miq_ae_logger.error "Method STDERR: #{msg}"
            end
          end
          threads.each(&:join)
        end
        rc  = status.exitstatus
        msg = "Method exited with rc=#{verbose_rc(rc)}"
        method_pid = nil
        threads = []
      rescue => err
        $miq_ae_logger.error("Method exec failed because (#{err.class}:#{err.message})")
        rc = MIQ_ABORT
        msg = "Method execution failed"
      ensure
        cleanup(method_pid, threads)
      end
      return rc, msg, final_stderr.presence
    end

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

    def self.invoke_rest_method(aem, obj, inputs)
      if ruby_method_runnable?(aem)
        input_file = File.join(Dir.tmpdir,"in#{Process.pid}_#{Thread.current.object_id}.yaml")
        output_file = File.join(Dir.tmpdir,"out#{Process.pid}_#{Thread.current.object_id}.yaml")
        begin
          state_var_hash = obj.workspace.persist_state_hash.each.with_object({}) { |(k, v), hash| hash[k.to_s] = v }
          rest_ws = {:workspace => obj.workspace.hash_workspace,
                     :inputs    => inputs,
                     :current   => current_info(obj.workspace),
                     :state_var => state_var_hash}.to_yaml
          open(input_file, 'w') { |f| f.puts rest_ws }
          File.delete(output_file) if File.exist?(output_file)

          preamble = rest_method_preamble(input_file, output_file, miq_method_token(obj))
          obj.workspace.num_rest_methods += 1
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Starting ")
          rc, msg, stderr = run_ruby_method(aem.data, preamble)
          $miq_ae_logger.info("<AEMethod [#{aem.fqname}]> Ending")
          process_ruby_method_results(rc, msg, stderr)
          update_workspace(obj, output_file)
        ensure
          obj.workspace.num_rest_methods -= 1
          #File.delete(input_file) if File.exist?(input_file)
          #File.delete(output_file) if File.exist?(output_file)
        end
      end
    end

    REST_RUBY_METHOD_PREAMBLE = <<-RUBY
begin
  require 'date'
  require 'miq_ae_method_wrapper'
  $evm = MiqAeMethodWrapper.new
end

begin
RUBY
    def self.rest_method_preamble(input_file, output_file, token)
      preamble = "$:.unshift('#{Rails.root.join("lib/miq_automation_engine/rest")}')\n"
      preamble << "MIQ_INPUT_FILE = '#{input_file}'\n"
      preamble << "MIQ_OUTPUT_FILE = '#{output_file}'\n"
      preamble << "MIQ_METHOD_TOKEN = '#{token}'\n"
      preamble << REST_RUBY_METHOD_PREAMBLE
      $miq_ae_logger.info("<AEMethod> Preamble")
      $miq_ae_logger.info(preamble)
      preamble
    end

    def self.miq_method_token(obj)
      ae_user = obj.workspace.ae_user
      tm = TokenManager.new("api")
      tm.gen_token("api", :userid => ae_user.userid)
    end

    def self.update_workspace(obj, output_file)
      hash = YAML.load_file(output_file)
      update_object(obj.workspace, hash['workspace'])
      hash['state_var'].each { |k, v| obj.workspace.presist_state_hash[k] = v }
    end

    def self.update_object(workspace, obj_hash)
      path = "/#{obj_hash['namespace']}/#{obj_hash['class']}/#{obj_hash['instance']}"

      obj = find_object(workspace.root, path)
      $miq_ae_logger.error("Object #{path} not found in workspace") unless obj
      raise MiqAeException::Error, "object not found #{path}" unless obj

      update_obj_attributes(obj, obj_hash['attributes']) if obj_hash['attributes']
      update_obj_references(obj, obj_hash['references']) if obj_hash['references']

      obj_hash['MiqAeObject'].each { |hash| update_object(workspace, hash) } if obj_hash['MiqAeObject']
    end

    def self.find_object(obj, object_name)
      return obj if obj.object_name == object_name
      obj.children.each do |child|
        if found = find_object(child, object_name)
          break found
        end
      end
    end

    def self.update_obj_attributes(obj, attributes)
      $miq_ae_logger.info("Updating object #{obj.object_name}")
      attributes.each { |k, v| obj[k] = v }
    end

    def self.update_obj_references(obj, references)
      #TODO: Load the VMDB Object
      references.each { |k, v| obj[k] = v }
    end

    def self.current_info(workspace)
      list = [:current_namespace, :current_class, :current_instance,
              :current_message, :current_method]
      list.each.with_object({}) { |m, hash| hash[m.to_s] = workspace.send(m) }
    end
  end
end
