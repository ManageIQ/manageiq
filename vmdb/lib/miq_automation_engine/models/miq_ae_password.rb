require 'miq-password'

class MiqAePassword < MiqPassword
  def self.encrypt(str)
    return str if str.blank? || self.encrypted?(str)
    MiqPassword.encrypt(str)
  end

  def self.decrypt(str)
    MiqPassword.decrypt(str)
  end

  def self.decrypt_if_password(obj)
    obj.kind_of?(MiqAePassword) ? MiqPassword.decrypt(obj.encStr) : obj
  end

  def to_s
    "********"
  end

  def inspect
    "\"#{self}\""
  end

  # Use the same keys for MiqPassword and MiqAePassword
  def self.v0_key
    MiqPassword.v0_key
  end

  def self.v1_key
    MiqPassword.v1_key
  end

  def self.v2_key
    MiqPassword.v2_key
  end
end
