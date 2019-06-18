class DialogFieldAssociationValidator
  class DialogFieldAssociationCircularReferenceError < RuntimeError; end
  def check_for_circular_references(hash, k, collection = [])
    raise DialogFieldAssociationCircularReferenceError, "#{k} already exists in #{collection}" if collection.include?(k)
    collection << k
    hash[k]&.each do |val|
      check_for_circular_references(hash, val, collection.dup)
    end
    nil
  end
end
