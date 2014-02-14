require 'spec_helper'

describe Spree::Calculator::Avatax do
  let(:calculator) { Spree::Calculator::Avatax.new }
  let(:tax_rate) { double(Spree::TaxRate, amount: 50.00, tax_category: 'Foo') }

  describe 'Avatax.description' do
    it 'should not be nil' do
      Spree::Calculator::Avatax.description.should_not be_nil
    end
  end

  describe 'compute' do
    subject { calculator.compute(computable) }

    context 'when computable is Spree::Order' do
      let(:computable) { Spree::Order.new }

      before do
        calculator.should_receive(:avatax_compute_order).once
        calculator.should_receive(:avatax_compute_line_item).never       
      end

      it 'should call compute order' do
        subject
      end
    end

    context 'when computable is Spree::LineItem' do
      let(:computable) { Spree::LineItem.new }

      before do
        calculator.should_receive(:avatax_compute_order).never
        calculator.should_receive(:avatax_compute_line_item).once
      end

      it 'should call compute order' do
        subject
      end
    end
  end 

  describe 'rate' do
    subject { calculator.send(:rate) }
    it 'should calculate a rate' do
      # TODO: Come up with a better test for rate.
      subject.should be_nil
    end  
  end

  describe 'avatax_compute_order' do
    let(:invoice_tax) { double(Avalara::Response, total_tax: 5.00) }
    let(:pager_duty_client) { Pagerduty.new('PAGER DUTY KEY') }  
    let(:order) do
      FactoryGirl.create(:order_with_line_items, ship_address: FactoryGirl.create(:ship_address))
    end

    subject do
      calculator.send(:avatax_compute_order, order)
    end

    context 'when invalid order' do
      before do
        Avalara.should_receive(:get_tax).never
      end

      context 'when no shipping address' do
        before do
          order.ship_address = nil
        end

        it 'should return 0' do
          subject.should == 0
        end
      end

      context 'when no line items' do
        before do
          order.line_items.delete_all
        end

        it 'should return 0' do
          subject.should == 0
        end
      end
    end

    context 'when valid order' do
      before(:each) do
        calculator.should_receive(:rate).at_least(1).and_return(tax_rate)
      end

      context 'when computing a Spree:Order' do
        before do
          Avalara.should_receive(:get_tax).once.and_return(invoice_tax)
        end

        it 'should call Avalara.get_tax' do
          subject
        end

        it 'should set avatax_response_at' do
          subject
          order.avatax_response_at.should_not be_nil    
        end
      end

      context 'when Avalara::ApiError is raised' do
        context 'when suppress_api_errors is true' do
          before do
            Avalara.should_receive(:get_tax).once.and_raise(Avalara::ApiError.new)
            SpreeAvatax::Config.should_receive(:suppress_api_errors?).and_return(true)
          end

          it 'should not notify Honeybadger' do
            Honeybadger.should_receive(:notify).never
            subject
          end

          it 'should not notify Pagerduty' do
            pager_duty_client.should_receive(:trigger).never
            calculator.pager_duty_client = pager_duty_client
            subject
          end
        end

        context 'when suppress_api_errors is false' do
          before do
            Avalara.should_receive(:get_tax).once.and_raise(Avalara::ApiError.new)
            SpreeAvatax::Config.should_receive(:suppress_api_errors?).and_return(false)
          end

          it 'should notify Honeybadger' do
            Honeybadger.should_receive(:notify).once
            subject
          end

          it 'should notify Pagerduty' do
            pager_duty_client.should_receive(:trigger).once
            calculator.pager_duty_client = pager_duty_client
            subject
          end
        end
      end

      context 'when StandardError is raised' do
        before do
          Avalara.should_receive(:get_tax).once.and_raise('SOME AVALARA ERROR')
        end

        it 'should notify Honeybadger' do
          Honeybadger.should_receive(:notify).once
          subject
        end

        it 'should notify Pagerduty' do
          pager_duty_client.should_receive(:trigger).once
          calculator.pager_duty_client = pager_duty_client
          subject
        end

        it 'should return 0 tax' do
          subject.should == 0
        end
      end
    end
  end

  describe 'avatax_compute_line_item' do
    before do
      calculator.should_receive(:rate).at_least(1).and_return(tax_rate)
    end

    it 'should invoke Calculator::DefaultTax' do
      calculator.send(:avatax_compute_line_item, FactoryGirl.create(:line_item))
    end
  end
end
