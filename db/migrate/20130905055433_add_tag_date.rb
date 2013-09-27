class AddTagDate < ActiveRecord::Migration
  def up
    execute "ALTER TABLE tags ADD COLUMN last_update timestamp without time zone;"
    execute "ALTER TABLE tags ALTER COLUMN last_update SET DEFAULT CURRENT_TIMESTAMP"
    execute "UPDATE tags SET last_update = now()"
  end

  def down
    remove_column :tags, :last_update
  end
end
