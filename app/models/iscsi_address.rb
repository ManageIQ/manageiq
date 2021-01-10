class IscsiAddress < SanAddress
  def address_value
    iqn
  end

  def self.display_name(number = 1)
    n_('iqn', 'iqn', number)
  end
end
