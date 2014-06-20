class BinaryBlobPart < ActiveRecord::Base
  def self.default_part_size
    @default_part_size ||= 1.megabyte
  end

  def inspect
    # Clean up inspect so that we don't flood script/console
    attrs = self.attribute_names.inject("{") { |s, n| s << "#{n.inspect}=>#{n == "data" ? "\"...\"" : read_attribute(n).inspect}, "; s }
    attrs.chomp!(", ")
    attrs << "}"
    iv = self.instance_variables.inject(" ") { |s, v| s << "#{v}=#{v == "@attributes" ? attrs : self.instance_variable_get(v).inspect}, "; s }
    iv.chomp!(", ")
    iv.rstrip!
    "#{self.to_s.chop}#{iv}>"
  end

  def data
    val = read_attribute(:data)
    raise "size of #{self.class.name} id [#{self.id}] is incorrect" unless self.size.nil? || self.size == val.bytesize
    raise "md5 of #{self.class.name} id [#{self.id}] is incorrect" unless self.md5.nil? || self.md5 == Digest::MD5.hexdigest(val)
    return val
  end

  def data=(val)
    raise ArgumentError, "data cannot be set to nil" if val.nil?
    write_attribute(:data, val)
    self.md5 = Digest::MD5.hexdigest(val)
    self.size = val.bytesize
    return self
  end
end
