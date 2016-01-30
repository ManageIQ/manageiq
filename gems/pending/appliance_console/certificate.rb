require "appliance_console/principal"
require "awesome_spawn"

module ApplianceConsole
  class Certificate
    STATUS_COMPLETE = :complete

    # map `getcert status` return codes to something more descriptive
    # 0 => :complete -- keys/certs generated
    # 1 => :no_key   -- either certmonger is down, or we havent asked for the key yet. (assuming the latter)
    # 2 => :rejected -- request failed. we need to resubmit once we fix stuff
    # 3 => :waiting  -- couldn't contact CA, will try again
    # 4 => :error    -- certmonger is not configured properly
    # 5 => :waiting  -- waiting for CA to send back the certificate
    STATUS_RETURN_CODES = [:complete, :no_key, :rejected, :waiting, :error, :waiting]

    # key filename defaults to certificate name w/ different extension
    attr_writer   :key_filename
    attr_accessor :cert_filename
    # root certificate filename
    attr_accessor :root_filename
    attr_accessor :service
    # 509 v3 extesions for stuff to signify purpose of this certificate (e.g.: client)
    attr_accessor :extensions
    attr_accessor :owner

    # hostname of current machine
    attr_accessor :hostname
    # ipa realm
    attr_accessor :realm
    # name of certificate authority
    attr_accessor :ca_name

    def initialize(options = {})
      options.each { |n, v| public_send("#{n}=", v) }
      @ca_name ||= "ipa"
      @extensions ||= %w(server client)
      @realm ||= hostname.split(".")[1..-1].join(".").upcase if hostname
    end

    def request
      if should_request_key?
        principal.register
        request_certificate
        # NOTE: status probably changed
        set_owner_of_key unless rejected?
      end

      if complete?
        make_certs_world_readable
        yield if block_given?
      end
      self
    end

    def principal
      @principal ||= Principal.new(:hostname => hostname, :realm => realm, :service => service, :ca_name => ca_name)
    end

    def request_certificate
      if rejected?
        request_again
      else
        request_first
      end
      clear_status
    end

    # workaround
    # currently, the -C is not run after the root certificate is written
    def make_certs_world_readable
      FileUtils.chmod(0644, [root_filename, cert_filename].compact)
    end

    def set_owner_of_key
      FileUtils.chown(owner.split(".").first, owner.split(".")[1], key_filename) if owner && (owner != "root")
      self
    end

    # statuses

    def should_request_key?
      no_key? || rejected?
    end

    def no_key?
      status == :no_key
    end

    def rejected?
      status == :rejected
    end

    def complete?
      status == :complete
    end

    def clear_status
      @status = nil
    end

    def status
      @status ||= key_status
    end

    private

    def request_first
      params = {
        nil  => "request",
        "-c" => ca_name,
        "-v" => nil, # verbose
        "-w" => nil, # wait til completion if possible
        "-k" => key_filename,
        "-f" => cert_filename,
        "-N" => principal.subject_name,
        "-K" => principal.name,
        "-C" => "chmod 644 #{cert_filename} #{root_filename}",
        "-U" => key_ext_usage
      }
      params["-F"] = root_filename if root_filename

      AwesomeSpawn.run!("/usr/bin/getcert", :params => params)
      self
    end

    def request_again
      AwesomeSpawn.run!("/usr/bin/getcert", :params => ["resubmit", "-w", "-f", cert_filename])
      self
    end

    def key_filename
      @key_filename || "#{cert_filename.chomp(File.extname(cert_filename))}.key"
    end

    def key_status
      ret = AwesomeSpawn.run("/usr/bin/getcert", :params => ["status", "-f", cert_filename])
      STATUS_RETURN_CODES[ret.exit_status]
    end

    def key_ext_usage
      extensions.collect { |n| "id-kp-#{n}Auth" }.join(",")
    end
  end
end
