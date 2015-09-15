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
end
