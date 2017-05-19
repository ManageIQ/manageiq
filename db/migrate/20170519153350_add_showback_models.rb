class AddShowbackModels < ActiveRecord::Migration[5.0]
  def change
    create_table :showback_usage_types do |t|
      t.string     :category
      t.string     :description
      t.string     :measure
      t.text       :dimensions
      t.timestamps
    end

    create_table :showback_events do |t|
      t.jsonb      :data
      t.timestamp  :start_time
      t.timestamp  :end_time
      t.belongs_to :resource, :type => :bigint, :polymorphic => true, :index => true
      t.jsonb      :context
      t.timestamps
    end

    create_table :showback_price_plans do |t|
      t.string     :name
      t.belongs_to :resource, :type => :bigint, :polymorphic => true
      t.string     :description
      t.timestamps
    end

    create_table :showback_rates do |t|
      t.bigint     :fixed_rate_subunit # Columns needed by gem money
      t.string     :fixed_rate_currency
      t.bigint     :variable_rate_subunit # Columns needed by gem money
      t.string     :variable_rate_currency
      t.string     :calculation
      t.string     :category
      t.string     :dimension
      t.jsonb      :screener
      t.datetime   :date
      t.string     :concept
      t.belongs_to :showback_price_plan, :type => :bigint
      t.timestamps
    end
    add_index :showback_rates, %i[category dimension]
    # add_index :showback_rates, :screener, :using => :gin

    create_table :showback_pools do |t|
      t.string     :name
      t.string     :description
      t.timestamp  :start_time
      t.timestamp  :end_time
      t.string     :state
      t.bigint     :accumulated_cost_subunits # Columns needed by gem money
      t.string     :accumulated_cost_currency
      t.references :resource, :type => :bigint, :polymorphic => true, :index => true
      t.timestamps
    end

    create_table :showback_charges do |t|
      t.bigint     :cost_subunits
      t.string     :cost_currency
      t.belongs_to :showback_pool,  :type => :bigint, :index => true
      t.belongs_to :showback_event, :type => :bigint, :index => true
      t.timestamps
    end
  end
end
