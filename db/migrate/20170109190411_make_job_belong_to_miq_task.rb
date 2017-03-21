class MakeJobBelongToMiqTask < ActiveRecord::Migration[5.0]
  def change
    add_reference :jobs, :miq_task, :type => "bigint", :index => true
  end
end
