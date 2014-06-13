class BinaryBlob < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  has_many :binary_blob_parts, :dependent => :delete_all, :order => :id

  def delete_binary
    self.md5 = self.size = self.part_size = nil
    self.binary_blob_parts.delete_all
    self.save!
  end

  # Get binary file from database into a raw String
  def binary
    # TODO: Change this to collect the binary_blob_parts in batches, so we are not pulling in every row into memory at once
    data = self.binary_blob_parts.inject("") { |d, b| d << b.data; d }
    raise "size of #{self.class.name} id [#{self.id}] is incorrect" unless self.size.nil? || self.size == data.bytesize
    raise "md5 of #{self.class.name} id [#{self.id}] is incorrect" unless self.md5.nil? || self.md5 == Digest::MD5.hexdigest(data)
    return data
  end

  # Set binary file into the database from a raw String
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

  # Write binary file from the database into a file
  def dump_binary(path_or_io)
    dump_size = 0
    hasher = Digest::MD5.new

    begin
      fd = path_or_io.respond_to?(:write) ? path_or_io : File.open(path_or_io, "wb")

      # TODO: Change this to collect the binary_blob_parts in batches, so we are not pulling in every row into memory at once
      self.binary_blob_parts.each do |b|
        data = b.data
        dump_size += data.bytesize
        hasher.update(data)
        fd.write(data)
      end
    ensure
      fd.close unless path_or_io.respond_to?(:write)
    end

    raise "size of #{self.class.name} id [#{self.id}] is incorrect" unless self.size.nil? || self.size == dump_size
    raise "md5 of #{self.class.name} id [#{self.id}] is incorrect" unless self.md5.nil? || self.md5 == hasher.hexdigest
    return true
  end

  # Set binary file into the database from a file
  def store_binary(path)
    self.delete_binary unless self.parts == 0

    self.part_size ||= BinaryBlobPart.default_part_size
    self.md5 = nil
    self.size = 0

    hasher = Digest::MD5.new

    File.open(path, "rb") do |f|
      until f.eof?
        buf = f.read(self.part_size)
        self.size += buf.length
        hasher.update(buf)
        self.binary_blob_parts << BinaryBlobPart.new(:data => buf)
      end
    end

    self.md5 = hasher.hexdigest
    self.save!

    return self
  end

  def parts
    self.binary_blob_parts.size
  end

  def expected_parts
    part_size = self.part_size || BinaryBlobPart.default_part_size
    return (self.size.to_f / part_size).ceil
  end
end
