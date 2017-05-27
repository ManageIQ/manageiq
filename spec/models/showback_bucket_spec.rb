require 'rails_helper'

RSpec.describe ShowbackBucket, :type => :model do
  let(:bucket) { FactoryGirl.build(:showback_bucket) }
  let(:event) { FactoryGirl.build(:showback_event) }

  describe '#basic lifecycle' do
    it 'has a valid factory' do
      bucket.valid?
      expect(bucket).to be_valid
    end

    it 'is not valid without an association to a parent element' do
      bucket.resource = nil
      bucket.valid?
      expect(bucket.errors.details[:resource]). to include(:error => :blank)
    end

    it 'is not valid without a name' do
      bucket.name = nil
      bucket.valid?
      expect(bucket.errors.details[:name]). to include(:error => :blank)
    end

    it 'is not valid without a description' do
      bucket.description = nil
      bucket.valid?
      expect(bucket.errors.details[:description]). to include(:error => :blank)
    end

    it 'deletes costs associated when deleting the bucket' do
      FactoryGirl.create(:showback_charge, :showback_bucket => bucket)
      FactoryGirl.create(:showback_charge, :showback_bucket => bucket)
      expect(bucket.showback_charges.count).to be(2)
      expect { bucket.destroy }.to change(ShowbackCharge, :count).from(2).to(0)
    end

    it 'deletes costs associated when deleting the event' do
      FactoryGirl.create(:showback_charge, :showback_bucket => bucket)
      FactoryGirl.create(:showback_charge, :showback_bucket => bucket)
      expect(bucket.showback_charges.count).to be(2)
      event = bucket.showback_charges.first.showback_event
      expect { event.destroy }.to change(ShowbackCharge, :count).from(2).to(1)
    end

    pending 'it can  be on states open, processing, pending'
    pending 'it can transition from open to processing'
    pending 'it can not transition from open to closed'
    pending 'a new bucket is created automatically when transitioning from open to processing'
    pending 'it can not transition from processing to open'
    pending 'it can transition from processing to closed'
    pending 'it can not transition from closed to open or processing'
  end

  describe '#state:open' do
    it 'new events can be associated to the bucket' do
      bucket.save
      event.save
      expect { bucket.showback_events << event }.to change(bucket.showback_events, :count).by(1)
      expect(bucket.showback_events.last).to eq(event)
    end

    it 'events can be associated to fixed costs' do
      bucket.save
      event.save
      expect { bucket.showback_events << event }.to change(bucket.showback_charges, :count).by(1)
      charge = bucket.showback_charges.last
      expect(charge.showback_event).to eq(event)
      expect { charge.fixed_cost = Money.new(3) }.to change(charge, :fixed_cost).from(0).to(Money.new(3))
    end

    it 'events can be associated to variable costs' do
      bucket.save
      event.save
      expect { bucket.showback_events << event }.to change(bucket.showback_charges, :count).by(1)
      charge = bucket.showback_charges.last
      expect(charge.showback_event).to eq(event)
      expect { charge.variable_cost = Money.new(3) }.to change(charge, :variable_cost).from(0).to(Money.new(3))
    end

    it 'monetizes fixed costs' do
      expect(ShowbackCharge).to monetize(:fixed_cost)
    end

    it 'monetized variable costs' do
      expect(ShowbackCharge).to monetize(:variable_cost)
    end

    pending 'charges can be updated for an event'
    pending 'charges can be updated for all events in the bucket'
    pending 'charges can be deleted for an event'
    pending 'charges can be deleted for all events in the bucket'
    pending 'is possible to return charges for an event'
    pending 'is possible to return charges for all events'
    pending 'sum of charges can be calculated for the bucket'
    pending 'sum of charges can be calculated for an event type'
  end

  describe '#state:processing' do
    pending 'new events are associated to a new or open bucket'
    pending 'new events can not be associated to the bucket'
    pending 'charges can be deleted for an event'
    pending 'charges can be deleted for all events in the bucket'
    pending 'charges can be updated for an event'
    pending 'charges can be updated for all events in the bucket'
    pending 'is possible to return charges for an event'
    pending 'is possible to return charges for all events'
    pending 'sum of charges can be calculated for the bucket'
    pending 'sum of charges can be calculated for an event type'
  end

  describe '#state:closed' do
    pending 'new events can not be associated to the bucket'
    pending 'new events are associated to a new or existing open bucket'
    pending 'charges can not be deleted for an event'
    pending 'charges can not be deleted for all events in the bucket'
    pending 'charges can not be updated for an event'
    pending 'charges can not be updated for all events in the bucket'
    pending 'is possible to return charges for an event'
    pending 'is possible to return charges for all events'
    pending 'sum of charges can be calculated for the bucket'
    pending 'sum of charges can be calculated for an event type'
  end
end
