# frozen_string_literal: true

class CreateBugReports < ActiveRecord::Migration[7.1]
  def change
    create_table :bug_reports do |t|
      t.integer :user_id
      t.string :user_type, limit: 50
      t.string :page_url, null: false
      t.text :description, null: false
      t.text :sanitized_description
      t.string :title
      t.string :category
      t.string :severity
      t.string :status, default: "pending", null: false
      t.string :github_issue_number
      t.string :github_issue_url
      t.decimal :quality_score, precision: 5, scale: 2
      t.text :validation_result
      t.text :rejection_reason
      t.text :internal_notes
      t.json :technical_context
      t.json :blur_metadata
      t.string :external_id, limit: 191, null: false
      t.datetime :deleted_at
      t.timestamps

      t.index :external_id, unique: true
      t.index :user_id
      t.index :status
      t.index :github_issue_number
      t.index :created_at
    end
  end
end

