class SettingsChange < ActiveRecord::Base
  serialize :value

  belongs_to :resource, :polymorphic => true

  def key_path
    key.to_s.split("/").drop(1)
  end
end
