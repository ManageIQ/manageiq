require 'pathname'
require 'fileutils'

RAILS_ROOT ||= Pathname.new(File.dirname(__FILE__)).join("../../vmdb")
module ApplianceConsole
  CERT_DIR = "#{RAILS_ROOT}/certs"
  KEY_FILE = "#{CERT_DIR}/v2_key"

  class KeyConfiguration
    def create_key(force = true)
      if File.exist?(KEY_FILE)
        return self unless force
        FileUtils.rm(KEY_FILE)
      end
      MiqPassword.generate_symmetric(KEY_FILE)
      self
    end
  end
end
