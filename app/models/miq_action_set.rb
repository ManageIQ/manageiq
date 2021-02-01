class MiqActionSet < MiqSet
  def self.display_name(number = 1)
    n_('Action Set', 'Action Sets', number)
  end
end
