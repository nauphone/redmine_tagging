class RecreateIssueView < ActiveRecord::Migration
  def up
    drop_view :issue_tags
    create_view :issue_tags, "select taggings.id as id, tags.name as tag, taggings.taggable_id as issue_id, tags.last_update from taggings join tags on taggings.tag_id = tags.id where taggable_type = 'Issue'"
  end

  def down
  end
end
