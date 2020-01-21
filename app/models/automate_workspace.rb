class AutomateWorkspace < ApplicationRecord
  include UuidMixin
  belongs_to :user
  belongs_to :tenant
  validates :tenant, :presence => true
  validates :user, :presence => true

  def href_slug
    Api::Utils.build_href_slug(self.class, guid)
  end

  def merge_output!(hash)
    if hash['objects'].nil? || hash['state_vars'].nil?
      raise ArgumentError, "No objects or state_vars specified for edit"
    end

    self[:output] = (output || {}).deep_merge(hash)
    save!
    self
  end

  def decrypt(object_name, attribute)
    ManageIQ::Password.decrypt(encrypted_value(object_name, attribute))
  rescue ArgumentError
    ""
  rescue ManageIQ::Password::PasswordError
    ""
  end

  def encrypt(object_name, attribute, value)
    hash = {'objects' => {}, 'state_vars' => {}}
    hash.store_path('objects', object_name, attribute, "password::#{ManageIQ::Password.encrypt(value)}")
    merge_output!(hash)
  end

  private

  def encrypted_value(object_name, attribute)
    value = fetch_value(object_name, attribute)
    raise ArgumentError, "#{object_name} : Attribute #{attribute} not found" unless value
    raise ArgumentError, "#{object_name} : Attribute #{attribute} invalid type" unless value.kind_of?(String)
    match_data = /^password::(.*)/.match(value)
    raise ArgumentError, "Attribute #{attribute} is not a password type" unless match_data
    match_data[1]
  end

  def fetch_value(object_name, attribute)
    if object_name == "method_parameters"
      input.fetch_path(object_name, attribute)
    else
      input.fetch_path('objects', object_name, attribute)
    end
  end
end
