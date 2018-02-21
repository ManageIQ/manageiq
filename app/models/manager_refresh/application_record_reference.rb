module ManagerRefresh
  class ApplicationRecordReference
    attr_reader :base_class_name, :id

    # ApplicationRecord is very bloaty in memory, so this class server for storing base_class and primary key
    # of the ApplicationRecord, which is just enough for filling up relationships
    #
    # @param base_class_name [String] A base class of the ApplicationRecord object
    # @param id [Bigint] Primary key value of the ApplicationRecord object
    def initialize(base_class_name, id)
      @base_class_name = base_class_name
      @id              = id
    end
  end
end
