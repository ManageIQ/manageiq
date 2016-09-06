class AddRetirementColsToLoadBalancers < ActiveRecord::Migration[5.0]
  def change
    add_column :load_balancers, :retired,              :boolean
    add_column :load_balancers, :retires_on,           :date
    add_column :load_balancers, :retirement_warn,      :bigint
    add_column :load_balancers, :retirement_last_warn, :datetime
    add_column :load_balancers, :retirement_state,     :string
    add_column :load_balancers, :retirement_requester, :string
  end
end
