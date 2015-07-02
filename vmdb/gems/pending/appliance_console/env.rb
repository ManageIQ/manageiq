RAILS_ROOT ||= Pathname.new(__dir__).join("../../..")

module ApplianceConsole
  class Env
    NET_FILE      = "/bin/miqnet.sh"
    ERR_FILE      = "/etc/init.d/miqnet.err"

    def self.[](var)
      File.exist?(NET_FILE) ? `#{NET_FILE} -GET #{var.to_s.upcase}`.chomp : var
    end

    def self.[]=(var, *values)
      # ENV['DHCP'] = false and ENV['HOST'] = nil is a NOP
      return if values == [false] || values == [nil]
      @changed = true
      # Env['DHCP'] = true will send command NET_FILE -DHCP 2> ERR_FILE
      values = [] if values == [true]
      `#{NET_FILE} -#{var.to_s.upcase} #{values.join(" ")} 2> #{ERR_FILE}` if File.exist?(NET_FILE)
    end

    # short term transition until other cli changes are accepted
    class << self
      alias_method :set, :[]=
      alias_method :get, :[]
    end

    def self.error?
      File.size?(ERR_FILE)
    end

    def self.error
      File.read(ERR_FILE) if error?
    end

    def self.clear_errors
      @changed = false
      File.delete(ERR_FILE) if File.exist?(ERR_FILE)
    end

    def self.changed?
      @changed
    end

    def self.rake(task)
      `cd #{RAILS_ROOT} && script/rails runner script/rake #{task} 2> #{ERR_FILE}`
      @changed = true
      !error?
    end
  end
end
