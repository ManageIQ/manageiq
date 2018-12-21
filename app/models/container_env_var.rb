class ContainerEnvVar < ApplicationRecord
  belongs_to :container
  def self.display_name(number = 1)
    n_('Container Environment Variable', 'Container Environment Variables', number)
  end
end
