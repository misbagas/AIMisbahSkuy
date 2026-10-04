class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.text :command
      t.string :status
      t.text :output
      t.string :language
      t.integer :exit_code
      t.text :ai_response

      t.timestamps
    end
  end
end
