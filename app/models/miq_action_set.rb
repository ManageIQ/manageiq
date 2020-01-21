class MiqActionSet < ApplicationRecord
  acts_as_miq_set

  def self.display_name(number = 1)
    n_('Action Set', 'Action Sets', number)
  end
end
