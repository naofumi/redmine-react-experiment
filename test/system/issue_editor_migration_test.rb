# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../application_system_test_case'

class IssueEditorMigrationTest < ApplicationSystemTestCase
  test 'E1 Edit action and direct URL preserve role-specific fields' do
    issue = Issue.find(1)

    [
      ['jsmith', 'jsmith', true], # Manager
      ['dlopper', 'foo', false] # Developer
    ].each do |login, password, can_add_private_notes|
      Capybara.using_session(login) do
        log_user(login, password)
        open_editor(issue)
        assert_role_fields(issue, can_add_private_notes)

        visit edit_issue_path(issue)
        assert_current_path edit_issue_path(issue)
        assert_role_fields(issue, can_add_private_notes)
      end
    end
  end

  test 'E2-E4 tracker change and invalid submission preserve the draft until it is saved' do
    set_tmp_attachments_directory
    issue = Issue.find(1)
    feature_tracker = Tracker.find_by!(name: 'Feature request')
    field = IssueCustomField.create!(
      name: 'Acceptance criteria',
      field_format: 'string',
      is_for_all: true,
      is_required: true,
      trackers: [feature_tracker]
    )
    # Give Feature request a different status list from Bug for the Manager.
    WorkflowTransition.where(
      tracker: feature_tracker,
      role: Role.find_by!(name: 'Manager'),
      old_status: IssueStatus.find_by!(name: 'New')
    ).where.not(new_status: IssueStatus.find_by!(name: 'Assigned')).delete_all

    note = 'Keep this note through tracker changes and validation.'
    filename = 'testfile.txt'
    original_subject = issue.subject
    original_journal_ids = issue.journals.ids

    log_user('jsmith', 'jsmith')
    open_editor(issue)
    within '#issue-form' do
      assert_select 'Tracker', selected: 'Bug'
      assert_select 'Status', options: %w[New Assigned Resolved Feedback Closed Rejected]
      assert_no_field field.name

      fill_in 'issue_notes', with: note
      attach_file 'attachments[dummy][file]', Rails.root.join('test/fixtures/files', filename)
      assert_pending_file(filename)
      assert_selector '.attachments_fields input[name$="[token]"][value]:not([value=""])', visible: :all

      select 'Feature request', from: 'Tracker'
      assert_field field.name
      assert_select 'Status', selected: 'New', options: %w[New Assigned]
      assert_field 'issue_notes', with: note
      assert_pending_file(filename)

      fill_in field.name, with: 'Temporary value'
      fill_in field.name, with: ''
      click_button 'Submit'
    end

    assert_text "#{field.name} cannot be blank"
    assert_equal 'Bug', issue.reload.tracker.name
    assert_equal original_subject, issue.subject
    assert_equal 'New', issue.status.name
    assert_equal original_journal_ids.sort, issue.journals.ids.sort
    assert_empty issue.attachments

    corrected_value = 'Printing succeeds with the default settings'
    within '#issue-form' do
      assert_select 'Tracker', selected: 'Feature request'
      assert_select 'Status', selected: 'New', options: %w[New Assigned]
      assert_field 'issue_notes', with: note
      assert_pending_file(filename)

      fill_in field.name, with: corrected_value
      click_button 'Submit'
    end

    assert_current_path issue_path(issue)
    assert_text 'Successful update.'
    visit issue_path(issue)
    assert_text "Feature request ##{issue.id}"
    assert_text corrected_value
    assert_text note, count: 1
    within '.attachments table' do
      assert_selector 'a', exact_text: filename, count: 1
    end
    assert_equal feature_tracker, issue.reload.tracker
    assert_equal corrected_value, issue.custom_field_value(field)
    assert_equal 1, issue.journals.where(notes: note).count
    assert_equal [filename], issue.attachments.pluck(:filename)
  end

  test 'E5 stale edits report the conflict and cancelling preserves the first save' do
    original = Issue.find(1)
    issue = original.copy(author: original.author)
    issue.save!

    first_subject = 'Subject saved by the first editor'
    stale_subject = 'Subject from the stale editor'
    stale_note = 'Notes from the stale editor'

    Capybara.using_session(:first_editor) do
      log_user('jsmith', 'jsmith')
      open_editor(issue)
      fill_in 'Subject', with: first_subject
    end

    Capybara.using_session(:stale_editor) do
      log_user('dlopper', 'foo')
      open_editor(issue)
      fill_in 'Subject', with: stale_subject
      fill_in 'issue_notes', with: stale_note
    end

    Capybara.using_session(:first_editor) do
      click_button 'Submit'
      assert_current_path issue_path(issue)
      assert_text 'Successful update.'
    end

    Capybara.using_session(:stale_editor) do
      click_button 'Submit'
      assert_text 'The issue has been updated by an other user while you were editing it.'
      assert_text first_subject
      assert_equal first_subject, issue.reload.subject
      assert_field 'Subject', with: stale_subject
      assert_field 'issue_notes', with: stale_note
      assert_text 'Apply my changes anyway'
      assert_text 'Add my notes and discard my other changes'
      assert_text 'Discard all my changes and redisplay'
      choose 'conflict_resolution_cancel'
      click_button 'Submit', match: :first

      assert_current_path issue_path(issue)
      assert_text first_subject
      assert_no_text stale_subject
      assert_no_text stale_note
      assert_equal first_subject, issue.reload.subject
      assert_empty issue.journals.where(notes: stale_note)
    end
  end

  test 'embedded cancel closes the editor and direct cancel returns to the issue' do
    issue = Issue.find(1)
    log_user('jsmith', 'jsmith')
    open_editor(issue)

    assert_selector 'form#issue-form[method="post"][enctype="multipart/form-data"]'
    within('#issue-form') { click_link 'Cancel' }
    assert_no_selector '#issue-form', visible: true
    assert_current_path issue_path(issue)

    visit edit_issue_path(issue)
    within('#issue-form') { click_link 'Cancel' }
    assert_current_path issue_path(issue)
  end

  test 'Assign to me appears only when the current user can select themselves' do
    log_user('admin', 'admin')
    open_editor(Issue.find(10))

    within '#issue-form' do
      click_on 'Assign to me'
      assert_equal User.find_by!(login: 'admin').id.to_s, find_field('Assignee').value
      assert_no_selector '.assign-to-me-link', visible: true
    end

    open_editor(Issue.find(2))
    within '#issue-form' do
      assert_select 'Assignee'
      assert_no_selector '.assign-to-me-link', visible: true
    end
  end

  private

  def open_editor(issue)
    visit issue_path(issue)
    first(:link, 'Edit', exact: true).click
    assert_selector '#issue-form'
  end

  def assert_role_fields(issue, can_add_private_notes)
    within '#issue-form' do
      assert_field 'Subject', with: issue.subject
      assert_field 'issue_notes'
      if can_add_private_notes
        assert_field 'Private notes'
      else
        assert_no_field 'Private notes'
      end
    end
  end

  def assert_pending_file(filename)
    assert_field class: 'filename', with: filename, count: 1
  end
end
