require 'fs/MiqFS/modules/WebDAV'

class MiqContainerGroup
  attr_reader :uri, :verify_mode, :headers, :guest_os

  def initialize(uri, verify_mode, headers, guest_os)
    @uri         = uri
    @verify_mode = verify_mode
    @headers     = headers
    @guest_os    = guest_os
  end

  def rootTrees
    web_dav_ost = OpenStruct.new(
      :uri         => @uri,
      :verify_mode => @verify_mode,
      :headers     => @headers,
      :guest_os    => @guest_os
    )
    [MiqFS.new(WebDAV, web_dav_ost)]
  end
end
