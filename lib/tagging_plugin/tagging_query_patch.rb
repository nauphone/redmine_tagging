require_dependency 'query'

module TaggingPlugin
  module QueryPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

        alias_method_chain :available_filters, :tags
        alias_method_chain :sql_for_field, :tags

        tag_query_column = QueryColumn.new(:issue_tags, :caption => :field_tags)
        add_available_column(tag_query_column)
      end

    end

    module InstanceMethods
      def available_filters_with_tags
        @available_filters = available_filters_without_tags

        if project.nil?
          tags = ActsAsTaggableOn::Tag.find(:all, :conditions => "id in (select tag_id from taggings where taggable_type = 'Issue')")
        else
          project_hierarchy = []
          project.hierarchy.each { |x| project_hierarchy << x }
          contexts = []
          project_hierarchy.each { |x| contexts << TaggingPlugin::ContextHelper.context_for(x) }
          tags = []
          contexts.each do |context|
            tags += ActsAsTaggableOn::Tag.find(:all, :conditions => ["id in (select tag_id from taggings where taggable_type = 'Issue' and context = ?)", context])
          end
        end
        tags = tags.collect {|tag| [tag.name.gsub(/^#/, ''), tag.name]}

        tag_filter = {
          "tags" => {
            :type => :list_optional,
            :values => tags.uniq.sort,
            :name => l(:field_tags),
            :order => 21,
            :field => "tags"
          }
        }
        @available_filters.merge(tag_filter)
      end

      def sql_for_field_with_tags(field, operator, v, db_table, db_field, is_custom_filter=false)
        if field == "tags"
          selected_values = values_for(field)
          selected_values.each do |tag|
            tag_find = Tag.where(:name => tag).last
            tag_find.last_update = Date.current
            tag_find.save
          end
          if operator == '!*'
            sql = "(#{Issue.table_name}.id NOT IN (select taggable_id from taggings where taggable_type='Issue'))"
            return sql
          elsif operator == "*"
            sql = "(#{Issue.table_name}.id IN (select taggable_id from taggings where taggable_type='Issue'))"
            return sql
          else
            sql = selected_values.collect{|val| "'#{ActiveRecord::Base.connection.quote_string(val.gsub('\'', ''))}'"}.join(',')
            sql = "(#{Issue.table_name}.id in (select taggable_id from taggings join tags on tags.id = taggings.tag_id where taggable_type='Issue' and tags.name in (#{sql})))"
            sql = "(not #{sql})" if operator == '!'
            return sql
          end
        else
          return sql_for_field_without_tags(field, operator, v, db_table, db_field, is_custom_filter)
        end
      end
    end
  end

  module QueriesHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include,InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        alias_method_chain :column_content, :tags
        base.send :alias_method_chain, :csv_value, :tags
      end
    end

    module InstanceMethods
      def column_content_with_tags(column, issue)
        value = column.value(issue)

        if value.class.name == "Array"
          if value.first.class.name == "IssueTag"
            links = value.map do |issue_tag|
              link_to_project_tag_filter(@project, issue_tag.tag)
            end

            links.join(', ')
          end
        else
          column_content_without_tags(column, issue)
        end
      end

      def csv_value_with_tags(column, issue, value)
        if value.class.name == 'IssueTag'
          value = value.tag
        end
        csv_value_without_tags(column, issue, value)
      end
    end
  end


  module PdfGenPatch
   def self.included(base) # :nodoc:
     base.send(:include, InstanceMethods)
     base.class_eval do
       unloadable # Send unloadable so it will not be unloaded in development
       alias_method_chain :fetch_row_values, :tags
     end
   end

   module InstanceMethods
     def fetch_row_values_with_tags(issue, query, level)
       query.inline_columns.collect do |column|
         s = if column.is_a?(QueryCustomFieldColumn)
           cv = issue.custom_field_values.detect {|v| v.custom_field_id == column.custom_field.id}
           show_value(cv)
         else
           value = issue.send(column.name)
           if column.name == :subject
             value = " " * level + value
           end
           if value.is_a?(Date)
             format_date(value)
           elsif value.is_a?(Time)
             format_time(value)
           elsif value.is_a?(Array)
             ret = ''
             value.each do |val|
               if val.class.name == 'IssueTag'
                 ret += val.tag.to_s + ' '
               end
             end
               ret
             else
               value
             end
           end
           s.to_s
         end
       end
     end
   end
end

IssueQuery.send(:include, TaggingPlugin::QueryPatch) unless IssueQuery.included_modules.include? TaggingPlugin::QueryPatch
QueriesHelper.send(:include, TaggingPlugin::QueriesHelperPatch) unless QueriesHelper.included_modules.include? TaggingPlugin::QueriesHelperPatch
Redmine::Export::PDF.send(:include, TaggingPlugin::PdfGenPatch) unless Redmine::Export::PDF.included_modules.include? TaggingPlugin::PdfGenPatch