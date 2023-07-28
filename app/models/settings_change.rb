class SettingsChange < ApplicationRecord
  serialize :value

  validates :key, :format => %r{\A/[^/]+(/[^/]+)*\z}
  belongs_to :resource, :polymorphic => true

  def key_path
    key.to_s.split("/").drop(1).collect(&:to_sym)
  end
end
