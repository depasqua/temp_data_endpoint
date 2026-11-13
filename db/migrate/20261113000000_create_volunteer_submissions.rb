class CreateVolunteerSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :volunteer_submissions do |t|
      t.json :data, null: false
      t.timestamps
    end
  end
end
