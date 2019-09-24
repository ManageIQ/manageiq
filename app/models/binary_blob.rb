class BinaryBlob < ApplicationRecord
  include_concern 'Purging'

  belongs_to :resource, :polymorphic => true
  has_many :binary_blob_parts, -> { order(:id) }, :dependent => :delete_all

  def delete_binary
    self.md5 = self.size = self.part_size = nil
    binary_blob_parts.delete_all
    self.save!
  end

  # Get binary file from database into a raw String
  def binary
    data = binary_blob_parts.pluck(:data).join
    unless size.nil? || size == data.bytesize
      raise _("size of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    unless md5.nil? || md5 == Digest::MD5.hexdigest(data)
      raise _("md5 of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    data
  end

  # Set binary file into the database from a raw String
  def binary=(data)
    data.force_encoding('ASCII-8BIT')
    delete_binary unless parts == 0
    return self if data.bytesize == 0

    self.part_size ||= BinaryBlobPart.default_part_size
    self.md5 = Digest::MD5.hexdigest(data)
    self.size = data.bytesize

    until data.bytesize == 0
      buf = data.slice!(0..self.part_size)
      binary_blob_parts << BinaryBlobPart.new(:data => buf)
    end
    self.save!

    self
  end

  # Write binary file from the database into a file
  def dump_binary(path_or_io)
    dump_size = 0
    hasher = Digest::MD5.new

    begin
      fd = path_or_io.respond_to?(:write) ? path_or_io : File.open(path_or_io, "wb")

      # TODO: Change this to collect the binary_blob_parts in batches, so we are not pulling in every row into memory at once
      binary_blob_parts.each do |b|
        data = b.data
        dump_size += data.bytesize
        hasher.update(data)
        fd.write(data)
      end
    ensure
      fd.close unless path_or_io.respond_to?(:write)
    end

    unless size.nil? || size == dump_size
      raise _("size of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    unless md5.nil? || md5 == hasher.hexdigest
      raise _("md5 of %{name} id [%{number}] is incorrect") % {:name => self.class.name, :number => id}
    end
    true
  end

  # Set binary file into the database from a file
  def store_binary(path)
    delete_binary unless parts == 0

    self.part_size ||= BinaryBlobPart.default_part_size
    self.md5 = nil
    self.size = 0

    hasher = Digest::MD5.new

    File.open(path, "rb") do |f|
      until f.eof?
        buf = f.read(self.part_size)
        self.size += buf.length
        hasher.update(buf)
        binary_blob_parts << BinaryBlobPart.new(:data => buf)
      end
    end

    self.md5 = hasher.hexdigest
    self.save!

    self
  end

  def parts
    binary_blob_parts.size
  end

  def expected_parts
    part_size = self.part_size || BinaryBlobPart.default_part_size
    (self.size.to_f / part_size).ceil
  end

  def serializer
    data_type == "YAML" ? YAML : Marshal
  end

  def data
    serializer.load(binary)
  end

  def store_data(data_type, the_data)
    self.data_type = data_type
    self.binary = serializer.dump(the_data)
  end
end
