require 'digest'
require 'thread'

Spree::Order.class_eval do

  ##
  # Possible order states
  # http://guides.spreecommerce.com/user/order_states.html

  # Send Avatax the invoice after ther order is complete and ask them to store it
  Spree::Order.state_machine.after_transition :to => :complete, :do => :commit_avatax_invoice

  # Start calculating tax as soon as addresses are supplied
  Spree::Order.state_machine.after_transition :from => :address, :do => :avatax_compute_tax

  # Calculate tax for shipping
  Spree::Order.state_machine.after_transition :from => :delivery, :do => :avatax_compute_tax

  def avataxable?
    line_items.present? && ship_address.present? && !cart?
  end

  def promotion_adjustment_total
    adjustments.promotion.eligible.sum(:amount).abs
  end

  ##
  # This method sends an invoice to Avalara which is stored in their system.
  def commit_avatax_invoice
    SpreeAvatax::TaxComputer.new(self, { doc_type: 'SalesInvoice', status_field: :avatax_invoice_at }).compute
  end

  ##
  # Comute avatax but do not commit it their db
  def avatax_compute_tax
    # Do not calculate if the current cart fingerprint is the same what we have before.
    # Alleviate multiple API calls for the same tax amount.
    c = calculate_avatax_fingerprint
    if self.avatax_fingerprint == calculate_avatax_fingerprint
      Rails.logger.info "Skipping Avatax due to same fingerprint [#{avatax_fingerprint}]"
      return
    end

    SpreeAvatax::TaxComputer.new(self).compute
    self.update_attributes(avatax_fingerprint: calculate_avatax_fingerprint)
  end

  # The fingerprint hash is the # of line items, # of shipments, and order total, and the ship address entity and last update
  def calculate_avatax_fingerprint
    md5 = Digest::MD5.new

    address_digest = ""
    if self.shipping_address
      h = self.shipping_address.attributes
      h.delete('created_at')
      h.delete('updated_at')
      address_digest = h.values.to_s
    end

    line_items_digest = line_items.map { |li| "#{li.id}#{li.quantity}#{li.total}" }

    # Remove the tax part of the total digest, else we get the delta of pre / post avatax and calculate 1 extra time
    total_digest = total - (additional_tax_total || 0.0)

    md5.update "#{total_digest}#{line_items_digest}#{address_digest}"
    md5.hexdigest
  end
end
