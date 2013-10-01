ActiveRecord::Schema.define version: 0 do

  create_table "splittables", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "email_sub"
    t.string   "postal_code"
    t.string   "phone_number"
    t.string   "birthday_era"
    t.string   "birthday"
    t.string   "latlng"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
