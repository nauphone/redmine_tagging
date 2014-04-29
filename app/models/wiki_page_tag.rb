class WikiPageTag < ActiveRecord::Base
  self.primary_key = :id

  belongs_to :wiki_page

  def readonly?
    return true
  end

  # Prevent objects from being destroyed
  def before_destroy
    raise ActiveRecord::ReadOnlyRecord
  end
end
