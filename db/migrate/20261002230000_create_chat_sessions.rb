class CreateChatSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_sessions do |t|
      t.string :key, null: false
      t.text :data, null: false, default: "{}"
      t.timestamps
    end

    add_index :chat_sessions, :key, unique: true
  end
end
