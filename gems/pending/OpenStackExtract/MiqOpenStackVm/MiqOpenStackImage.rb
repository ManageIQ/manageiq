require 'util/miq_tempfile'
require_relative '../../MiqVm/MiqVm'

class MiqOpenStackImage

  SUPPORTED_METHODS = [ :vmRootTrees, :extract, :diskInitErrors ]

	def initialize(image_id, args)
    @image_id     = image_id
    @fog_compute  = args[:fog_compute]
    @fog_image    = args[:fog_image]
    @args         = args

    raise ArgumentError, "#{self.class.name}: required arg fog_compute missing"  unless @fog_compute
    raise ArgumentError, "#{self.class.name}: required arg fog_image missing"    unless @fog_image
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
      MiqVm.new(hardware)
    end
  end

  def get_image_file
    log_pref = "#{self.class.name}##{__method__}"

    cimage = @fog_compute.images.get(@image_id)
    raise "Image #{@image_id} not found" unless cimage
    $log.debug "#{log_pref}: cimage = #{cimage.class.name}"

    iname = cimage.attributes[:name]
    isize = cimage.attributes['OS-EXT-IMG-SIZE:size'].to_i
    $log.debug "#{log_pref}: iname = #{iname}"
    $log.debug "#{log_pref}: isize = #{isize}"

    raise "Image: #{iname} (#{@image_id}) is empty" unless isize > 0

    tot = 0
    rv = nil

    tf = MiqTempfile.new(iname, :encoding => 'ascii-8bit')
    $log.debug "#{log_pref}: saving image to #{tf.path}"
    response_block = lambda do |buf, rem, sz|
      tf.write buf
      tot += buf.length
      $log.debug "#{log_pref}: response_block: #{tot} bytes written of #{sz}"
    end

    #
    # We're calling the low-level request method here, because
    # the Fog "get image" methods don't currently support passing
    # a response block. We should attempt to remedy this in Fog
    # upstream and modify this code accordingly.
    #
    rv = @fog_image.request(
      :expects => [200, 204],
      :method  => 'GET',
      :path    => "images/#{@image_id}",
      :response_block => response_block
    )

    tf.close

    checksum = rv.headers['X-Image-Meta-Checksum']
    $log.debug "#{log_pref}: Checksum: #{checksum}" if $log.debug?
    $log.debug "#{log_pref}: #{`ls -l #{tf.path}`}" if $log.debug?

    if tf.size != isize
      $log.error "#{log_pref}: Error downloading image #{iname}"
      $log.error "#{log_pref}: Downloaded size does not match image size #{tf.size} != #{isize}"
      raise "Image download failed"
    end

    return tf
  end

  def method_missing(sym, *args)
    super unless SUPPORTED_METHODS.include? sym
    return miq_vm.send(sym) if args.empty?
    return miq_vm.send(sym, args)
  end

end
