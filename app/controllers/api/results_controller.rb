module Api
  class ResultsController < BaseController
    before_action :set_additional_attributes, :only => [:show]

    private

    def set_additional_attributes
      @additional_attributes = %w(result_set)
    end
  end
end
