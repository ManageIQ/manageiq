class ChangeBinaryBlobAndBinaryBlobPartSizeValuesFromCharacterLengthToBytesize < ActiveRecord::Migration
  class BinaryBlob < ActiveRecord::Base
    has_many :binary_blob_parts, :dependent => :delete_all, :order => :id, :class_name => "ChangeBinaryBlobAndBinaryBlobPartSizeValuesFromCharacterLengthToBytesize::BinaryBlobPart"
  end

  class BinaryBlobPart < ActiveRecord::Base
  end

  def up
    say_with_time("Fixing BinaryBlob and BinaryBlobPart sizes") do
      blob_ids = BinaryBlobPart.select(:binary_blob_id).where("size != #{ActiveRecordQueryParts.binary_length}(data)")
      BinaryBlob.where(:id => blob_ids).find_each do |bb|
        bb_size = bb.binary_blob_parts.inject(0) do |total_size, part|
          data = part.read_attribute(:data) # avoid error due to size mismatch

          size = data.bytesize

          # binary_blob_parts size is allowed to be nil
          if part.size && part.size != size
            say "BinaryBlobPart #{part.id}: #{part.size} -> #{size}", :subitem
            part.update_attribute(:size, size)
          end

          total_size + size
        end

        # binary_blobs size is allowed to be nil
        if bb.size && bb.size != bb_size
          say "BinaryBlob     #{bb.id}: #{bb.size} -> #{bb_size}", :subitem
          bb.update_attribute(:size, bb_size)
        end

        # clear the binary_blob_parts from memory
        bb.clear_association_cache
      end
    end
  end

  def down
  end
end
