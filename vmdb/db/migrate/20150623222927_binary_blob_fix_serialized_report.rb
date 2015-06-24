class BinaryBlobFixSerializedReport < ActiveRecord::Migration
  class BinaryBlob < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
    has_many :binary_blob_parts, -> { order(:id) }

    YAML_ATTRS = [:table, :sub_table, :filter_summary, :extras, :ids, :scoped_association, :html_title, :file_name, :extras, :record_id,
                  :tl_times, :user_categories, :trend_data, :performance, :include_for_find, :report_run_time, :chart, :reserved]

    def serialize_report_to_hash
      val = binary

      if val.include?("!ruby/object:MiqReport")
        val.sub!(/MiqReport/, 'Hash')
      else
        raise "unexpected format of binary data encountered, '#{val.inspect}'"
      end

      raw_hash = YAML.load(val)
      new_hash = YAML_ATTRS.each_with_object(raw_hash['attributes'].to_hash) { |k, h| h[k.to_s] = raw_hash[k.to_s] }

      YAML.dump(new_hash)
    end

    def serialize_hash_to_report
      val = binary
      if val.starts_with?("---")
        YAML.dump(MiqReport.new(YAML.load(val)))
      else
        raise "unexpected format of report attribute encountered, '#{val.inspect}'"
      end
    end

    def delete_binary
      self.md5 = self.size = self.part_size = nil
      self.binary_blob_parts.delete_all
      self.save!
    end

    def binary
      data = self.binary_blob_parts.inject("") { |d, b| d << b.data; d }
      raise "size of #{self.class.name} id [#{self.id}] is incorrect" unless self.size.nil? || self.size == data.bytesize
      raise "md5 of #{self.class.name} id [#{self.id}] is incorrect" unless self.md5.nil? || self.md5 == Digest::MD5.hexdigest(data)
      return data
    end

    def binary=(data)
      data.force_encoding('ASCII-8BIT')
      self.delete_binary unless self.parts == 0
      return self if data.bytesize == 0

      self.part_size ||= BinaryBlobPart.default_part_size
      self.md5 = Digest::MD5.hexdigest(data)
      self.size = data.bytesize

      until data.bytesize == 0
        buf = data.slice!(0..self.part_size)
        self.binary_blob_parts << BinaryBlobPart.new(:data => buf)
      end
      self.save!

      return self
    end

    def parts
      self.binary_blob_parts.size
    end
  end

  def up
    say_with_time("Converting BinaryBlob report results to a serialized hash") do
      BinaryBlob.where(:resource_type=>'MiqReportResult').each do |bb|
        bb.binary = bb.serialize_report_to_hash
      end
    end
  end

  def down
    say_with_time("Converting BinaryBlob report results back to a serialized MiqReport") do
      BinaryBlob.where(:resource_type=>'MiqReportResult').each do |bb|
        bb.binary = bb.serialize_hash_to_report
      end
    end
  end
end
