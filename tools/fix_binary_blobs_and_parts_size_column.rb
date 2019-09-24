#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

puts "Fixing BinaryBlob and BinaryBlobPart sizes"

blob_ids = BinaryBlobPart.select(:binary_blob_id).where("size != LENGTH(data)")
BinaryBlob.where(:id => blob_ids).find_each do |bb|
  bb_size = bb.binary_blob_parts.inject(0) do |total_size, part|
    data = part.read_attribute(:data) # avoid error due to size mismatch

    size = data.bytesize

    # binary_blob_parts size is allowed to be nil
    if part.size && part.size != size
      puts "BinaryBlobPart #{part.id}: #{part.size} -> #{size}"
      part.update_attribute(:size, size)
    end

    total_size + size
  end

  # binary_blobs size is allowed to be nil
  if bb.size && bb.size != bb_size
    puts "BinaryBlob     #{bb.id}: #{bb.size} -> #{bb_size}"
    bb.update_attribute(:size, bb_size)
  end

  # clear the binary_blob_parts from memory
  bb.send(:clear_association_cache)
end
