class AddAvataxInvoiceAtToOrders < ActiveRecord::Migration
  def up 
    add_column :spree_orders, :avatax_invoice_at, :datetime
    
    # For legacy orders, assume that if we calculated an Avatax for the order, we also invoiced it.
    Spree::Order.all.each do |order|
      if order.avatax_response_at
        order.update_attribute!(:avatax_invoice_at, order.avatax_respomnse_at)
      end
    end
  end

  def down
    remove_column :spree_orders, :avatax_invoice_at
  end
end
