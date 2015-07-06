module ActiveRecord
  class Base
    #
    # Used by the REST API
    #
    def self.paginate(req_offset, req_limit)
      offset(req_offset).limit(req_limit)
    end
  end
end
