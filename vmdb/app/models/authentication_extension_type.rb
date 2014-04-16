class AuthenticationExtensionType < ActiveHash::Base
  include ActiveHash::Associations

  # corresponds to Authentication#authtype
  field :authtype
  # short name for the extension type
  field :key
  # readable name for the extension type
  field :name
  # supported data_types:
  # * string
  # * symbol
  # * select (implies symbol, requires options)
  # * password
  # * text (long string)
  # * int
  # * float
  # * date
  # * boolean
  field :data_type
  # options allowed for this configuration type
  # stored as a map, corresponding to the value and data for an option in an
  # html select box
  field :options, :default => {}

  has_many :extensions, :class_name => "AuthenticationExtension"

  add :authtype => :amqp, :key => "ssl", :name => "Require SSL?", :data_type => "boolean"
  add :authtype => :amqp, :key => "alt_ip", :name => "Alternate IP Address", :data_type => "string"
  add :authtype => :amqp, :key => "impl", :name => "AMQP Implementation", :data_type => "select", :options => {:rabbit => "Rabbit", :qpid => "QPid"}.freeze
end
