class BinaryBlobPart < ActiveRecord::Base
  def self.default_part_size
    @default_part_size ||= begin
      if ActiveRecord::Base.connection.adapter_name != "MySQL"
        1.megabyte
      else
        # MySQL has a built in query string size limit of 1MB.  The ActiveRecord
        #   adapter for MySQL escapes binary data by converting it into a hex
        #   string, thus making 2 characters for every 1 byte.  We must also factor
        #   in some overhead for the rest of the query, hence the 512.kilobytes - 1.kilobyte.
        #
        #   There is a setting in the mysql configuration file which can be set to
        #   increase the maximum query string size limit.  Under the section [mysqld]
        #   the following line can be added (or edited):
        #     max_allowed_packet=16M
        #   More info can be found here: http://dev.mysql.com/doc/refman/5.1/en/packet-too-large.html
        overhead = 1.kilobyte
        size = 0
        begin
          result = ActiveRecord::Base.connection.execute("show variables like 'max_allowed_packet'")
          result = result.fetch_row unless result.nil?
          result = result[1] unless result.nil?
          size = result.to_i
        rescue
        end

        size - overhead > 1.megabyte ? 1.megabyte : 512.kilobytes - overhead
      end
    end
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
