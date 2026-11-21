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

class IssueEditorActionsTest < ApplicationSystemTestCase
  def test_create_category_and_version_from_direct_edit
    log_user('jsmith', 'jsmith')
    issue = Issue.find(1)
    visit edit_issue_path(issue)
    fill_in 'issue_notes', with: 'Keep this draft while creating options.'

    click_on 'New category'
    within('#ajax-modal') do
      fill_in 'Name', with: 'Editor category'
      click_button 'Create'
    end
    assert_select 'Category', selected: 'Editor category'

    click_on 'New version'
    within('#ajax-modal') do
      fill_in 'Name', with: 'Editor version'
      click_button 'Create'
    end
    assert_select 'Target version', selected: 'Editor version'
    assert_select 'Category', selected: 'Editor category'
    assert_field 'issue_notes', with: 'Keep this draft while creating options.'

    click_button 'Submit'
    assert_text 'Successful update.'
    assert_equal 'Editor category', issue.reload.category.name
    assert_equal 'Editor version', issue.fixed_version.name
  end

  def test_select_status_description_and_parent_suggestion_from_direct_edit
    log_user('jsmith', 'jsmith')
    issue = Issue.find(2)
    parent = Issue.find(1)
    visit edit_issue_path(issue)

    click_link 'View all issue statuses description'
    within('#issue_statuses_description') do
      click_link 'Resolved'
    end
    assert_no_selector '#issue_statuses_description'
    assert_select 'Status', selected: 'Resolved'

    fill_in 'Parent task', with: 'Cannot print'
    within('ul.ui-autocomplete') do
      find('li', text: parent.subject).click
    end
    assert_field 'Parent task', with: parent.id.to_s
    assert_select 'Status', selected: 'Resolved'

    click_button 'Submit'
    assert_text 'Successful update.'
    assert_equal parent.id, issue.reload.parent_id
    assert_equal 'Resolved', issue.status.name

    visit edit_issue_path(issue)
    fill_in 'Parent task', with: ''
    click_button 'Submit'
    assert_text 'Successful update.'
    assert_nil issue.reload.parent_id
  end
end
