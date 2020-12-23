class FiberChannelAddress < SanAddress
  def get_address_info
    [_("wwpn"), wwpn]
  end
end
