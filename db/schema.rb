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

ActiveRecord::Schema[7.2].define(version: 2025_05_17_223118) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "growth_opportunities", force: :cascade do |t|
    t.string "symbol"
    t.decimal "price"
    t.decimal "volume_24h"
    t.decimal "price_change_24h"
    t.decimal "market_cap"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trades", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "side", null: false
    t.string "status", default: "pending", null: false
    t.decimal "amount", null: false
    t.decimal "price", null: false
    t.string "order_id"
    t.decimal "profit_loss", default: "0.0"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trading_position_id", null: false
    t.index ["status"], name: "index_trades_on_status"
    t.index ["trading_position_id"], name: "index_trades_on_trading_position_id"
  end

  create_table "trading_configs", force: :cascade do |t|
    t.string "api_key", null: false
    t.string "api_secret", null: false
    t.string "mode", default: "dry_run", null: false
    t.integer "check_interval", default: 300, null: false
    t.decimal "min_growth_rate", default: "5.0", null: false
    t.decimal "max_investment_per_trade", default: "100.0", null: false
    t.boolean "active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.decimal "volume_spike_multiplier", precision: 5, scale: 2, default: "2.5"
    t.decimal "rsi_threshold", precision: 5, scale: 2, default: "65.0"
    t.decimal "upper_wick_percentage", precision: 5, scale: 2, default: "2.0"
    t.index ["user_id"], name: "index_trading_configs_on_user_id"
  end

  create_table "trading_metrics", force: :cascade do |t|
    t.bigint "trading_config_id", null: false
    t.decimal "total_profit_loss", default: "0.0"
    t.integer "total_trades", default: 0
    t.integer "completed_trades", default: 0
    t.decimal "win_rate", default: "0.0"
    t.jsonb "daily_metrics", default: {}
    t.jsonb "symbol_metrics", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trading_config_id"], name: "index_trading_metrics_on_trading_config_id"
  end

  create_table "trading_positions", force: :cascade do |t|
    t.string "symbol", null: false
    t.decimal "entry_price", precision: 20, scale: 8, null: false
    t.decimal "quantity", precision: 20, scale: 8, null: false
    t.string "status", null: false
    t.datetime "entry_time", null: false
    t.jsonb "take_profit_levels", default: [], null: false
    t.decimal "stop_loss", precision: 20, scale: 8, null: false
    t.datetime "exit_time"
    t.decimal "exit_price", precision: 20, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "dry_run", default: false
    t.datetime "listing_time"
    t.bigint "trading_config_id", null: false
    t.index ["dry_run"], name: "index_trading_positions_on_dry_run"
    t.index ["entry_time"], name: "index_trading_positions_on_entry_time"
    t.index ["listing_time"], name: "index_trading_positions_on_listing_time"
    t.index ["status"], name: "index_trading_positions_on_status"
    t.index ["symbol"], name: "index_trading_positions_on_symbol"
    t.index ["trading_config_id"], name: "index_trading_positions_on_trading_config_id"
  end

  create_table "trading_recommendations", force: :cascade do |t|
    t.string "symbol"
    t.string "action"
    t.float "confidence"
    t.decimal "price"
    t.datetime "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}
    t.index ["symbol", "timestamp"], name: "index_trading_recommendations_on_symbol_and_timestamp"
    t.index ["symbol"], name: "index_trading_recommendations_on_symbol"
    t.index ["timestamp"], name: "index_trading_recommendations_on_timestamp"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "trading_configs", "users"
  add_foreign_key "trading_metrics", "trading_configs"
  add_foreign_key "trading_positions", "trading_configs"
end
