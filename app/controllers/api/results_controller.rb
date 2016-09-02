module Api
  class ResultsController < BaseController
    def show
      @additional_attributes = %w(result_set)
      super
    end
  end
end
