class TestBuilderHelper
  def self.construct_tst_support
    ActiveRecord::Migration.create_table "tsts" do |test|
      test.column "task_id",          :integer
      test.column "task",             :string
      test.column "callback",         :string
      test.column "task_result",      :boolean
      test.column "callback_result",  :boolean
    end
    MiqWorker.instance_variable_set("@server", 1)
    MiqWorker.start_a_worker("priority")
    MiqWorker.start_a_worker("generic")
  end
  def self.delete_tst_support
    MiqWorker.stop_workers
    ActiveRecord::Migration.drop_table "tsts"
  end
end

# A test class
class Tst < ActiveRecord::Base
  def self.get_all_tasks
    Tst.find(:all)
  end

  def self.get_task_by_task_id(task_id)
    Tst.find_by_task_id(task_id)
  end
end

class TstTask
  def self.task1(args)
    tst = Tst.find_by_task_id(args.to_i)
    if tst
      tst.task = 'task1'
      tst.save!
      begin
        sleep 2
        tst.task_result = true
      rescue
      ensure
        tst.task = 'done'
        tst.save!
      end
    end
  end

    def self.task2(args)
      tst = Tst.find_by_task_id(args.to_i)
      if tst
        tst.task = 'task2'
        tst.save!
        begin
          sleep 2
          tst.task_result = true
        rescue
        ensure
          tst.task = 'done'
          tst.save!
        end
      end
    end
  end

  class TstCallBack
    def self.call_back1(args)
      tst = Tst.find_by_task_id(args.to_i)
      if tst
        tst.callback = 'call_back1'
        tst.save!
        begin
          sleep 1
          tst.callback_result = true
        rescue
        ensure
          tst.callback  = 'done'
          tst.save!
        end
      end
    end

    def self.call_back2(args)
      tst = Tst.find_by_task_id(args.to_i)
      if tst
        tst.callback = 'call_back2'
        tst.save!
        begin
          sleep 1
          tst.callback_result = true
        rescue
        ensure
          tst.callback  = 'done'
          tst.save!
        end
      end
    end
  end
