$:.push("#{File.dirname(__FILE__)}/../../lib/util")

require 'open-uri'
require 'digest/md5'
require 'net/http'
require 'miq-encode'
require 'monitor'
require 'platform'
require 'miq-process'

module Manageiq
  class AgentMgmt
    @@monitor = Monitor.new

  def self.cleanup_temp_files()
    return if $miqExtDir.nil?

    process_name = Platform::OS == :win32 ? "ruby" : "miqhost"
    ruby_processes = MiqProcess.get_active_process_by_name(process_name)
    return if ruby_processes.empty?

    search_path = File.join(File.dirname($miqExtDir).gsub("\\","/"), ".miq-*/miqhost.pid")
    Dir.glob(search_path).each do |file|
      begin
        pid = nil
        File.open(file, "rb") {|f| pid = f.read.to_i; f.close}
        next if Process.pid == pid
        unless ruby_processes.include?(pid)
          $log.info "Deleting #{File.dirname(file)} based on non-running pid: [#{pid}]"
          FileUtils.rm_rf File.dirname(file)
        end
      rescue => error
        $log.error "MIQ(cleanup_temp_files) Error: #{error}, #{error.backtrace.join("/n")}"
      end
    end
  end

    def self.cleanup_miqhost_builds(targetDir, miqhost_keep)
      files = self.collect_filenames(targetDir)
      if files.length > miqhost_keep.to_i
        miqhost_keep.to_i.times{files.pop}
        files.each{|file|
          $log.info "MIQ(UpdateAgent-cleanup_miqhost_builds), deleting #{file}"
          File.delete(file[:filename])}
      end
    end

    def self.collect_filenames(dir)
      begin
        files = Array.new
        Dir.glob(File.join(dir, "miqhost.*")).each do |file|
          files.push(:filename=>file, :miq_host_build=>File.extname(file).gsub(/\./,"").split("-").last)
        end
        files.sort!{ |file1, file2| file1[:miq_host_build]<=>file2[:miq_host_build]}
        return files
      rescue => error
        $log.error "MIQ(UpdateAgent-collect_filenames): #{error}"
      end
    end

    def self.downloadAgent(agentURI, targetDir, miqhost_keep, props)
      # Check if the requested file is already downloaded with the proper stats
      return true if self.agentExist?(targetDir, props)

      self.cleanup_miqhost_builds(targetDir, miqhost_keep)

      # Get local filename
      dl_file = getAgentPath(targetDir, props)

      self.fork_process("miq_download") do
        $log.info "Download starting for [#{dl_file}]" if $log

  			meta = {}; data = nil
        open(agentURI) {|ret| data = ret.read; meta = ret.meta}

        uri_status = meta["status"].to_i
        if uri_status == 200 || (uri_status == 0 && data.length == meta['content-length'].to_i)
          # Delete any existing file
          File.delete(dl_file) if File.exists?(dl_file)

          # Now write the file
          File.open(dl_file, "wb") {|f| f.write(data); f.close}
          File.utime(Time.now, Time.at(props[:mtime]), dl_file)
          $log.info "Download complete for [#{dl_file}]." if $log
        else
          $log.warn "Failed to download module [#{dl_file}].  Status=[#{uri_status}]" if $log
        end
      end

      # We need to read the file back in since the above code may run in a forked process
      # and we do not have visibility to the data
      if File.exists?(dl_file)
        # Validate MD5
        data = nil
        File.open(dl_file, "rb") {|f| data = f.read; f.close}
        data_md5 = Digest::MD5.hexdigest(data).to_s

        # Determine if we want to remove the downloaded file and raise an error
        unless data_md5 == props[:md5]
          File.delete(dl_file) if File.exists?(dl_file)
          raise "MD5 Signature does not match for downloaded data [#{data_md5}] and expected signature [#{props[:md5]}].  Downloaded data size[#{data.length}]"
        end
      else
        raise "Failed to download module [#{dl_file}]."
      end
		end

    def self.agentExist?(targetDir, props)
        return agent_exist_error_message(targetDir, props) rescue false
    end

		def self.agent_exist_error_message(targetDir, props)
			file = getAgentPath(targetDir, props)

			# Check File existance
			raise "file [#{file}] does not exist" unless File.exists?(file)

			# Check Size
			raise "file [#{file}] size [#{File.size(file)}] does not match expected size [#{props[:size]}]" unless File.size(file).eql?(props[:size])

			# Check MD5
			md5file = Digest::MD5.new
			File.open(file, "rb") {|f| md5file << f.read; f.close}
			raise "file [#{file}] MD5 [#{md5file}] does not match expected MD5 [#{props[:md5]}]" unless md5file.to_s === props[:md5]

			# File Matches
			return true
		end

		def self.getAgentPath(targetDir, props)
		    return getAgentBuildPath(targetDir, props[:build])
		end

		def self.getAgentBuildPath(targetDir, build)
		    return File.join(targetDir, "miqhost.#{build}")
		end

		def self.logUpload(hostId, myUrl, targetDir, props)
      return if $log.nil?

      @@monitor.synchronize do
        self.fork_process("miq_logupload") do
          # Collect all the currently logging filenames so we can
          # ensure that they get sent to the server
          logFiles = []
          upload_files = []
          logFiles = $log.outputters.collect {|o| File.basename(o.filename) rescue nil}.compact
          $log.info "Checking for log files in: <#{targetDir}>"

          # Convert the last upload time from an int to Time object.
          # If it is not passed, default to Time.at(0)
          lastUploadTime = Time.at(props[:lastUploadTime]) rescue Time.at(0)
          $log.info "Skipping log files before: <#{lastUploadTime.utc.iso8601}>"

          # Loop over all the logs and send any logs newer than the specified time.
          Dir.glob(File.join(targetDir, "*.log")).each do |l|
            # Skip zero byte files
            next if File.zero?(l)

            # Get the modified time of the log file
            mtime = File.mtime(l)
            if not logFiles.include?(File.basename(l))
              # If the current files modified time earlier than the lastUpload time skip it.
              if mtime < lastUploadTime
                $log.debug "Skipping log file upload for  [#{File.basename(l)}] [#{mtime}]"
                next
              end
            end
            upload_files << l
          end

          current_idx = 0
          upload_files.each do |l|
            current_idx += 1
            begin
              $log.info "Uploading log file [#{File.basename(l)}]"
              data = nil; File.open(l, "rb") {|f| data = f.read; f.close}
              query = {"id" => hostId, "filename" => File.basename(l), "data" => MIQEncode.encode(data), "mtime"=>File.mtime(l).to_i,
                "current" => current_idx, "total" => upload_files.length, "completed" => current_idx == upload_files.length}

              # Merge the options passed in so we can pass them back to the server side
              query.merge!(props)

              # Check if we are calling http or https and do proper setup.
              url = URI.parse(myUrl)
              if url.scheme == "https"
                req = Net::HTTP::Post.new(url.path)
                req.set_form_data(query, '&')
                http = Net::HTTP.new(url.host, url.port)
                http.use_ssl = true
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                res = http.start {|http| http.request(req) }
              else
                res = Net::HTTP.post_form(url, query)
              end
            rescue => err
              $log.error "error sending log to server #{url}, #{err}"
              return false
            end

            if ["200", "201"].include?(res.code)
              $log.debug "Request successful: Code: #{res.code}, Message: #{res.msg}"
            else
              $log.warn "Request failed: Code: #{res.code}, Message: #{res.msg}"
              return false
            end
          end
        end
      end
      return true
		end

    def self.fork_process(process_name = "miq_process")
      # Fork the process only on Linux
      if Platform::IMPL == :linux
        # Set the module description so init.d does not send the
        # shutdown message to this forked process
        fpid = fork {$0 = process_name; yield}
        $log.info "Waiting for external process [#{fpid}] to complete."
        fstatus = Process.waitpid2(fpid)
        $log.info "External process [#{fpid}] completed.  Status: [#{fstatus[1].inspect}]"
      else
        yield
      end
    end
	end
end

module OpenURI
  def OpenURI.open_http(buf, target, proxy, options) # :nodoc:
    if proxy
      raise "Non-HTTP proxy URI: #{proxy}" if proxy.class != URI::HTTP
    end

    if target.userinfo
      raise ArgumentError, "userinfo not supported.  [RFC3986]"
    end

    require 'net/http'
    klass = Net::HTTP
    if URI::HTTP === target
      # HTTP or HTTPS
      if proxy
        klass = Net::HTTP::Proxy(proxy.host, proxy.port)
      end
      target_host = target.host
      target_port = target.port
      request_uri = target.request_uri
    else
      # FTP over HTTP proxy
      target_host = proxy.host
      target_port = proxy.port
      request_uri = target.to_s
    end

    http = klass.new(target_host, target_port)
    if target.class == URI::HTTPS
      require 'net/https'
      http.use_ssl = true
      #GMM http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      http.cert_store = store
    end
    if options.include?(:read_timeout)
      http.read_timeout = options[:read_timeout]
    end

    header = {}
    options.each {|k, v| header[k] = v if String === k }

    resp = nil
    http.start {
      if target.class == URI::HTTPS
        # xxx: information hiding violation
        sock = http.instance_variable_get(:@socket)
        if sock.respond_to?(:io)
          sock = sock.io # 1.9
        else
          sock = sock.instance_variable_get(:@socket) # 1.8
        end
        #GMM sock.post_connection_check(target_host)
      end
      req = Net::HTTP::Get.new(request_uri, header)
      if options.include? :http_basic_authentication
        user, pass = options[:http_basic_authentication]
        req.basic_auth user, pass
      end
      http.request(req) {|response|
        resp = response
        if options[:content_length_proc] && Net::HTTPSuccess === resp
          if resp.key?('Content-Length')
            options[:content_length_proc].call(resp['Content-Length'].to_i)
          else
            options[:content_length_proc].call(nil)
          end
        end
        resp.read_body {|str|
          buf << str
          if options[:progress_proc] && Net::HTTPSuccess === resp
            options[:progress_proc].call(buf.size)
          end
        }
      }
    }
    io = buf.io
    io.rewind
    io.status = [resp.code, resp.message]
    resp.each {|name,value| buf.io.meta_add_field name, value }
    case resp
    when Net::HTTPSuccess
    when Net::HTTPMovedPermanently, # 301
         Net::HTTPFound, # 302
         Net::HTTPSeeOther, # 303
         Net::HTTPTemporaryRedirect # 307
      throw :open_uri_redirect, URI.parse(resp['location'])
    else
      raise OpenURI::HTTPError.new(io.status.join(' '), io)
    end
  end
end
