class IscsiAddress < SanAddress
  def get_address_info
    [_("iqn"), iqn]
  end
end
