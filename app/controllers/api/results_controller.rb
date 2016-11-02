module Api
  class ResultsController < BaseController
    before_action :set_additional_attributes, :only => [:index, :show]

    def results_search_conditions
      MiqReportResult.for_user(@auth_user_obj).where_clause.ast
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(result_set)
    end
  end
end
