class BinaryBlobPart < ApplicationRecord
  def self.default_part_size
    @default_part_size ||= 1.megabyte
  end

  def inspect
    # Clean up inspect so that we don't flood script/console
    attrs = attribute_names.inject("{") { |s, n| s << "#{n.inspect}=>#{n == "data" ? "\"...\"" : read_attribute(n).inspect}, "; s }
    attrs.chomp!(", ")
    attrs << "}"
    iv = instance_variables.inject(" ") { |s, v| s << "#{v}=#{v == "@attributes" ? attrs : instance_variable_get(v).inspect}, "; s }
    iv.chomp!(", ")
    iv.rstrip!
    "#{to_s.chop}#{iv}>"
  end

  def data
    val = read_attribute(:data)
    unless size.nil? || size == val.bytesize
      raise _("size of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    unless md5.nil? || md5 == Rails.application.config.digest_class.hexdigest(val)
      raise _("md5 of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    val
  end

  def data=(val)
    raise ArgumentError, "data cannot be set to nil" if val.nil?
    write_attribute(:data, val)
    self.md5 = Rails.application.config.digest_class.hexdigest(val)
    self.size = val.bytesize
    self
  end
end
