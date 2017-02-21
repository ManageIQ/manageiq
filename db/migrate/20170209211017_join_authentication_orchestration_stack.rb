class JoinAuthenticationOrchestrationStack < ActiveRecord::Migration[5.0]
  def change
    create_table :authentication_orchestration_stacks do |t|
      t.bigint :authentication_id
      t.bigint :orchestration_stack_id
      t.index  [:authentication_id, :orchestration_stack_id], :unique => true, :name => "index_authentication_orchestration_stacks"
    end
  end
end
