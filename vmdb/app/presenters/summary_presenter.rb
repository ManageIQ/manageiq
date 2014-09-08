class SummaryPresenter
  def initialize(controller, record)
    @controller = controller
    @record  = record
  end

  def self.include_summary_methods(presenter_class, included_into)
    presenter_class.instance_methods.find_all { |method| method =~ /_group_/ }.each do |method|
      included_into.send(:define_method, method) do
        presenter_class.new(self, @record).send(method)
      end
    end
  end

  protected

  extend Forwardable
  def_delegators :@controller, :link_to, :url_for, :pluralize,
    :controller_name, :role_allows, :last_date, :time_ago_in_words,
    :number_with_delimiter, :number_to_human_size,
    :get_vmdb_config, :session, :set_controller_action
end

class Module
  def include_summary_presenter(presenter_class)
    SummaryPresenter.include_summary_methods(presenter_class, self)
  end
end
