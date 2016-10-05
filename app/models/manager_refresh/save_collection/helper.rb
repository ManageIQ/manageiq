module ManagerRefresh::SaveCollection
  module Helper
    def save_dto_inventory(dto_collection)
      save_dto_inventory_multi(dto_collection.parent.send(dto_collection.association),
                               dto_collection,
                               :use_association,
                               dto_collection.manager_ref)
      store_ids_for_new_dto_records(dto_collection.parent.send(dto_collection.association),
                                    dto_collection,
                                    dto_collection.manager_ref)
      dto_collection.saved = true
    end
  end
end
