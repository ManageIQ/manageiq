module Vmdb
  module Appliance
    def self.VERSION
      @EVM_VERSION ||= File.read(File.join(File.expand_path(Rails.root), "VERSION")).strip
    end

    def self.BUILD
      @EVM_BUILD ||= get_build
    end

    def self.BUILD_NUMBER
      @EVM_BUILD_NUMBER ||= self.BUILD.nil? ? "N/A" : self.BUILD.split("-").last   # Grab the build number after the last hyphen
    end

    private

    def self.get_build
      build_file = File.join(File.expand_path(Rails.root), "BUILD")

      if File.exists?(build_file)
        build = File.read(build_file).strip.split("-").last
      else
        date  = Time.now.strftime("%Y%m%d%H%M%S")
        sha   = `git rev-parse --short HEAD`.chomp
        build = "#{date}_#{sha}"
      end

      build
    end
  end
end
