class ApiController
  module Initializer
    extend ActiveSupport::Concern

    included do
      Api::Initializer.new.go
    end
  end
end
