ActiveRecord::Schema.define version: 0 do

  create_table "splittables", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "postal_code"
    t.string   "phone_number"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end