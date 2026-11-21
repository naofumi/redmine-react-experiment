import { useLayoutEffect, useRef } from 'react';
import type { RefObject } from 'react';
import { createPortal } from 'react-dom';

export const ISSUE_FIELD_OPTIONS_EVENT = 'redmine:issue-field-options';

export interface IssueFieldOptions {
  optionsHtml: string;
  value: string;
}

interface Description {
  value: string;
  name: string;
  description: string;
}

interface Descriptions {
  id: string;
  title: string;
  helpLabel: string;
  selectLabel: string;
  icon: string;
  items: Description[];
}

export interface IssueFieldActions {
  selectedDescription?: string | null;
  descriptions?: Descriptions | null;
  warning?: string | null;
  warningIcon?: string;
  create?: { url: string; label: string; icon: string };
  autocompleteUrl?: string;
}

interface AutocompleteWidget {
  autocomplete(options: {
    source: string;
    minLength: number;
    position: { collision: string };
    select: (event: Event, result: { item: { value: string } }) => false;
  }): void;
  autocomplete(action: 'destroy'): void;
}

const legacy = window as Window & { jQuery?: (input: HTMLInputElement) => AutocompleteWidget };

export function useIssueFieldAutocomplete(input: RefObject<HTMLInputElement | null>, url?: string, onSelect?: () => void) {
  const selectCallback = useRef(onSelect);
  useLayoutEffect(() => {
    selectCallback.current = onSelect;
  }, [onSelect]);

  useLayoutEffect(() => {
    const element = input.current;
    if (!element || !url || !legacy.jQuery) return;

    const widget = legacy.jQuery(element);
    widget.autocomplete({
      source: url,
      minLength: 2,
      position: { collision: 'flipfit' },
      select: (_event, result) => {
        element.value = result.item.value;
        selectCallback.current?.();
        return false;
      },
    });
    return () => widget.autocomplete('destroy');
  }, [input, url]);
}

function DescriptionPicker({ descriptions, choose, closeLabel }: {
  descriptions: Descriptions;
  choose: (value: string) => void;
  closeLabel: string;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = descriptions.id + '_title';

  return <>
    {' '}<a className="icon-only icon-help" href="#" title={descriptions.helpLabel}
      aria-haspopup="dialog" onClick={event => {
        event.preventDefault();
        dialog.current?.showModal();
      }} dangerouslySetInnerHTML={{ __html: descriptions.icon }} />
    {createPortal(<dialog id={descriptions.id} ref={dialog} aria-labelledby={heading} style={{ width: 'min(500px, 90vw)' }}>
      <h3 id={heading}>{descriptions.title}</h3>
      <dl>{descriptions.items.map(item => <div key={item.value}>
        <dt><a href="#" title={descriptions.selectLabel} onClick={event => {
          event.preventDefault();
          dialog.current?.close();
          choose(item.value);
        }}>{item.name}</a></dt>
        <dd>{item.description}</dd>
      </div>)}</dl>
      <button type="button" onClick={() => dialog.current?.close()}>{closeLabel}</button>
    </dialog>, document.body)}
  </>;
}

export function IssueFieldAffordances({ actions, choose, closeLabel }: {
  actions?: IssueFieldActions | null;
  choose: (value: string) => void;
  closeLabel: string;
}) {
  if (!actions) return null;

  return <>
    {actions.descriptions && <DescriptionPicker descriptions={actions.descriptions} choose={choose} closeLabel={closeLabel} />}
    {actions.warning && <span className="icon-only icon-warning" title={actions.warning}
      dangerouslySetInnerHTML={{ __html: actions.warningIcon || '' }} />}
    {actions.create && <>{' '}<a className="icon-only icon-add" href={actions.create.url} title={actions.create.label}
      data-remote="true" data-method="get" tabIndex={200} dangerouslySetInnerHTML={{ __html: actions.create.icon }} /></>}
  </>;
}
