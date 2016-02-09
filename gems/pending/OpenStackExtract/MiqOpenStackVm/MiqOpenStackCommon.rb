module MiqOpenStackCommon
  def disk_format_glance_v1(snapshot_image_id)
    image_service.get_image(snapshot_image_id).headers['X-Image-Meta-Disk_format']
  end

  def disk_format_glance_v2(snapshot_image_id)
    image_service.images.get(snapshot_image_id).disk_format
  end

  def disk_format(snapshot_image_id)
    send("disk_format_glance_#{image_service.version}", snapshot_image_id)
  end

  def get_image_file_glance_v2(image_id)
    log_prefix = "#{self.class.name}##{__method__}"

    image = image_service.images.get(image_id)
    raise "Image #{image_id} not found" unless image
    $log.debug "#{log_prefix}: image = #{image.class.name}"

    iname = image.name
    isize = image.size.to_i
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

    _rv = image.download_data(:response_block => response_block)
    tf.close

    # TODO(lsmola) Fog download_data doesn't support header returned, it returns body by hard. We need to wrap the
    # result load_response like in Fog::OpenStack::Collection. The header will be accessible as rv.response.headers
    # checksum = rv.headers['Content-Md5']
    # $log.debug "#{log_prefix}: Checksum: #{checksum}" if $log.debug?
    $log.debug "#{log_prefix}: #{`ls -l #{tf.path}`}" if $log.debug?

    if tf.size != isize
      $log.error "#{log_prefix}: Error downloading image #{iname}"
      $log.error "#{log_prefix}: Downloaded size does not match image size #{tf.size} != #{isize}"
      raise "Image download failed"
    end
    tf
  end

  def get_image_file_glance_v1(image_id)
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

  def get_image_file_common(image_id)
    send("get_image_file_glance_#{image_service.version}", image_id)
  end
end
