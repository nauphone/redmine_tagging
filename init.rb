require 'redmine'

ActionDispatch::Callbacks.to_prepare do
  require 'tagging_plugin/tagging_patches'
  require 'tagging_plugin/tagging_query_patch'
  require 'tagging_plugin/api_template_handler_patch'
  require 'tagging_plugin/application_helper_path.rb'

  if !Issue.searchable_options[:include].include? :issue_tags
    Issue.searchable_options[:columns] << "#{IssueTag.table_name}.tag"
    Issue.searchable_options[:include] << :issue_tags
  end

  if !WikiPage.searchable_options[:include].include? :wiki_page_tags
    WikiPage.searchable_options[:columns] << "#{WikiPageTag.table_name}.tag"
    WikiPage.searchable_options[:include] << :wiki_page_tags
  end
end

require_dependency 'tagging_plugin/tagging_hooks'

Redmine::Plugin.register :redmine_tagging do
  name 'Redmine Tagging plugin'
  author 'friflaj'
  description 'Wiki/issues tagging'
  version '0.0.1'

  settings :default => { :dynamic_font_size => "1", :sidebar_tagcloud => "1", :wiki_pages_inline  => "0", :issues_inline => "0" }, :partial => 'tagging/settings'
  project_module :issue_tags do
    permission :issue_tags, {:issues => :tags}, :require => :loggedin
  end
  Redmine::WikiFormatting::Macros.register do
    desc "Wiki/Issues tagcloud"
    macro :tagcloud do |obj, args|
      args, options = extract_macro_options(args, :parent)

      return if params[:controller] == "mailer"

      if obj
        if obj.is_a? WikiContent
          project = obj.page.wiki.project
        else
          project = obj.project
        end
      else
        project = Project.visible.where(:identifier => params[:project_id]).first
      end

      if project # this may be an attempt to render tag cloud when deleting wiki page
        if [WikiContent, WikiContent::Version, NilClass].include?(obj.class)
          render :partial => 'tagging/tagcloud_search', :project => project
        elsif [Journal, Issue].include?(obj.class)
          render :partial => 'tagging/tagcloud', :project => project
        end
      end
    end
  end

  Redmine::WikiFormatting::Macros.register do
    desc "Wiki/Issues tag"
    macro :tag do |obj, args|
      if obj.is_a?(WikiContent) && Setting.plugin_redmine_tagging[:wiki_pages_inline] == "1"
        inline = true
      elsif obj.is_a?(Issue) && Setting.plugin_redmine_tagging[:issues_inline] == "1"
        inline = true
      else
        inline = false
      end

      if inline
        args, options = extract_macro_options(args, :parent)
        tags = args.collect{|a| a.split(/[#"'\s,]+/)}.flatten.select{|tag| !tag.blank?}.collect{|tag| "##{tag}" }.uniq.sort

        if obj.is_a? WikiContent
          obj = obj.page
          project = obj.wiki.project
        else
          project = obj.project
        end

        context = TaggingPlugin::ContextHelper.context_for(project)
        tags_present = obj.tag_list_on(context).sort.join(',')
        new_tags = tags.join(',')
        if tags_present != new_tags
          obj.tags_to_update = new_tags
          obj.save
        end

        taglinks = tags.collect do |tag|
          search_url = {
            :controller => "search",
            :action => "index",
            :id => project,
            :q => "\"#{tag}\""
          }

          search_url.merge!(obj.is_a?(WikiPage) ? { :wiki_pages => true, :issues => false } : { :wiki_pages => false, :issues => true })
          link_to(tag, search_url)
        end.join('&nbsp;')

        raw("<div class='tags'>#{taglinks}</div>")
      else
        ''
      end
    end
  end
end
