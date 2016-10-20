require 'util/miq_tempfile'
require_relative '../../MiqVm/MiqVm'
require_relative 'MiqOpenStackCommon'

#
# TODO: Create common base class for MiqOpenStackInstance and MiqOpenStackImage
# and factor out common code. Also, refactor MiqVm so it can be a proper super class.
#

class MiqOpenStackInstance
  include MiqOpenStackCommon

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

  def create_snapshot(options = {})
    log_prefix = "MIQ(#{self.class.name}##{__method__}) instance_id=[#{@instance_id}]"

    $log.debug "#{log_prefix}: Snapshotting instance: #{instance.name}..."

    snapshot = compute_service.create_image(instance.id, options[:name], :description => options[:desc])

    $log.debug "#{log_prefix}: #{snapshot.status}"
    $log.debug "#{log_prefix}: snapshot creation complete"

    return snapshot.body["image"]
  rescue => err
    $log.error "#{log_prefix}, error: #{err}"
    $log.debug err.backtrace.join("\n") if $log.debug?
    raise
  end

  def delete_snapshot(image_id)
    delete_evm_snapshot(image_id)
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
        raise "Already has an EVM snapshot: #{miq_snapshot.name}, with id: #{miq_snapshot.id}"
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

    miq_snapshot = image_service.images.get(rv.body['image']['id'])

    until miq_snapshot.status.upcase == "ACTIVE"
      $log.debug "#{log_prefix}: #{miq_snapshot.status}"
      sleep 1
      # TODO(lsmola) identity is missing in Glance V2 object, fix it in Fog, then miq_snapshot.reload will work
      # miq_snapshot.reload
      miq_snapshot = image_service.images.get(miq_snapshot.id)
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

      diskFormat = disk_format(snapshot_image_id)
      $log.debug "diskFormat = #{diskFormat}"

      ost = OpenStruct.new
      ost.rawDisk = diskFormat == "raw"
      MiqVm.new(hardware, ost)
    end
  end

  def get_image_file(image_id)
    get_image_file_common(image_id)
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
