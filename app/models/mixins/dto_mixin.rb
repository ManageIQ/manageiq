module DtoMixin
  extend ActiveSupport::Concern

  class_methods do
    def dto_collection(parent, association)
      ::ManagerRefresh::DtoCollection.new(self,
                                          :manager_ref => @dto_manager_ref,
                                          :attributes  => @dto_attributes,
                                          :association => association,
                                          :parent      => parent)
    end

    def dto_manager_ref(*args)
      @dto_manager_ref = args
    end

    def dto_attributes(*args)
      @dto_attributes = args
    end
  end
end
