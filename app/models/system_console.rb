class SystemConsole < ApplicationRecord
  belongs_to :vm
  belongs_to :user

  default_value_for :opened, false

  validates :url_secret, :uniqueness => true

  def connection_params
    {
      :url    => "ws/console/#{url_secret}",
      :secret => secret,
      :proto  => protocol
    }
  end
end
