module DtoMixin
  extend ActiveSupport::Concern

  class_methods do
    def dto_collection(parent, association)
      ::DtoCollection.new(self,
                          :dependencies => @dto_dependencies,
                          :manager_ref  => @dto_manager_ref,
                          :attributes   => @dto_attributes,
                          :association  => association,
                          :parent       => parent)
    end

    def dto_dependencies(*args)
      @dto_dependencies = args
    end

    def dto_manager_ref(*args)
      @dto_manager_ref = args
    end

    def dto_attributes(*args)
      @dto_attributes = args
    end
  end
end
