# frozen_string_literal: true

require 'csv'
require_relative '../application_system_test_case'

class IssueListMigrationTest < ApplicationSystemTestCase
  setup do
    @project = Project.find(1)
    @manager = User.find_by!(login: 'jsmith')
    @bug = Tracker.find_by!(name: 'Bug')
    @feature = Tracker.find_by!(name: 'Feature request')
    @delta = list_issue('Delta', @bug)
    @bravo = list_issue('Bravo', @feature)
    @alpha = list_issue('Alpha', @bug)
    @charlie = list_issue('Charlie', @bug, private_issue: true)
    @echo = list_issue('Echo', @bug)
    @query = IssueQuery.create!(
      name: 'Migration list', user: @manager, visibility: Query::VISIBILITY_PUBLIC,
      project: @project, filters: {'subject' => {operator: '~', values: ['Migration list']}},
      column_names: [:id, :subject, :tracker], sort_criteria: [['id', 'asc']]
    )
    Setting.per_page_options = '2, 25'
    Setting.issues_export_limit = '10'
  end

  test 'L1 saved query keeps columns and restricts private rows by role' do
    Capybara.using_session(:list_manager) do
      log_user('jsmith', 'jsmith')
      visit list_url
      assert_text 'Migration list'
      assert_columns
      assert_rows @delta, @bravo
      assert_selector '.pagination .items', exact_text: '(1-2/5)'
      within('.pagination') {click_link '2'}
      assert_rows @alpha, @charlie
    end

    Capybara.using_session(:list_developer) do
      log_user('dlopper', 'foo')
      visit list_url
      assert_columns
      assert_rows @delta, @bravo
      assert_selector '.pagination .items', exact_text: '(1-2/4)'
      within('.pagination') {click_link '2'}
      assert_rows @alpha, @echo
      assert_selector '.pagination .items', exact_text: '(3-4/4)'
      assert_no_selector "#issue-#{@charlie.id}"
    end
  end

  test 'L2-L5 filter sort paginate use history reopen and export' do
    log_user('jsmith', 'jsmith')
    visit list_url
    find('#filters legend').click
    select 'Tracker', from: 'Add filter'
    select 'Bug', from: 'values_tracker_id_1'
    within('#query_form') {click_link 'Apply'}

    assert_rows @delta, @alpha
    assert_select 'values_tracker_id_1', selected: 'Bug'
    assert_selector '.pagination .items', exact_text: '(1-2/4)'
    within('table.issues thead') {click_link 'Subject'}
    assert_rows @alpha, @charlie
    assert_selector 'th.subject a.sort.asc'
    assert_columns

    within('.pagination') {click_link '2'}
    assert_rows @delta, @echo
    assert_selector '.pagination .items', exact_text: '(3-4/4)'
    filtered_url = page.current_url
    within("#issue-#{@delta.id}") {click_link @delta.subject}
    assert_current_path issue_path(@delta)
    page.go_back
    assert_current_path filtered_url, url: true
    assert_rows @delta, @echo
    assert_columns
    assert_select 'values_tracker_id_1', selected: 'Bug'
    assert_selector 'th.subject a.sort.asc'

    within('p.other-formats') {click_link 'CSV'}
    within('#csv-export-form') do
      assert_field 'Selected Columns', checked: true
      click_button 'Export'
    end
    exported = CSV.read(downloaded_file('*.csv'), headers: true, encoding: 'bom|utf-8')
    assert_equal ['#', 'Subject', 'Tracker'], exported.headers
    expected = [@alpha, @charlie, @delta, @echo]
    assert_equal expected.map {|issue| issue.id.to_s}, exported['#']
    assert_equal expected.map(&:subject), exported['Subject']
    assert_equal ['Bug'], exported['Tracker'].uniq

    visit project_issues_path(@project)
    assert_rows @alpha, @charlie
    assert_select 'values_tracker_id_1', selected: 'Bug'

    Capybara.using_session(:list_fresh) do
      log_user('jsmith', 'jsmith')
      visit list_url(page: 2)
      assert_columns
      assert_rows @alpha, @charlie
      visit filtered_url
      assert_rows @delta, @echo
      assert_columns
      assert_select 'values_tracker_id_1', selected: 'Bug'
      assert_selector 'th.subject a.sort.asc'
      visit project_issues_path(@project)
      assert_rows @alpha, @charlie

      sign_out_user
      log_user('jsmith', 'jsmith')
      visit project_issues_path(@project)
      assert_no_field 'values_tracker_id_1'
    end
  end

  private

  def list_issue(name, tracker, private_issue: false)
    Issue.create!(
      project: @project, tracker: tracker, author: @manager,
      subject: "Migration list #{name}", is_private: private_issue
    )
  end

  def list_url(**)
    project_issues_path(@project, query_id: @query.id, **)
  end

  def assert_columns
    assert_equal ['#', 'Subject', 'Tracker'], all('table.issues thead th:not(.checkbox, .buttons)').map(&:text)
  end

  def assert_rows(*issues)
    assert_selector 'table.issues tbody tr.hascontextmenu', count: issues.size
    issues.each_with_index do |issue, index|
      assert_selector "table.issues tbody tr#issue-#{issue.id}:nth-child(#{index + 1})"
    end
  end
end
