describe ManagerRefresh::Target do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_cloud, :zone => @zone)

    @vm_1 = FactoryGirl.create(
      :vm_cloud,
      :ext_management_system => @ems,
      :ems_ref               => "vm_1"
    )

    @vm_2 = FactoryGirl.create(
      :vm_cloud,
      :ext_management_system => @ems,
      :ems_ref               => "vm_2"
    )
  end

  context ".load" do
    it "intializes correct ManagerRefresh::Target.object with a :manager_id" do
      target_1 = ManagerRefresh::Target.load(
        :manager_id  => @ems.id,
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_1).to(
        have_attributes(
          :manager     => @ems,
          :manager_id  => @ems.id,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )
      )
    end

    it "intializes correct ManagerRefresh::Target.object with a :manager " do
      target_1 = ManagerRefresh::Target.load(
        :manager     => @ems,
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_1).to(
        have_attributes(
          :manager     => @ems,
          :manager_id  => @ems.id,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )
      )
    end

    it "raises exception when manager not provided in any form" do
      data = {
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      }

      expect { ManagerRefresh::Target.load(data) }.to raise_error("Provide either :manager or :manager_id argument")
    end

    context ".dump" do
      it "intializes correct ManagerRefresh::Target.object with a :manager_id" do
        target_1 = ManagerRefresh::Target.load(
          :manager_id  => @ems.id,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.dump).to(
          eq(
            :manager_id  => @ems.id,
            :event_id    => nil,
            :association => :vms,
            :manager_ref => {:ems_ref => @vm_1.ems_ref},
            :options     => {:opt1 => "opt1", :opt2 => "opt2"}
          )
        )
      end

      it "intializes correct ManagerRefresh::Target.object with a :manager " do
        target_1 = ManagerRefresh::Target.load(
          :manager     => @ems,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.dump).to(
          eq(
            :manager_id  => @ems.id,
            :event_id    => nil,
            :association => :vms,
            :manager_ref => {:ems_ref => @vm_1.ems_ref},
            :options     => {:opt1 => "opt1", :opt2 => "opt2"}
          )
        )
      end

      it "class method .dump returns the same as an instance method .dump " do
        target_1 = ManagerRefresh::Target.load(
          :manager     => @ems,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.dump).to eq ManagerRefresh::Target.dump(target_1)
      end
    end

    context ".load_from_db" do
      it "loads ManagerRefresh::Target from the db" do
        target_1 = ManagerRefresh::Target.load(
          :manager     => @ems,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.load_from_db).to eq @vm_1
      end
    end

    context ".id" do
      it "checks that .id is an alias for .dump" do
        target_1 = ManagerRefresh::Target.load(
          :manager     => @ems,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.dump).to eq target_1.id
      end
    end

    context ".name" do
      it "checks that .name is an alias for .association" do
        target_1 = ManagerRefresh::Target.load(
          :manager     => @ems,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )

        expect(target_1.name).to eq target_1.manager_ref
      end
    end
  end
end
