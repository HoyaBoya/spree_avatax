require 'spec_helper'

describe Spree::Order do
  subject { create(:order_with_line_items) }

  describe '#calculate_avatax_fingerprint' do
    it 'should hash' do
      expect(subject.calculate_avatax_fingerprint).to_not be_nil
    end
  end

  describe '#avatax_compute_tax' do
    context 'when the avatax_fingerprint is different' do
      let(:original_fingerprint) { 'abcdef' }

      before do
        subject.update_attributes!(avatax_fingerprint: original_fingerprint)
        SpreeAvatax::TaxComputer.any_instance.should_receive(:compute).once
      end

      it 'should set avatax_fingerprint' do
        subject.avatax_compute_tax
        subject.reload
        expect(subject.avatax_fingerprint).to_not be_nil
        expect(subject.avatax_fingerprint).to_not eq(original_fingerprint)
      end
    end

    context 'when the avatax_fingerprint is same' do
      before do
        SpreeAvatax::TaxComputer.any_instance.should_receive(:compute).never
        subject.update_attributes!(avatax_fingerprint: subject.calculate_avatax_fingerprint)
      end

      it 'should set avatax_fingerprint' do
        subject.avatax_compute_tax
      end
    end
  end

  describe "#avataxable?" do
    it "returns true if there are avataxable line items and a ship address" do
      subject.stub(:line_items).and_return([1])
      subject.stub(:ship_address).and_return(double(:as_null_object))
      expect(subject).to be_avataxable
    end

    it "returns false if there are no avataxable line items" do
      subject.stub(:line_items).and_return([])
      subject.stub(:ship_address).and_return(double(:as_null_object))
      expect(subject).not_to be_avataxable
    end

    it "returns false if there is no ship address" do
      subject.stub(:line_items).and_return([1])
      subject.stub(:ship_address).and_return(nil)
      expect(subject).not_to be_avataxable
    end
  end

  describe "on state transition" do
    context "when transitioning to complete" do
      before do
        subject.update_attribute(:state, "confirm")
        subject.payments.create!(state: "checkout")
      end

      it "tells the avatax computer to compute tax" do # for storage in avalara and our own records
        expect(SpreeAvatax::TaxComputer).to receive(:new).with(
          subject, hash_including(doc_type: 'SalesInvoice', status_field: :avatax_invoice_at)
        ).and_call_original
        SpreeAvatax::TaxComputer.any_instance.should_receive(:compute).once
        subject.next!
      end
    end

    context "when not transitioning to complete" do
      it "does not communicate with the avatax calculator" do
        expect(SpreeAvatax::TaxComputer).not_to receive(:new)
        SpreeAvatax::TaxComputer.any_instance.should_receive(:compute).never
        subject.next!
      end
    end
  end

  describe '#promotion_adjustment_total' do
    context 'no adjustments exist' do
      it 'returns 0' do
        expect(subject.promotion_adjustment_total).to eq 0
      end
    end

    context 'there are eligible adjustments' do
      before do
        subject.adjustments.create(source_type: "Spree::PromotionAction", eligible: false, amount: -5.0, label: 'Promo One')
        subject.adjustments.create(source_type: "Spree::PromotionAction", eligible: true, amount: -10.99, label: 'Promo Two')
      end

      it 'returns 10.99' do
        expect(subject.promotion_adjustment_total).to eq BigDecimal("10.99")
      end
    end
  end
end
