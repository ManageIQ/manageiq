class CustomAttribute < ApplicationRecord
  ALLOWED_API_VALUE_TYPES = %w(DateTime Time Date).freeze
  ALLOWED_API_SECTIONS = %w(metadata cluster_settings).freeze
  belongs_to :resource, :polymorphic => true
  serialize :serialized_value

  validates :name, :format => {:with => /\A[\p{Alpha}_][\p{Alpha}_\d\$]*\z/, :message => "must begin with a letter (a-z, but also letters with diacritical marks and non-Latin letters) or an underscore (_). Subsequent characters can be letters, underscores, digits (0-9), or dollar signs ($)"}

  def value=(value)
    self.serialized_value = value
    self[:value] = value
  end

  def stored_on_provider?
    source == "VC"
  end

  def value_type
    serialized_value ? serialized_value.class.to_s.downcase.to_sym : :string
  end
end
