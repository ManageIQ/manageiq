require "appliance_console/principal"
require "awesome_spawn"

module ApplianceConsole
  class Certificate
    STATUS_COMPLETE = :complete
    STATUS_RETURN_CODES = [:complete, :no_key, :rejected, :waiting, :error, :waiting]

    attr_accessor :cert_filename
    # root certificate filename
    attr_accessor :root_filename
    attr_accessor :service
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
      @realm   ||= hostname.split(".")[1..-1].join(".").upcase if hostname
    end

    def request
      if no_key? || rejected?
        principal.register
        if rejected?
          request_again
        else
          request_first
        end
        # NOTE: status probably changed
        chown_cert unless rejected?
      end

      if complete?
        yield if block_given?
      end
      self
    end

    def principal
      @principal ||= Principal.new(:hostname => hostname, :realm => realm, :service => service, :ca_name => ca_name)
    end

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
      clear_status
      self
    end

    def request_again
      AwesomeSpawn.run("/usr/bin/getcert", :params => ["resubmit", "-w", "-f", cert_filename])
      clear_status
      self
    end

    def chown_cert
      FileUtils.chown(owner.split(".").first, owner.split(".")[1], cert_filename) if owner && (owner != "root")
      self
    end

    # statuses

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

    def key_filename
      "#{cert_filename.chomp(File.extname(cert_filename))}.key"
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
