class SpreeAvatax::Invoice
  ADDRESS_CODE = "1"
  DESTINATION_CODE = "1"
  ORIGIN_CODE = "1"

  attr_reader :order, :doc_type, :invoice

  def initialize(order, doc_type)
    @doc_type = doc_type
    @order = order
    build_invoice
  end

  private

  def build_invoice
    invoice = Avalara::Request::Invoice.new(
      :customer_code => order.email, # TODO why are we sending the email here ?!? shouldnt this be an ID instead?
      :doc_date => Date.today,
      :doc_type => doc_type,
      :company_code => SpreeAvatax::Config.company_code,
      :discount => order.promotion_adjustment_total.round(2).to_f,
      :doc_code => order.number
    )
    invoice.addresses = build_invoice_addresses
    invoice.lines = build_invoice_lines
    @invoice = invoice
  end

  def build_invoice_addresses
    address = order.ship_address
    [Avalara::Request::Address.new(
      :address_code => ADDRESS_CODE,
      :line_1 => address.address1,
      :line_2 => address.address2,
      :city => address.city,
      :postal_code => address.zipcode
    )]
  end

  def build_invoice_lines
    line_items = order.line_items.map do |line_item|
      Avalara::Request::Line.new(
        :line_no => line_item.id,
        :destination_code => DESTINATION_CODE,
        :origin_code => ORIGIN_CODE,
        :qty => line_item.quantity,
        :amount => line_item.discounted_amount.round(2).to_f,
        :item_code => line_item.variant.sku,
        :discounted => order.promotion_adjustment_total > 0.0 # Continue to pass this field if we have an order-level discount so the line item gets discount calculated onto it
      )
    end

    # Add shipping as a line item for Avalara
    # Need to check missing shipment_method before adding.
    line_items += order.shipments.select { |s| s.shipping_method.present? }.map do |shipment|
      Avalara::Request::Line.new(
        :line_no => shipment.id,
        :destination_code => DESTINATION_CODE,
        :origin_code => ORIGIN_CODE,
        :qty => 1,
        :amount => shipment.discounted_amount.round(2).to_f,
        :item_code => shipment.shipping_method.tax_category.tax_code,
        :discounted => order.promotion_adjustment_total > 0.0 # Continue to pass this field if we have an order-level discount so the line item gets discount calculated onto it
      )
    end

    line_items
  end
end
