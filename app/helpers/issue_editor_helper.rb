# frozen_string_literal: true

module IssueEditorHelper
  include IssueEditorActionsHelper

  def issue_editor_props
    {
      heading: "#{@issue.tracker_was} ##{@issue.id}",
      issueUrl: issue_path(@issue),
      editUrl: edit_issue_path(@issue),
      embedded: action_name == 'show',
      hidden: {
        'issue[lock_version]' => @issue.lock_version,
        :last_journal_id => params[:last_journal_id] || @issue.last_journal_id.to_s,
        :back_url => params[:back_url], :prev_issue_id => @prev_issue_id || params[:prev_issue_id],
        :next_issue_id => @next_issue_id || params[:next_issue_id],
        :issue_position => @issue_position || params[:issue_position], :issue_count => @issue_count || params[:issue_count]
      }.compact,
      validationMessages: [@issue, @time_entry].compact.flat_map {|record| record.errors.full_messages},
      conflictHtml: (@conflict ? render(partial: 'issues/conflict') : nil),
      labels: {properties: l(:label_change_properties), notes: l(:field_notes), privateNotes: l(:field_private_notes),
               submit: l(:button_submit), cancel: l(:button_cancel), edit: l(:button_edit),
               refreshError: l(:notice_issue_editor_refresh_failed), retry: l(:button_update)},
      schema: issue_editor_schema
    }
  end

  def issue_editor_schema
    {
      projectId: @issue.project_id,
      properties: @issue.attributes_editable?,
      mentionUrl: (if User.current.allowed_to?(:add_issue_watchers, @issue.project)
                     watchers_autocomplete_for_mention_path(project_id: @issue.project_id, q: '', object_type: 'issue',
                       object_id: @issue.id)
                   end),
      fields: @issue.attributes_editable? ? issue_editor_fields : [],
      statusText: @issue.status.to_s, statusLabel: Issue.human_attribute_name(:status_id),
      notesHtml: (@issue.notes_addable? ? issue_editor_wiki(:notes) : nil),
      privateNotes: @issue.notes_addable? && @issue.safe_attribute?('private_notes'),
      privateNotesChecked: @issue.private_notes == true,
      customFields: issue_editor_custom_fields,
      timeHtml: (@issue.time_loggable? ? render(partial: 'issues/editor_time') : nil),
      attachmentsHtml: (@issue.attachments_addable? ? render(partial: 'issues/editor_attachments') : nil)
    }
  end

  private

  def issue_editor_fields
    fields = []
    add = lambda do |name, kind = 'text', **options|
      required = options.fetch(:required) { @issue.required_attribute?(name.to_s) }
      fields << {name: name, kind: kind, label: Issue.human_attribute_name(name), value: @issue.public_send(name).to_s,
                 required: required, invalid: @issue.errors[name].present?, actions: issue_editor_field_actions(name)}.merge(options)
    end
    add.call(:is_private, 'checkbox', value: @issue.is_private? ? '1' : '0') if @issue.safe_attribute?('is_private')
    projects = projects_for_select(@issue)
    if (@issue.safe_attribute?('project_id') || @issue.project_id_changed?) && projects.size > 1
      add.call(:project_id, 'select', optionsHtml: project_tree_options_for_select(projects), refresh: true, required: true)
    end
    if @issue.safe_attribute?('tracker_id') || @issue.tracker_id_changed?
      add.call(:tracker_id, 'select', optionsHtml: options_for_select(trackers_options_for_select(@issue)), refresh: true, required: true)
    end
    add.call(:subject, required: true) if @issue.safe_attribute?('subject')
    add.call(:description, 'wiki', html: issue_editor_wiki(:description)) if @issue.safe_attribute?('description')
    if @issue.safe_attribute?('status_id') && @allowed_statuses.present?
      add.call(:status_id, 'select', optionsHtml: options_from_collection_for_select(@allowed_statuses, :id, :name), refresh: true, required: true)
    end
    if @issue.safe_attribute?('priority_id')
      add.call(:priority_id, 'select', optionsHtml: options_from_collection_for_select(@priorities, :id, :name), required: true)
    end
    if @issue.safe_attribute?('assigned_to_id')
      users = @issue.assignable_users
      add.call(:assigned_to_id, 'select', optionsHtml: tag.option(value: '') + principals_options_for_select(users),
               assignToMe: (l(:label_assign_to_me) if users.include?(User.current)), userId: User.current.id.to_s)
    end
    if @issue.safe_attribute?('category_id') && @issue.project.issue_categories.any?
      add.call(:category_id, 'select', optionsHtml: tag.option(value: '') + options_from_collection_for_select(@issue.project.issue_categories, :id, :name))
    end
    if @issue.safe_attribute?('fixed_version_id') && @issue.assignable_versions.any?
      add.call(:fixed_version_id, 'select', optionsHtml: tag.option(value: '') + version_options_for_select(@issue.assignable_versions))
    end
    add.call(:parent_issue_id, refresh: true) if @issue.safe_attribute?('parent_issue_id')
    [:start_date, :due_date].each {|name| add.call(name, 'date') if @issue.safe_attribute?(name.to_s)}
    if @issue.safe_attribute?('estimated_hours')
      hours = @issue.errors[:estimated_hours].empty? ? format_hours(@issue.estimated_hours) : @issue.estimated_hours_before_type_cast
      add.call(:estimated_hours, value: hours.to_s)
    end
    if @issue.safe_attribute?('done_ratio') && Issue.use_field_for_done_ratio?
      ratios = (0..100).step(Setting.issue_done_ratio_interval.to_i).map {|i| ["#{i} %", i]}
      add.call(:done_ratio, 'select', optionsHtml: options_for_select(ratios))
    end
    fields
  end

  def issue_editor_wiki(name)
    wiki_textarea_tag("issue[#{name}]", @issue.public_send(name),
      id: "issue_#{name}", cols: 60, rows: 10, data: {auto_complete: true},
      preview_url: preview_issue_path(project_id: @issue.project_id, issue_id: @issue.id))
  end

  def issue_editor_custom_fields
    return [] unless @issue.attributes_editable? && @issue.safe_attribute?('custom_field_values')

    @issue.editable_custom_field_values.map do |value|
      field = value.custom_field
      {id: field.id, fullWidth: field.full_width_layout?, html: custom_field_tag_with_label(:issue, value,
        required: @issue.required_attribute?(field.id), wiki_toolbar: field.full_width_layout?,
        preview_url: preview_issue_path(project_id: @issue.project_id, issue_id: @issue.id))}
    end
  end
end
