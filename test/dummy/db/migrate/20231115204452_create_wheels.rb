class CreateWheels < ActiveRecord::Migration[7.1]
  def change
    create_table :wheels do |t|
      t.string :location
      t.string :state, null: false
      t.string :state_at
      t.references :vehicle, null: false, foreign_key: true

      t.timestamps
    end
  end
end
