module DtoMixin
  extend ActiveSupport::Concern

  class_methods do
    def dto_collection
      ::DtoCollection.new(self,
                          :dependencies => @dto_dependencies,
                          :manager_ref  => @dto_manager_ref,
                          :attributes   => @dto_attributes)
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
