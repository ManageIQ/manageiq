require 'util/miq_tempfile'
require_relative '../../MiqVm/MiqVm'

#
# TODO: Create common base class for MiqOpenStackInstance and MiqOpenStackImage
# and factor out common code. Also, refactor MiqVm so it can be a proper super class.
#

class MiqOpenStackInstance
  attr_reader :vmConfigFile

  SUPPORTED_METHODS = [:rootTrees, :extract, :diskInitErrors]

  def initialize(instance_id, openstack_handle)
    @instance_id      = instance_id
    @openstack_handle = openstack_handle
    @vmConfigFile     = instance_id
  end

  def compute_service
    @compute_service ||= @openstack_handle.compute_service
  end

  def image_service
    @image_service ||= @openstack_handle.detect_image_service
  end

  def instance
    @instance ||= compute_service.servers.get(@instance_id)
  end

  def snapshot_metadata
    @snapshot_metadata ||= instance.metadata.length > 0 && instance.metadata.get(:miq_snapshot)
  end

  def snapshot_image_id
    @snapshot_image_id ||= snapshot_metadata && snapshot_metadata.value
  end

  def unmount
    return unless @miq_vm
    @miq_vm.unmount
    @temp_image_file.unlink
  end

  def create_evm_snapshot(options = {})
    log_prefix = "MIQ(#{self.class.name}##{__method__}) instance_id=[#{@instance_id}]"

    miq_snapshot = nil
    if snapshot_image_id
      $log.debug "#{log_prefix}: Found pointer to existing snapshot: #{snapshot_image_id}"
      miq_snapshot = begin
        image_service.images.get(snapshot_image_id)
      rescue => err
        $log.debug "#{log_prefix}: #{err}"
        $log.debug err.backtrace.join("\n")
        nil
      end

      if miq_snapshot
        raise "Already has an EVM snapshot: #{miq_snapshot.name}"
      else
        $log.debug "#{log_prefix}: Snapshot does not exist, deleting metadata"
        snapshot_metadata.destroy
      end
    else
      $log.debug "#{log_prefix}: No existing snapshot detected for: #{instance.name}"
    end

    $log.debug "#{log_prefix}: Snapshotting instance: #{instance.name}..."
    # TODO: pass in snapshot name.
    rv = compute_service.create_image(instance.id, "EvmSnapshot", :description => options[:desc])
    rv.body['image'][:service] = image_service
    miq_snapshot = Fog::Image::OpenStack::Image.new(rv.body['image'])
    miq_snapshot.collection = image_service.images

    until miq_snapshot.status == "active"
      $log.debug "#{log_prefix}: #{miq_snapshot.status}"
      sleep 1
      miq_snapshot.reload
    end
    $log.debug "#{log_prefix}: #{miq_snapshot.status}"
    $log.debug "#{log_prefix}: EVM snapshot creation complete"

    instance.metadata.update(:miq_snapshot => miq_snapshot.id)
    return miq_snapshot
  rescue => err
    $log.error "#{log_prefix}, error: #{err}"
    $log.debug err.backtrace.join("\n") if $log.debug?
    raise
  end

  def delete_evm_snapshot(image_id)
    log_prefix = "MIQ(#{self.class.name}##{__method__}) snapshot=[#{image_id}]"

    snapshot = begin
      image_service.images.get(image_id)
    rescue => err
      $log.debug "#{log_prefix}: #{err}"
      $log.debug err.backtrace.join("\n")
      nil
    end

    if snapshot
      begin
        if snapshot_image_id != image_id
          $log.warn "#{log_prefix}: pointer from instance doesn't match #{snapshot_image_id}"
        end
        $log.info "#{log_prefix}: deleting snapshot image"
        snapshot.destroy
        snapshot_metadata.destroy
      rescue => err
        $log.debug "#{log_prefix}: #{err}"
        $log.debug err.backtrace.join("\n") if $log.debug?
      end
    else
      $log.info "#{log_prefix}: no longer exists, deleting references"
    end
  end

  private

  def miq_vm
    raise "Instance: #{instance.id}, does not have snapshot reference." unless snapshot_image_id
    @miq_vm ||= begin
      @temp_image_file = get_image_file(snapshot_image_id)
      hardware  = "scsi0:0.present = \"TRUE\"\n"
      hardware += "scsi0:0.filename = \"#{@temp_image_file.path}\"\n"

      diskFormat = image_service.get_image(snapshot_image_id).headers['X-Image-Meta-Disk_format']
      $log.debug "diskFormat = #{diskFormat}"

      ost = OpenStruct.new
      ost.rawDisk = diskFormat == "raw"
      MiqVm.new(hardware, ost)
    end
  end

  def get_image_file(image_id)
    log_prefix = "#{self.class.name}##{__method__}"

    image = image_service.get_image(image_id)
    raise "Image #{image_id} not found" unless image
    $log.debug "#{log_prefix}: image = #{image.class.name}"

    iname = image.headers['X-Image-Meta-Name']
    isize = image.headers['X-Image-Meta-Size'].to_i
    $log.debug "#{log_prefix}: iname = #{iname}"
    $log.debug "#{log_prefix}: isize = #{isize}"

    raise "Image: #{iname} (#{image_id}) is empty" unless isize > 0

    tot = 0
    tf = MiqTempfile.new(iname, :encoding => 'ascii-8bit')
    $log.debug "#{log_prefix}: saving image to #{tf.path}"
    response_block = lambda do |buf, _rem, sz|
      tf.write buf
      tot += buf.length
      $log.debug "#{log_prefix}: response_block: #{tot} bytes written of #{sz}"
    end

    #
    # We're calling the low-level request method here, because
    # the Fog "get image" methods don't currently support passing
    # a response block. We should attempt to remedy this in Fog
    # upstream and modify this code accordingly.
    #
    rv = image_service.request(
      :expects        => [200, 204],
      :method         => 'GET',
      :path           => "images/#{image_id}",
      :response_block => response_block
    )

    tf.close

    checksum = rv.headers['X-Image-Meta-Checksum']
    $log.debug "#{log_prefix}: Checksum: #{checksum}" if $log.debug?
    $log.debug "#{log_prefix}: #{`ls -l #{tf.path}`}" if $log.debug?

    if tf.size != isize
      $log.error "#{log_prefix}: Error downloading image #{iname}"
      $log.error "#{log_prefix}: Downloaded size does not match image size #{tf.size} != #{isize}"
      raise "Image download failed"
    end

    tf
  end

  def method_missing(sym, *args)
    return super unless SUPPORTED_METHODS.include? sym
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
