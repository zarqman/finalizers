class CreateVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicles do |t|
      t.string :color
      t.string :state, null: false
      t.string :state_at
      t.string :wheels_count, null: false, default: 0

      t.timestamps
    end
  end
end
