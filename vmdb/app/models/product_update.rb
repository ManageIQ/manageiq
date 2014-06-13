require 'digest/md5'
require 'zip/zipfilesystem'
require 'tempfile'
require 'fileutils'

class ProductUpdate < ActiveRecord::Base
  has_one :binary_blob, :as => :resource, :dependent => :destroy, :conditions => {:name => "product_update"}
  has_one :release_notes, :as => :resource, :dependent => :destroy, :class_name => "BinaryBlob", :conditions => {:name => "release_notes"}
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

  def self.upload(fd, name = nil)
    name ||= fd.original_filename
    block_size = 65536

    filename = File.join(UPDATES_DIR, name)
    filename = "#{filename}_#{Time.now.to_i}" if File.exist?(filename)
    $log.info("MIQ(ProductUpdate.upload) Uploading maintenance bundle to file <#{filename}>")
    raise "file, '#{filename}', already exists" if File.exist?(filename)

    outfd = File.open(filename, "wb")
    data  = fd.read(block_size)
    while !fd.eof do
      outfd.write(data)
      data = fd.read(block_size)
    end
    outfd.write(data) if data
    fd.close
    outfd.chmod(0777)
    outfd.close

    $log.info("MIQ(ProductUpdate.upload) Upload complete (size=#{File.size(filename)}), validating maintenance bundle...")
    begin
      ProductUpdate.validate_bundle(filename)
    rescue => err
      # Remove the Bundle
      $log.debug("MIQ(ProductUpdate.upload) Removing file <#{filename}>")
      File.delete(filename)
      if err.kind_of?(Zip::ZipError) || err.kind_of?(MiqException::MaintenanceBundleInvalid)
        raise(MiqException::MaintenanceBundleInvalid, "Maintenance Bundle Invalid because <#{err.message}>")
      else
        raise
      end
    end
    $log.info("MIQ(ProductUpdate.upload) Queuing processing of maintenance bundle...")
    MiqQueue.put(
      :class_name   => self.to_s,
      :method_name  => "process_bundle",
      :args         => [filename],
      :server_guid  => MiqServer.my_guid
    )
  end

  def self.validate_bundle(fname)
    $log.info("MIQ(ProductUpdate.validate_bundle) Validating Maintenance Bundle <#{fname}>")
    raise(MiqException::MaintenanceBundleInvalid, "Maintenance Bundle does not exist") unless File.exist?(fname)

    Zip::ZipFile.open(fname) { |zipfile|
      # Read in Manifest
      manifest  = YAML.load(zipfile.read("manifest"))

      unless manifest[:release_notes].nil?
        rn_fname = manifest[:release_notes]
        unless rn_fname.nil?
          rn_fname = rn_fname[2..-1] if rn_fname[0,2] == "./"
          raise(MiqException::MaintenanceBundleInvalid, "Release Notes File in manifest <#{rn_fname}> is not in the uploaded bundle") if zipfile.find_entry(rn_fname).nil?
        end
      end

      $log.info("MIQ(ProductUpdate.validate_bundle) Validating #{manifest[:blobs].length} components.") unless manifest[:blobs].nil?

      # For each entry in the Manifest, create a row (if needed) in ProductUpdates table
      manifest[:blobs].each { |bmeta|
        blob_fname = bmeta[:file]
        blob_fname = blob_fname[2..-1] if blob_fname[0,2] == "./"
        $log.info("MIQ(ProductUpdate.validate_bundle) Validating component file <#{blob_fname}>")

        blob = zipfile.find_entry(blob_fname)
        raise(MiqException::MaintenanceBundleInvalid, "Component File in manifest <#{blob_fname}> is not in the uploaded bundle") if blob.nil?
        raise(MiqException::MaintenanceBundleInvalid, "Component File Size (#{blob.size}) of file <#{blob_fname}> does not match size in manifest <#{bmeta[:size]}>") if blob.size != bmeta[:size]
        md5 = blob.get_input_stream { |fd| ProductUpdate.md5_from_zipstream(fd) }
        raise(MiqException::MaintenanceBundleInvalid, "MD5 (#{md5}) of component file <#{blob_fname}> does not match md5 in manifest <#{bmeta[:md5]}>") if md5 != bmeta[:md5]

        $log.info("MIQ(ProductUpdate.validate_bundle) Validated  component file <#{blob_fname}>")
      }
    }

    $log.info("MIQ(ProductUpdate.validate_bundle) Validated  Maintenance Bundle <#{fname}>")
  end

  def self.process_bundle(fname)
    $log.info("MIQ(ProductUpdate.process_bundle) Processing <#{fname}>")

    # Name the Bundle Directory
    bundle_dir = File.join(UPDATES_DIR, Time.now.to_i.to_s)
    $log.debug("MIQ(ProductUpdate.process_bundle) Bundle Directory is <#{bundle_dir}>")

    begin
      # Create Bundle Directory
      Dir.mkdir(bundle_dir) unless File.exist?(bundle_dir)

      # Uncrate Bundle
      $log.info("MIQ(ProductUpdate.process_bundle) Extracting bundle contents.")
      Zip::ZipFile.foreach(fname) { |f|
        $log.debug("MIQ(ProductUpdate.process_bundle) Extracting bundle contents <#{f.name}> to <#{File.join(bundle_dir, File.basename(f.name))}>.")
        f.extract(File.join(bundle_dir, File.basename(f.name)))
      }

      # Read in Manifest
      $log.debug("MIQ(ProductUpdate.process_bundle) Reading manifest file.")
      manifest  = YAML.load_file(File.join(bundle_dir, "manifest"))

      $log.info("MIQ(ProductUpdate.process_bundle) Processing #{manifest[:blobs].length} components.") unless manifest[:blobs].nil?
      # For each entry in the Manifest, create a row (if needed) in ProductUpdates table
      manifest[:blobs].each { |bmeta|
        blob_fname = File.join(bundle_dir, bmeta[:file])
        $log.info("MIQ(ProductUpdate.process_bundle) Processing component file <#{blob_fname}>")

        unless ProductUpdate.find_by_version_and_component_and_platform_and_arch_and_md5(manifest[:version], bmeta[:component], bmeta[:platform], bmeta[:arch], bmeta[:md5]).nil?
          $log.info("MIQ(ProductUpdate.process_bundle) Component already in VMDB -- skipping")
          next
        end

        build = manifest[:build]
        case bmeta[:component].downcase
        when "smartproxy"
          version, build = ProductUpdate.smartproxy_version_build(blob_fname, bmeta[:platform])
          if build.nil?
            $log.error("MIQ(ProductUpdate.process_bundle) Build of component file <#{blob_fname}> is empty")
            next
          end

          if !manifest[:build].nil? && manifest[:build] != build
            $log.error("MIQ(ProductUpdate.process_bundle) Build (#{build}) of component file <#{blob_fname}> does not match build in manifest (#{manifest[:build]})")
            next
          end
        when "vmdb"
          # Parse the file name ('vmdb_install.2.1.0.7-12746') from the manifest to capture the build number
          build = bmeta[:file] if bmeta[:file] =~ /-(\d{4,5})$/
          build = build.split("-").last unless build.nil?
        end

        pu = ProductUpdate.new
        pu.name          = manifest[:name]
        pu.description   = manifest[:description]
        pu.version       = manifest[:version]
        pu.build         = build
        pu.update_type   = manifest[:type]
        pu.component     = bmeta[:component]
        pu.platform      = bmeta[:platform]
        pu.md5           = bmeta[:md5]
        pu.arch          = bmeta[:arch]

        # Add release notes to the record
        unless manifest[:release_notes].nil?
          pu.release_notes = BinaryBlob.new(:name => "release_notes", :data_type => "pdf")
          $log.debug("MIQ(ProductUpdate.process_bundle) Reading Release Notes #{manifest[:release_notes]}.")
          pu.release_notes.store_binary(File.join(bundle_dir, manifest[:release_notes]))
        end

        # Add blob file to the record
        pu.binary_blob = BinaryBlob.new(:name => "product_update", :data_type => "executable")
        $log.debug("MIQ(ProductUpdate.process_bundle) Adding component file <#{blob_fname}> to VMDB with size <#{bmeta[:size]}>")
        pu.binary_blob.store_binary(blob_fname)

        pu.save
        $log.debug("MIQ(ProductUpdate.process_bundle) Created Product Update Entry (id=#{pu.id})")
      }
    ensure
      # Remove the Bundle
      $log.debug("MIQ(ProductUpdate.process_bundle) Removing file <#{fname}>")
      File.delete(fname) if File.exist?(fname)

      # Clean Up Uncrated Bundle
      $log.debug("MIQ(ProductUpdate.process_bundle) Cleaning up contents of <#{bundle_dir}>")
      Dir.foreach(bundle_dir) { |fname|
        next if fname == "." || fname == ".."
        uncrated_file = File.join(bundle_dir, fname)
        $log.debug("MIQ(ProductUpdate.process_bundle) Deleting file <#{uncrated_file}>")
        File.delete(uncrated_file) if File.exist?(uncrated_file)
      }

      # Remove Bundle Directory
      $log.debug("MIQ(ProductUpdate.process_bundle) Removing directory <#{bundle_dir}>")
      Dir.rmdir(bundle_dir) if File.exist?(bundle_dir)
    end
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
    when MiqServer then "#{deployment_target.class.to_s}_#{self.md5}"
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
    File.delete(file) if File.exists?(file)
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
    Zip::ZipFile.open(filename) {|z| z.file.read("/host/miqhost/VERSION")}
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
