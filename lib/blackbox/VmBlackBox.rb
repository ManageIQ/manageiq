$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../metadata/VmConfig")

require 'ostruct'
require 'yaml'
require 'miq-xml'
require 'xmlStorage'
require 'VmConfig'
require 'digest/md5'

module Manageiq
  class BlackBox
    GLOBAL_CONFIG_FILE = "/miq.yml"

    def initialize(vmName, ost=nil)
      @config_name = vmName
      @write_data_externally = true    # For now we are always writing externally

      ost ||= OpenStruct.new

      if ost.miqVm
        @vmCfg = ost.miqVm.vm.vmConfig
      elsif ost.skipConfig == true
        @vmCfg = VmConfig.new({})
      else
        @vmCfg = VmConfig.new(@config_name)
      end

      # Get path to local data directory
      if ost.config && ost.config.dataDir
        @localDataDir = File.join(ost.config.dataDir, Digest::MD5.hexdigest(@config_name))
      elsif $miqHostCfg && $miqHostCfg.dataDir
        @localDataDir = File.join($miqHostCfg.dataDir, Digest::MD5.hexdigest(@config_name))
      else
        @localDataDir = "/tmp"
      end

      loadGlobalSettings

      @xmlData = loadXmlConfig()
    end

    def self.vmId(vmName)
      Manageiq::BlackBox.new(vmName).vmId
    end

    def vmId=(uuid)
      saveGlobalValue(:vmId, uuid)
    end

    def vmId
      @cfg[:vmId]
    end

    def close
    end

    # This method is used to cleanup local storage data after it is sent to the server.
    def postSync(options = {})
      deleteLocalDataDir(options)
    end

    private

    def loadGlobalSettings
      begin
        @cfg = {:smart=>false}
        @cfg.merge!(YAML.load(readData(GLOBAL_CONFIG_FILE)))
      rescue
      end
    end

    def saveGlobalValue(key, value)
      @cfg[key] = value
      saveGlobalSettings
    end

    def saveGlobalSettings
      x = ""
      YAML.dump(@cfg, x)
      writeData(GLOBAL_CONFIG_FILE, x)
    end

    def deleteLocalDataDir(options={})
      if @write_data_externally || options[:forceDelete]
        if File.exist?(@localDataDir)
          Dir.foreach(@localDataDir) {|f| File.delete(File.join(@localDataDir,f)) unless f[0..0] === "."}
          Dir.delete(@localDataDir)
        end
      end
    end

    def writeData(filename, data)
      Dir.mkdir(@localDataDir, 755) unless File.exist?(@localDataDir)
      filename2 = filename.gsub("/", "_")
      fullpath = File.join(@localDataDir, filename2)
      f = File.open(fullpath, "w")
      f.write(data.to_s)
      f.close
    end

    def readData(filename)
      filename2 = filename.gsub("/", "_")
      fullpath = File.join(@localDataDir, filename2)
      File.read(fullpath)
    end

  end
end
