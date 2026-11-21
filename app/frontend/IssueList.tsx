import { Fragment, useState } from 'react';

type Column = {
  key: string;
  caption: string;
  cssClass: string;
  sort?: { href: string; title: string; cssClass: string | null; icon: string | null };
};

type Row = {
  id: number;
  cssClass: string;
  level: number;
  cells: string[];
  blocks: { key: string; cssClass: string; caption: string | null; content: string }[];
};

type PageLink = { text: string; href: string | null; accessKey: string };

type PageLinks = {
  previous: PageLink | null;
  next: PageLink | null;
  pages: { number: number; href: string | null }[];
  items: string;
  perPage: { size: number; href: string | null }[];
  perPageBefore: string;
  perPageAfter: string | null;
};

type Results = {
  columns: Column[];
  groups: { key: number; heading: { name: string; count: number | null; totals: string } | null; rows: Row[] }[];
  tableClass: string;
  contextMenuUrl: string;
  action: string;
  backUrl: string;
  columnNames: string[];
  authenticityToken: string;
  checkAllLabel: string;
  actionsLabel: string;
  actionsIcon: string;
  expandIcon: string;
  collapseIcon: string;
  toggleGroupsLabel: string;
  pagination: PageLinks;
};

function PageDirection({ link, direction }: { link: PageLink; direction: 'previous' | 'next' }) {
  return (
    <li className={link.href ? `${direction} page` : direction}>
      {link.href ? <a href={link.href} accessKey={link.accessKey}>{link.text}</a> : <span>{link.text}</span>}
    </li>
  );
}

function Pagination({ previous, next, pages, items, perPage, perPageBefore, perPageAfter }: PageLinks) {
  return (
    <span className="pagination">
      <ul className="pages">
        {previous && <PageDirection link={previous} direction="previous" />}
        {pages.map(({ number, href }, index) => (
          <Fragment key={number}>
            {index > 0 && pages[index - 1].number !== number - 1 && <li className="spacer"><span>…</span></li>}
            <li className={href ? 'page' : 'current'}>
              {href ? <a href={href}>{number}</a> : <span aria-current="page">{number}</span>}
            </li>
          </Fragment>
        ))}
        {next && <PageDirection link={next} direction="next" />}
      </ul>
      <span>
        <span className="items">{items}</span>{' '}
        {perPage.length > 0 && (
          <span className="per-page">
            {perPageBefore}
            {perPage.map(({ size, href }, index) => (
              <Fragment key={size}>
                {index > 0 && ', '}
                {href ? <a href={href}>{size}</a> : <span className="selected">{size}</span>}
              </Fragment>
            ))}
            {perPageAfter}
          </span>
        )}
      </span>
    </span>
  );
}

function ColumnHeader({ column }: { column: Column }) {
  const { cssClass, caption, sort } = column;
  return (
    <th className={cssClass}>
      {sort ? (
        <a href={sort.href} title={sort.title} className={sort.cssClass ?? undefined}>
          {sort.icon ? <><span dangerouslySetInnerHTML={{ __html: sort.icon }} /><span className="icon-label">{caption}</span></> : caption}
        </a>
      ) : caption}
    </th>
  );
}

export default function IssueList({ results, noData }: { results: Results | null; noData?: string }) {
  const [collapsedGroups, setCollapsedGroups] = useState<Set<number>>(() => new Set());
  if (!results) return noData ? <p className="nodata">{noData}</p> : null;

  const { columns, groups, contextMenuUrl, action, backUrl, columnNames, authenticityToken, pagination } = results;
  const columnCount = columns.length + 2;

  function toggleGroup(key: number) {
    setCollapsedGroups((current) => {
      const next = new Set(current);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  return (
    <>
      <form action={action} method="post" data-cm-url={contextMenuUrl}>
        <input name="authenticity_token" type="hidden" value={authenticityToken} />
        <input name="back_url" type="hidden" value={backUrl} />
        {columnNames.map((column) => <input key={column} name="c[]" type="hidden" value={column} />)}
        <div className="autoscroll">
          <table className={`list issues odd-even ${results.tableClass}`}>
            <thead>
              <tr>
                <th className="checkbox hide-when-print">
                  <input type="checkbox" id="check_all" name="check_all" value="" className="toggle-selection" title={results.checkAllLabel} />
                </th>
                {columns.map((column) => <ColumnHeader key={column.key} column={column} />)}
                <th className="buttons hide-when-print" />
              </tr>
            </thead>
            <tbody>
              {groups.map(({ key, heading, rows }) => {
                const isOpen = !collapsedGroups.has(key);
                return (
                  <Fragment key={key}>
                    {heading && (
                      <tr className={isOpen ? 'group open' : 'group'}>
                        <td colSpan={columnCount}>
                          <button
                            type="button"
                            className={`expander icon ${isOpen ? 'icon-expanded' : 'icon-collapsed'}`}
                            aria-expanded={isOpen}
                            aria-labelledby={`issue-group-${key}`}
                            onClick={() => toggleGroup(key)}
                            dangerouslySetInnerHTML={{ __html: isOpen ? results.collapseIcon : results.expandIcon }}
                          />
                          <span className="name" id={`issue-group-${key}`} dangerouslySetInnerHTML={{ __html: heading.name }} />
                          {heading.count !== null && <span className="badge badge-count count">{heading.count}</span>}
                          <span className="totals" dangerouslySetInnerHTML={{ __html: heading.totals }} />
                          <a href="#" className="toggle-all" onClick={(event) => {
                            event.preventDefault();
                            setCollapsedGroups(new Set(isOpen ? groups.map((group) => group.key) : []));
                          }}>{results.toggleGroupsLabel}</a>
                        </td>
                      </tr>
                    )}
                    {rows.map((row, index) => {
                      const shade = index % 2 === 0 ? 'odd' : 'even';
                      const indent = row.level > 0 ? ` idnt idnt-${row.level}` : '';
                      return (
                        <Fragment key={row.id}>
                          <tr id={`issue-${row.id}`} hidden={!isOpen} className={`hascontextmenu ${shade} ${row.cssClass}${indent}`}>
                            <td className="checkbox hide-when-print"><input type="checkbox" name="ids[]" value={row.id} /></td>
                            {columns.map((column, cell) => (
                              <td key={column.key} className={column.cssClass} dangerouslySetInnerHTML={{ __html: row.cells[cell] }} />
                            ))}
                            <td className="buttons hide-when-print">
                              <a href="#" title={results.actionsLabel} className="icon-only icon-actions js-contextmenu" dangerouslySetInnerHTML={{ __html: results.actionsIcon }} />
                            </td>
                          </tr>
                          {row.blocks.map((block) => (
                            <tr key={block.key} className={shade} hidden={!isOpen}>
                              <td colSpan={columnCount} className={`${block.cssClass} block_column`}>
                                {block.caption && <span>{block.caption}</span>}
                                <div className="block-content" dangerouslySetInnerHTML={{ __html: block.content }} />
                              </td>
                            </tr>
                          ))}
                        </Fragment>
                      );
                    })}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      </form>
      <Pagination {...pagination} />
    </>
  );
}
