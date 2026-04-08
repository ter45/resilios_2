class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: false do |t|
      t.string   :id,                 null: false
      t.string   :name,               null: false
      t.string   :email,              null: false
      t.string   :password_digest,    null: false
      t.string   :stripe_customer_id
      t.string   :plan,               default: 'trial'
      t.string   :status,             default: 'active'
      t.string   :timezone,           default: 'America/Bogota'
      t.jsonb    :metadata,           default: {}
      t.datetime :trial_ends_at
      t.timestamps
    end
    add_index :accounts, :id,    unique: true
    add_index :accounts, :email, unique: true
    add_index :accounts, :status
  end
end
