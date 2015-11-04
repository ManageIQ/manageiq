module MiqAeMethodService
  class MiqAeServiceClassification < MiqAeServiceModelBase
    expose :parent,    :association => true
    expose :namespace, :method      => :ns
    expose :category
    expose :name
    expose :to_tag
    expose :entries

    def self.categories
      wrap_results(Classification.categories)
    end
  end
end
