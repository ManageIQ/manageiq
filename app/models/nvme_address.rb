class NvmeAddress < SanAddress
  def address_value
    wwpn
  end

  def self.display_name(number = 1)
    n_('wwpn', 'wwpn', number)
  end
end
