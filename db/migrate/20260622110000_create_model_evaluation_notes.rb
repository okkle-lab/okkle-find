class CreateModelEvaluationNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :model_evaluation_notes do |t|
      t.references :model_variant, null: false, foreign_key: true
      t.string :test_id
      t.string :category
      t.string :criterion
      t.string :score_field
      t.string :grader_model_key
      t.string :grader_model_name
      t.decimal :score, precision: 4, scale: 2
      t.text :reasoning
      t.text :strengths
      t.text :issues

      t.timestamps
    end

    add_index :model_evaluation_notes,
      [:model_variant_id, :test_id, :grader_model_key],
      unique: true,
      name: "index_model_eval_notes_on_variant_test_grader"
    add_index :model_evaluation_notes,
      [:model_variant_id, :score_field],
      name: "index_model_eval_notes_on_variant_score_field"
  end
end
