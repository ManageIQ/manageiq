class BinaryBlob < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  has_many :binary_blob_parts, -> { order(:id) }, :dependent => :delete_all

  def delete_binary
    self.md5 = self.size = self.part_size = nil
    binary_blob_parts.delete_all
    self.save!
  end

  # Get binary file from database into a raw String
  def binary
    # TODO: Change this to collect the binary_blob_parts in batches, so we are not pulling in every row into memory at once
    data = binary_blob_parts.inject("") { |d, b| d << b.data; d }
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
