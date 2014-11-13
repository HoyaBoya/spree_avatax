class AddAvataxFingerprintToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :avatax_fingerprint, :string
  end
end
