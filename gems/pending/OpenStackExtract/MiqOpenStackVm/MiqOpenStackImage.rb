require 'util/miq_tempfile'
require_relative '../../MiqVm/MiqVm'
require_relative 'MiqOpenStackCommon'

class MiqOpenStackImage
  include MiqOpenStackCommon

  attr_reader :vmConfigFile

  SUPPORTED_METHODS = [:rootTrees, :extract, :diskInitErrors]

  def initialize(image_id, args)
    @image_id     = image_id
    @os_handle    = args[:os_handle]
    @args         = args
    @vmConfigFile = image_id

    raise ArgumentError, "#{self.class.name}: required arg os_handle missing"    unless @os_handle
    @fog_image    = @os_handle.detect_image_service
    raise ArgumentError, "#{self.class.name}: required arg fog_image missing"    unless @fog_image
  end

  def image_service
    @image_service ||= @os_handle.detect_image_service
  end

  def unmount
    return unless @miq_vm
    @miq_vm.unmount
    @temp_image_file.unlink
  end

  private

  def miq_vm
    @miq_vm ||= begin
      @temp_image_file = get_image_file
      hardware  = "scsi0:0.present = \"TRUE\"\n"
      hardware += "scsi0:0.filename = \"#{@temp_image_file.path}\"\n"

      diskFormat = disk_format(@image_id)
      $log.debug "diskFormat = #{diskFormat}"

      ost = OpenStruct.new
      ost.rawDisk = diskFormat == "raw"
      MiqVm.new(hardware, ost)
    end
  end

  def get_image_file
    get_image_file_common(@image_id)
  end

  def method_missing(sym, *args)
    super unless SUPPORTED_METHODS.include? sym
    return miq_vm.send(sym) if args.empty?
    miq_vm.send(sym, args)
  end

  def respond_to_missing?(sym, *args)
    if SUPPORTED_METHODS.include?(sym)
      true
    else
      super
    end
  end
end
