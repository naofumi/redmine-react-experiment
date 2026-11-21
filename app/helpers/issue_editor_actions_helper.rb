# frozen_string_literal: true

module IssueEditorActionsHelper
  private

  def issue_editor_field_actions(name)
    case name
    when :tracker_id
      issue_editor_descriptions(
        trackers_for_select(@issue), @issue.tracker, 'trackers_description',
        :label_open_trackers_description, :label_trackers_description, :text_select_apply_tracker
      )
    when :status_id
      issue_editor_descriptions(
        @allowed_statuses, @issue.status, 'issue_statuses_description',
        :label_open_issue_statuses_description, :label_issue_statuses_description, :text_select_apply_issue_status
      ).merge(
        warning: @issue.transition_warning,
        warningIcon: sprite_icon('warning', l(:notice_issue_not_closable_by_open_tasks))
      )
    when :category_id
      if User.current.allowed_to?(:manage_categories, @issue.project)
        issue_editor_create_action(new_project_issue_category_path(@issue.project), :label_issue_category_new)
      end
    when :fixed_version_id
      if User.current.allowed_to?(:manage_versions, @issue.project)
        issue_editor_create_action(new_project_version_path(@issue.project), :label_version_new)
      end
    when :parent_issue_id
      {
        autocompleteUrl: auto_complete_issues_path(
          project_id: @issue.project, scope: Setting.cross_project_subtasks,
          status: @issue.closed? ? 'c' : 'o', issue_id: @issue.id
        )
      }
    end
  end

  def issue_editor_descriptions(records, selected, id, open_label, heading, select_label)
    descriptions = records.filter_map do |record|
      if record.description.present?
        {value: record.id.to_s, name: record.name, description: record.description}
      end
    end
    {
      selectedDescription: selected.description.presence,
      descriptions: (if descriptions.any?
                       {
                         id: id, title: l(heading), helpLabel: l(open_label), selectLabel: l(select_label),
        icon: sprite_icon('help', l(open_label)), items: descriptions
                       }
                     end)
    }
  end

  def issue_editor_create_action(url, label)
    {create: {url: url, label: l(label), icon: sprite_icon('add', l(label))}}
  end
end
