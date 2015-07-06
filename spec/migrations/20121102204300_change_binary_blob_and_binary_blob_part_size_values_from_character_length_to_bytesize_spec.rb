# encoding: utf-8

require "spec_helper"
require Rails.root.join("db/migrate/20121102204300_change_binary_blob_and_binary_blob_part_size_values_from_character_length_to_bytesize.rb")

describe ChangeBinaryBlobAndBinaryBlobPartSizeValuesFromCharacterLengthToBytesize do
  migration_context :up do
    let(:binary_blob_stub)      { migration_stub(:BinaryBlob) }
    let(:binary_blob_part_stub) { migration_stub(:BinaryBlobPart) }

    it "corrects size column values to bytesize" do
      utf8_string =  "--- Quota \xE2\x80\x93 Max CPUs\n...\n"

      blob = binary_blob_stub.create!
      2.times do
        binary_blob_part_stub.create!(:binary_blob_id => blob.id, :data => utf8_string, :size => utf8_string.length) # instead of the correct bytesize
        blob.update_attribute(:size, (blob.size || 0) + utf8_string.length)
      end

      migrate

      blob.reload
      blob.size.should == utf8_string.bytesize * 2
      blob.binary_blob_parts.each {|part| part.size.should == utf8_string.bytesize }
    end
  end
end
