class CreateDialogs < ActiveRecord::Migration
  def change
    create_table :dialogs do |t|
      t.string      :name
      t.string      :description
      t.string      :buttons
      t.timestamps
    end

    create_table :dialog_tabs do |t|
      t.string      :name
      t.string      :description
      t.string      :display
      t.timestamps
    end

    create_table :dialog_groups do |t|
      t.string      :name
      t.string      :description
      t.string      :display
      t.timestamps
    end

    create_table :dialog_fields do |t|
      t.string      :name
      t.string      :description
      t.string      :type
      t.string      :data_type          # => :string / :integer / :button / :boolean / :time
      t.string      :notes
      t.string      :notes_display      # => :show / :hide
      t.string      :display            # => :edit / :hide / :show / :ignore
      t.string      :display_method     # => <name>
      t.text        :display_options    # => {:method => ???, :options => {???}}
      t.boolean     :required,          :default => false
      t.string      :required_method
      t.text        :required_options
      t.string      :default_value
      t.text        :values             # => {false => 0, true => 1}
      t.string      :values_method
      t.text        :values_options     # => {:category => :Vm}
      t.text        :options
      t.timestamps
    end

    create_table :dialog_resources do |t|
      t.belongs_to  :parent,      :polymorphic => true, :type => :bigint
      t.belongs_to  :resource,    :polymorphic => true, :type => :bigint
      t.integer     :order
    end
  end
end
