class SummaryPresenter
  def initialize(controller, record)
    @controller = controller
    @record  = record
  end
  protected

  extend Forwardable
  def_delegators :@controller, :link_to, :url_for, :pluralize,
    :controller_name, :role_allows, :last_date, :time_ago_in_words,
    :number_with_delimiter, :number_to_human_size,
    :get_vmdb_config, :session
end
