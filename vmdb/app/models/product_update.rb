require 'digest/md5'
require 'zip/zipfilesystem'
require 'tempfile'
require 'fileutils'

class ProductUpdate < ActiveRecord::Base
  has_one :binary_blob, -> { where(:name => "product_update") }, :as => :resource, :dependent => :destroy
  has_one :release_notes, -> { where(:name => "release_notes") }, :as => :resource, :dependent => :destroy, :class_name => "BinaryBlob"
  has_and_belongs_to_many :miq_servers
  has_and_belongs_to_many :miq_proxies

  include ReportableMixin

  TMP_DIR = File.expand_path(MIQ_TEMP)
  FileUtils.mkdir_p(TMP_DIR) unless File.exist?(TMP_DIR)
  UPDATES_DIR = File.join(TMP_DIR, "miq_updates")
  # Create the temp folder
  FileUtils.mkdir_p(UPDATES_DIR) unless File.exist?(UPDATES_DIR)

  def self.server_dir
    UPDATES_DIR
  end

  def self.sync_from_preloaded
    media_dir = Rails.root.join("product", "media")
    return unless File.exist?(media_dir)

    platforms = ["linux", "windows"]
    architectures = ["x86", "x86_64"]
    component = "smartproxy"

    Dir.foreach(media_dir) { |platform|
      next unless platforms.include?(platform)
      platform_dir = File.join(media_dir, platform)
      Dir.foreach(platform_dir) { |arch|
        next unless architectures.include?(arch)
        arch_dir = File.join(platform_dir, arch)

        Dir.foreach(arch_dir) { |smartproxy|
          next if smartproxy == "." || smartproxy == ".."
          fname = File.join(arch_dir, smartproxy)
          $log.info("MIQ(ProductUpdate.sync_from_product) Considering for upload <#{fname}>")

          version, build = ProductUpdate.smartproxy_version_build(fname, platform)
          if build.nil?
            $log.error("MIQ(ProductUpdate.sync_from_product) Build of component file <#{fname}> is empty")
            next
          end

          md5 = ProductUpdate.md5(fname)

          unless ProductUpdate.find_by_component_and_platform_and_arch_and_md5_and_build(component, platform, arch, md5, build).nil?
            $log.info("MIQ(ProductUpdate.sync_from_product) Component already in VMDB -- skipping")
            next
          end

          pu = ProductUpdate.new
          pu.name          = "Fix #{version}"
          pu.version       = version
          pu.build         = build
          pu.update_type   = "release"
          pu.component     = component
          pu.platform      = platform
          pu.md5           = md5
          pu.arch          = arch
          pu.binary_blob   = BinaryBlob.new(:name => "product_update", :data_type => "executable")
          $log.debug("MIQ(ProductUpdate.sync_from_product) Adding component file <#{fname}> to VMDB with size <#{File.size(fname)}>")
          pu.binary_blob.store_binary(fname)
          pu.save
          $log.info("MIQ(ProductUpdate.sync_from_product) Created Product Update Entry (id=#{pu.id})")
        }
      }
    }
  end

  def self.seed
    # Remote databases need more time to preload product updates
    MiqRegion.my_region.lock(:exclusive, 60 * 10) do
      self.sync_from_preloaded
    end

    # Create the temp folder or clear out any old files
    File.exist?(UPDATES_DIR) ? FileUtils.rm(Dir.glob(File.join(UPDATES_DIR,'*')), :force => true) : Dir.mkdir(UPDATES_DIR)
  end

  def file_from_db(deployment_target = nil)
    # Dump the binary update to a local temp file on the appliance pushing out the proxy...because the ssu.cp is expecting a local file to copy to the remote host
    # Create a file miqserver_4 or miqhost_3
    # Added support for the UI downloading a file via nil deployment target
    basename = case deployment_target
    when MiqServer then "#{deployment_target.class}_#{self.md5}"
    when MiqProxy  then "miqhost_#{self.md5}"
    when NilClass
      download = "#{self.component}_#{self.version}_#{self.build}".gsub(".", "_")
      self.platform.to_s.downcase == "windows" ? download + ".exe" : download
    end

    file = File.join(UPDATES_DIR, basename)
    # If the file already exists check its md5 signature
    if File.exist?(file)
      data = nil
      File.open(file, "rb") {|f| data = f.read; f.close}
      File.delete(file) unless Digest::MD5.hexdigest(data).to_s == self.md5
    end
    self.binary_blob.dump_binary(file) unless File.exist?(file)
    return file
  end

  def cleanup_file(file)
    File.delete(file) if File.exist?(file)
  end

  def self.server_link_to_current_update(server)
    rec = self.find_by_version_and_build_and_component(server.version, server.build, "vmdb")
    return unless rec

    server.upgrade_status = nil
    server.product_updates << rec unless server.product_updates.include?(self)
  end

  private

  def server_validate_update(server)
    res, msg = nil

    # check current server update and validate the update is ok
    res, msg = server_compatible_update?(server)
    return res, msg unless res

    # md5 check should be in the BinaryBlobMixin
    #res, msg = update_md5_ok?
    #return res, msg unless res
    return true
  end

  def server_compatible_update?(server)
    nver = self.version.split(".")
    cver = server.version.split(".")
    return false, "requested version, '#{self.version}', is the same as the current version, '#{server.version}'" if nver == cver

    msg = "requested version, '#{self.version}', is older than the current version, '#{server.version}'"
    idx = 0
    result = loop do
      if nver[idx] == cver[idx]
        idx += 1
        next
      end
      break(nver[idx].to_i > cver[idx].to_i)
    end
    msg = "" if result
    return result, msg
  end

  BUF_SIZE = 64.kilobytes

  def self.md5_from_zipstream(fd)
    hasher = Digest::MD5.new
    while (!fd.eof)
      hasher.update(fd.sysread(BUF_SIZE))
    end
    return hasher.hexdigest
  end

  def self.md5(fname)
    #return Digest::MD5.hexdigest(File.read(fname, "rb"))

    hasher = Digest::MD5.new
    File.open(fname, "rb") do |fd|
      while (!fd.eof)
        hasher.update(fd.readpartial(BUF_SIZE))
      end
    end
    return hasher.hexdigest
  end

  def self.get_smartproxy_version(filename)
    Zip::ZipFile.open(filename) { |z| z.file.read("/host/miqhost/VERSION").strip }
  rescue => err
    raise "Error <#{err}> for file <#{filename}>"
  end

  def self.rpm_version(rpm_name)
    return nil unless MiqEnvironment::Command.is_appliance?

    require 'linux_admin'
    packages = LinuxAdmin::Rpm.list_installed
    return packages[rpm_name] if packages.has_key?(rpm_name)
    $log.warn "(ProductUpdate.rpm_version) RPM package <#{rpm_name}> is not installed"
    nil
  end

  def self.smartproxy_rpm_package_name(platform)
    platform == "windows" ? "mingw32-cfme-host" : nil
  end

  def self.smartproxy_version_build(fname, platform)
    version = build = nil
    rpm_version = self.rpm_version(self.smartproxy_rpm_package_name(platform))

    if rpm_version
      rpm_version, rpm_build = rpm_version.split("-")
      version = self.get_smartproxy_version(fname)
      build = rpm_build.split(".").first if version == rpm_version
    end

    return version, build
  end
end
