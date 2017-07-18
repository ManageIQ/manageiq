
module DMiqVimSync
  #
  # This method is called - with the cacheLock held - when returning an object from the cache to the client.
  # It used to produce a full recursive copy of the object before releasing the lock.
  # When used in the broker, the DRB layer would then marshal the copy of the object to return it to the remote client.
  # This new scheme enables us to hold the cacheLock until after DRB marshals the object, eliminating the need
  # for this method to produce a full recursive copy.
  #
  # The lock count of the cacheLock is incremented, so when this method's caller releases the lock, the lock
  # will still be held. The object to be returned and the cacheLock are wraped in a MiqDrbReturn object
  # and returned to the DRB layer, which will marshal the object and release the lock. See below.
  #
  def dupObj(obj)
    return(obj) unless @cacheLock.sync_locked?
    $vim_log.debug "DMiqVim::dupObj: LOCKING [#{Thread.current.object_id}] <#{obj.object_id}>" if $vim_log.debug?
    @cacheLock.sync_lock(:SH)
    (MiqDrbReturn.new(obj, @cacheLock))
  end
end # module DMiqVimSync

class DRb::DRbMessage
  EXPECTED_MARSHAL_VERSION = [Marshal::MAJOR_VERSION, Marshal::MINOR_VERSION].freeze
  alias_method :dump_original, :dump

  #
  # This is the DRB half of the dupObj locking scheme. If we get a MiqDrbReturn object,
  # we marshal the object it wraps and release the lock.
  #
  def dump(obj, error = false)
    #
    # Place a temp hold on the object until the client registers it.
    #
    obj.holdBrokerObj if obj.respond_to?(:holdBrokerObj)

    obj_to_dump = obj.kind_of?(MiqDrbReturn) ? obj.obj : obj

    result = dump_original(obj_to_dump, error)

    valid = true
    size = result[0..3].unpack("N")[0]
    if @load_limit < size
      $vim_log.error("DRb packet size too large: #{size}")
      valid = false
    end

    marshal_version = result[4, 2].unpack("C2")
    if marshal_version != EXPECTED_MARSHAL_VERSION
      $vim_log.error("Marshal version mismatch: expected: #{EXPECTED_MARSHAL_VERSION} got: #{marshal_version}")
      valid = false
    end

    unless valid
      $vim_log.error("object: #{obj.inspect}")
      $vim_log.error("buffer:\n#{result[0, 1024].hex_dump}")
      $vim_log.error("caller:\n#{caller.join("\n")}")
    end

    return result unless obj.kind_of?(MiqDrbReturn)

    begin
      return result
    ensure
      if obj.lock && obj.lock.sync_locked?
        $vim_log.debug "DRb::DRbMessage.dump: UNLOCKING [#{Thread.current.object_id}] <#{obj.obj.object_id}>" if $vim_log.debug?
        obj.lock.sync_unlock
      end
    end
  end
end # class DRb::DRbMessage
