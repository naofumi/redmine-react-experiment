# frozen_string_literal: true

module IssueListHelper
  def issue_list_props
    return {results: nil} unless @issues
    return {results: nil, noData: l(:label_no_data)} if @issues.empty?

    {
      results: {
        columns: @query.inline_columns.map { |column| issue_list_column(column) },
        groups: issue_list_groups,
        tableClass: @query.css_classes,
        contextMenuUrl: issues_context_menu_path,
        action: url_for({}),
        backUrl: url_for(params: request.query_parameters),
        columnNames: @query.columns.map(&:name),
        authenticityToken: form_authenticity_token(form_options: {action: url_for({}), method: :post}),
        checkAllLabel: "#{l(:button_check_all)} / #{l(:button_uncheck_all)}",
        actionsLabel: l(:button_actions),
        actionsIcon: sprite_icon('3-bullets', l(:button_actions)),
        expandIcon: sprite_icon('angle-right', rtl: true),
        collapseIcon: sprite_icon('angle-down'),
        toggleGroupsLabel: "#{l(:button_collapse_all)}/#{l(:button_expand_all)}",
        pagination: issue_list_pagination
      }
    }
  end

  private

  def issue_list_column(column)
    data = {key: column.name, caption: column.caption, cssClass: column.css_classes}
    if (sort = query_column_header_sort(@query, column))
      data[:sort] = {
        href: url_for(sort[:url]),
        cssClass: sort[:link_options][:class],
        title: sort[:link_options][:title],
        icon: sort[:icon] && sprite_icon(sort[:icon])
      }
    end
    data
  end

  def issue_list_groups
    groups = []
    grouped_issue_list(@issues, @query) do |issue, level, name, count, totals|
      if name || groups.empty?
        heading = {name: h(name), count: count, totals: h(totals)} if name
        groups << {key: issue.id, heading: heading, rows: []}
      end
      groups.last[:rows] << {
        id: issue.id,
        cssClass: issue.css_classes,
        level: level,
        cells: @query.inline_columns.map { |column| h(column_content(column, issue)) },
        blocks: issue_list_blocks(issue)
      }
    end
    groups
  end

  def issue_list_blocks(issue)
    @query.block_columns.filter_map do |column|
      content = column_content(column, issue)
      next if content.blank?

      {
        key: column.name, cssClass: column.css_classes,
        caption: @query.block_columns.size > 1 ? column.caption : nil,
        content: h(content)
      }
    end
  end

  def issue_list_pagination
    paginator = @issue_pages
    page_link = lambda do |page|
      url_for(params: request.query_parameters.merge(paginator.page_param => page)) if page
    end
    per_page = per_page_options(paginator.per_page, paginator.item_count).map do |size|
      params = request.query_parameters.merge(:per_page => size, paginator.page_param => nil)
      {size: size, href: size == paginator.per_page ? nil : url_for(params: params)}
    end
    if paginator.multiple_pages?
      previous_link = {text: "« #{l(:label_previous)}", href: page_link.call(paginator.previous_page), accessKey: accesskey(:previous)}
      next_link = {text: "#{l(:label_next)} »", href: page_link.call(paginator.next_page), accessKey: accesskey(:next)}
    end
    per_page_before, per_page_after = l(:label_display_per_page, '%{links}').split('%{links}', 2)
    {
      previous: previous_link,
      next: next_link,
      pages: paginator.linked_pages.map do |page|
        {number: page, href: page == paginator.page ? nil : page_link.call(page)}
      end,
      items: "(#{paginator.first_item}-#{paginator.last_item}/#{paginator.item_count})",
      perPage: per_page,
      perPageBefore: per_page_before,
      perPageAfter: per_page_after
    }
  end
end
