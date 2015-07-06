require 'awesome_spawn'

module ApplianceConsole
  # Kerberos principal
  class Principal
    attr_accessor :ca_name
    attr_accessor :hostname
    attr_accessor :realm
    attr_accessor :service
    # kerberos principal name
    attr_accessor :name

    def initialize(options = {})
      options.each { |n, v| public_send("#{n}=", v) }
      @ca_name ||= "ipa"
      @realm = @realm.upcase if @realm
      @name ||= "#{service}/#{hostname}@#{realm}"
    end

    def register
      request if ipa? && !exist?
    end

    def subject_name
      "CN=#{hostname},OU=#{service},O=#{realm}"
    end

    def ipa?
      @ca_name == "ipa"
    end

    private

    def exist?
      AwesomeSpawn.run("/usr/bin/ipa", :params => ["service-find", "--principal", name]).success?
    end

    def request
      # using --force because these services tend not to be in dns
      # this is like VERIFY_NONE
      AwesomeSpawn.run!("/usr/bin/ipa", :params => ["service-add", "--force", name])
    end
  end
end
