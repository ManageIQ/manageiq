class ExternalUrl < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :user

  validates :url, :format => URI::RFC2396_PARSER.make_regexp, :allow_nil => false
end
