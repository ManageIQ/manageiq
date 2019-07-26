class Budget < ApplicationRecord
  has_many :budget_histories, :dependent => :nullify
  belongs_to :resource, :polymorphic => true
  has_many :chargeable_field_budgets, :dependent => :destroy
  has_many :chargeable_fields, :through => :chargeable_field_budgets, :source => :chargeable_field, :dependent => :destroy

  def name
    "budget-#{resource&.name}"
  end

  def consumption
    cost_keys = chargeable_fields.map(&:cost_key)
    budget_histories.sum do |budget_history|
      cost_keys.sum do |cost_key|
        cost = budget_history.send(cost_key)
        cost ? cost : 0
      end
    end
  end

  def remaining_budget
    is_numeric?(amount) ? amount - consumption : 0
  end

  def budget_available?
   remaining_budget > 0
  end

  def generate_chargeback_report
    # report = MiqReport.find_by(:name => 'chargeback')
    # report.queue_generate_table(:userid => 'admin')
    # report._async_generate_table(MiqTask.last.id, {:userid => 'admin', :mode => "async", :report_source => "Requested by user"})

    # report.miq_report_results

    [MiqReportResult.last].each do |rr|
      rr.result_set.each do |rs|
        bh = BudgetHistory.find_or_create_by(:interval_range => rs['display_range'], :budget => self)
        rs.each do |key, value|
          next if key == "id"
          if bh.respond_to?(key)
            bh.send("#{key}=", value)
          end
        end

        self.budget_histories << bh
      end
    end
  end

  def self.check_all
    Budget.all.each do |b|
      b.check
    end
  end

  def check
    generate_chargeback_report
    unless budget_available?
      case action.to_sym
      when :notify
        Notification.create(:initiator => User.first, :type => 'budget_reached', :options => {:message => "You have now reached the limit on your budget for tenant #{resource.name}. Budget ($ #{amount}) has been exceed by $ #{remaining_budget.abs}" } )
      end
    else
      Notification.create(:initiator => User.first, :type => 'budget_available', :options => {:message => "You have still available the budget for tenant #{resource.name}: $ #{remaining_budget.abs} ($ #{amount})" } )
    end
  end
end
