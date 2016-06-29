require_migration

describe FixServiceOrderPlacedAt do
  let(:service_order_stub) { migration_stub(:ServiceOrder) }

  migration_context :up do
    it "should convert only items with state=ordered" do
      ordered_item = service_order_stub.create!(:state      => 'ordered',
                                                :created_at => Time.zone.now - 1.day,
                                                :updated_at => Time.zone.now - 12.hours,
                                                :placed_at  => nil)
      wish_item = service_order_stub.create!(:state      => 'wish',
                                             :created_at => Time.zone.now - 1.day,
                                             :updated_at => Time.zone.now - 12.hours,
                                             :placed_at  => nil)
      cart_item = service_order_stub.create!(:state      => 'cart',
                                             :created_at => Time.zone.now - 1.day,
                                             :updated_at => Time.zone.now - 12.hours,
                                             :placed_at  => nil)

      migrate

      ordered_item.reload
      wish_item.reload
      cart_item.reload

      expect(ordered_item.placed_at).not_to be_nil
      expect(wish_item.placed_at).to be_nil
      expect(cart_item.placed_at).to be_nil
    end

    it "should convert more than one item" do
      ordered_item_1 = service_order_stub.create!(:state      => 'ordered',
                                                  :created_at => Time.zone.now - 1.day,
                                                  :updated_at => Time.zone.now - 12.hours,
                                                  :placed_at  => nil)
      ordered_item_2 = service_order_stub.create!(:state      => 'ordered',
                                                  :created_at => Time.zone.now - 2.days,
                                                  :updated_at => Time.zone.now - 16.hours,
                                                  :placed_at  => nil)

      migrate

      ordered_item_1.reload
      ordered_item_2.reload

      expect(ordered_item_1.placed_at).not_to be_nil
      expect(ordered_item_2.placed_at).not_to be_nil
    end

    it "should use updated_at as the source" do
      time_1 = Time.zone.now - 17.hours
      time_2 = Time.zone.now - 13.hours

      ordered_item_1 = service_order_stub.create!(:state      => 'ordered',
                                                  :created_at => Time.zone.now - 14.hours,
                                                  :updated_at => time_1,
                                                  :placed_at  => nil)
      ordered_item_2 = service_order_stub.create!(:state      => 'ordered',
                                                  :created_at => Time.zone.now - 16.hours,
                                                  :updated_at => time_2,
                                                  :placed_at  => nil)

      migrate

      ordered_item_1.reload
      ordered_item_2.reload

      expect(ordered_item_1.placed_at).to be_within(1.second).of(time_1)
      expect(ordered_item_2.placed_at).to be_within(1.second).of(time_2)
    end

    it "should not overwrite existing placed_at" do
      time_good = Time.zone.now - 19.hours
      time_bad = Time.zone.now - 11.hours

      ordered_item = service_order_stub.create!(:state      => 'ordered',
                                                :created_at => Time.zone.now - 18.hours,
                                                :updated_at => time_bad,
                                                :placed_at  => time_good)

      migrate

      ordered_item.reload

      expect(ordered_item.placed_at).to be_within(1.second).of(time_good)
    end
  end
end
