module ManagerRefresh
  class RefreshParserDto
    def initialize(ems, options = nil)
      @ems     = ems
      @options = options || {}
      @data    = {:_dto_collection => true}
    end

    def process_dto_collection(collection, key)
      collection.each do |item|
        _uid, new_result = yield(item)
        next if new_result.blank?

        dto = @data[key].new_dto(new_result)
        @data[key] << dto
      end
    end

    def add_dto_collection(model_class, association, manager_ref = nil)
      @data[association] = ::ManagerRefresh::DtoCollection.new(model_class,
                                                               :parent      => @ems,
                                                               :association => association,
                                                               :manager_ref => manager_ref)
    end

    def add_cloud_manager_db_cached_dto(model_class, association, manager_ref = nil)
      @data[association] = ::ManagerRefresh::DtoCollection.new(model_class,
                                                               :parent      => @ems.parent_manager,
                                                               :association => association,
                                                               :manager_ref => manager_ref,
                                                               :strategy    => :local_db_cache_all)
    end

    class << self
      def ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end
    end
  end
end
