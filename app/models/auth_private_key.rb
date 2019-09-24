class AuthPrivateKey < Authentication
  acts_as_miq_taggable

  def self.display_name(number = 1)
    n_('Private Key', 'Private Keys', number)
  end
end
