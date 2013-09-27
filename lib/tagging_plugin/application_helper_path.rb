require_dependency "application_helper"
module TaggingPlugin
  module ApplicationHelperPatch
    def self.included(base)
      base.class_eval do

        def link_to_project_tag_filter(project, tag, options = {}, html_options = {})
          options.reverse_merge!({
            :status => 'o',
            :title => tag
          })

          opts = {
            'set_filter' => 1,
            'f' => ['tags', 'status_id'],
            'op[tags]' => '=',
            'op[status_id]' => options[:status],
            'v[tags][]' => tag,
            'v[status_id][]' => 1
          }

          if project
            link_to(options[:title], project_issues_path(project, opts), html_options)
          else
            link_to(options[:title], issues_path(opts), html_options)
          end
        end

        def tag_without_sharp(tag)
          tag[1..-1]
        end

        def tag_cloud_in_project(project, create = false, &each_tag)
          tags = {}
          if project
            project_hierarchy = []
            project.hierarchy.each { |x| project_hierarchy << x }
            contexts = []
            project_hierarchy.each { |x| contexts << TaggingPlugin::ContextHelper.context_for(x) }

            if !create
              contexts.each do |context|
                Issue.tag_counts_on(context).where("last_update >= ?", 6.month.ago).each do |tag|
                  if tags[tag.name]
                    tags[tag.name] += tag.count
                  else
                    tags[tag.name] = tag.count
                  end
                end
              end
            else
              contexts.each do |context|
                Issue.tag_counts_on(context).each do |tag|
                  if tags[tag.name]
                    tags[tag.name] += tag.count
                  else
                    tags[tag.name] = tag.count
                  end
                end
              end
            end
            contexts.each do |context|
              WikiPage.tag_counts_on(context).each do |tag|
                tags[tag.name] = tags[tag.name].to_i + tag.count
              end
            end
          else
            if !create
              Issue.all_tag_counts.where("last_update >= ?", 6.month.ago).each do |tag|
                tags[tag.name] = tag.count
              end
            else
              Issue.all_tag_counts.each do |tag|
                tags[tag.name] = tag.count
              end
            end

            WikiPage.all_tag_counts.each do |tag|
              tags[tag.name] = tags[tag.name].to_i + tag.count
            end
          end

          tags = tags.reject {|key,value| value == 0 }

          if tags.size > 0
            min_max = tags.values.minmax
            distance = min_max[1] - min_max[0]

            dynamic_fonts_enabled = (Setting.plugin_redmine_tagging[:dynamic_font_size] == "1")

            tags.keys.sort.each do |tag|
              if dynamic_fonts_enabled && (distance != 0)
                count = tags[tag]
                factor = (count - min_max[0]).to_f / distance
              else
                factor = 0.0
              end

              each_tag.call(tag, factor)
            end
          end
        end
      end
    end
  end
end
ApplicationHelper.send(:include, TaggingPlugin::ApplicationHelperPatch)
