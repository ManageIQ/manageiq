module ActiveRecordPreloadScopes
  # based upon active record 6.1
  def records_for(ids)
    # use our logic if passing in [ActiveRecord::Base] or passing in a loaded Relation/scope
    unless (preload_scope.kind_of?(Array) && preload_scope.first.kind_of?(ActiveRecord::Base)) ||
            preload_scope.try(:loaded?)
      return super
    end

    preload_scope.each do |record|
      owner = owners_by_key[convert_key(record[association_key_name])].first
      association = owner.association(reflection.name)
      association.set_inverse_instance(record)
    end
  end
end

ActiveRecord::Associations::Preloader::Association.prepend(ActiveRecordPreloadScopes)
