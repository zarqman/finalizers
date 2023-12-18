# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2023_11_15_204452) do
  create_table "vehicles", force: :cascade do |t|
    t.string "color"
    t.string "state"
    t.string "state_at"
    t.string "wheels_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wheels", force: :cascade do |t|
    t.string "location"
    t.string "state", null: false
    t.string "state_at"
    t.integer "vehicle_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vehicle_id"], name: "index_wheels_on_vehicle_id"
  end

  add_foreign_key "wheels", "vehicles"
end
