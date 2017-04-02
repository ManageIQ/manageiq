class ShowbackModels < ActiveRecord::Migration[5.0]
  def up
    create_table :showback_measure_types, :id => :bigserial, :force => :cascade do |t|
      t.string     :category
      t.string     :description
      t.string     :measure
      t.text       :dimensions, :array => true, :default => []
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end

    create_table :showback_events do |t|
      t.json       :data
      t.timestamp  :start_time  # when start the event
      t.timestamp  :end_time    # when finish the event
      t.bigint     :resource_id      # id of name model about reference the event in C&U
      t.string     :resource_type    # name model about reference the event in C&U
      t.json       :context, :default => {}
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end
    add_index  :showback_events, :resource_id
    add_index  :showback_events, :resource_type

    create_table :showback_tariffs, :id => :bigserial, :force => :cascade do |t|
      t.string     :name
      t.string     :description
      t.belongs_to :resource, :allow_nil => false, :type => :bigint, :polymorphic => true
      t.timestamps
    end

    create_table :showback_rates, :id => :bigserial, :force => :cascade do |t|
      t.decimal    :fixed_cost,    :allow_nil  => true, :default => nil
      t.decimal    :variable_cost, :allow_nil  => true, :default => nil
      t.string     :calculation,   :allow_nil  => false
      t.string     :category,      :allow_nil  => false
      t.string     :dimension,     :allow_nil  => false
      t.datetime   :date
      t.string     :concept
      t.belongs_to :showback_tariff, :type => :bigint
      t.timestamps
    end
    add_index :showback_rates, :category
    add_index :showback_rates, [:category, :dimension, :showback_tariff_id, :calculation], :unique => true, :name => 'unique_measure_type_for_rate'

    create_table :showback_buckets, :id => :bigserial, :force => :cascade do |t|
      t.string     :name
      t.string     :description
      t.references :resource, :polymorphic => true, :type => :bigint, :index => true
      t.timestamps
    end

    create_table :showback_charges, :id => :bigserial, :force => :cascade do |t|
      t.decimal    :fixed_cost,    :allow_nil  => true
      t.decimal    :variable_cost, :allow_nil  => true
      t.belongs_to :showback_bucket, :type => :bigint, :index => true
      t.belongs_to :showback_event,  :type => :bigint, :index => true
      t.timestamps
    end
  end

  def down
    drop_table :showback_measure_types
    drop_table :showback_events
    drop_table :showback_tariffs
    drop_table :showback_rates
    drop_table :showback_buckets
    drop_table :showback_charges
  end
end
