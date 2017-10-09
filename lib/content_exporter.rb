module ContentExporter
  def self.export_to_hash(initial_hash, key, elements)
    hash = initial_hash.dup
    %w(id created_on updated_on).each { |k| hash.delete(k) }
    hash[key] = elements.collect { |e| e.export_to_array.first[key] unless e.nil? }
    hash
  end
end
