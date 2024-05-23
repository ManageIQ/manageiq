class ExternalUrl < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :user

  validates :url, :format => URI::DEFAULT_PARSER.make_regexp, :allow_nil => false
end
