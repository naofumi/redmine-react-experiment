import { memo, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { ISSUE_FIELD_OPTIONS_EVENT, IssueFieldAffordances, useIssueFieldAutocomplete } from './IssueFieldActions';
import type { IssueFieldActions, IssueFieldOptions } from './IssueFieldActions';

declare global {
  interface Window {
    setupFileDrop?: () => void;
    rm?: { AutoComplete?: { dataSources: { users?: string } } };
  }
}

interface Field {
  name: string;
  kind: 'text' | 'checkbox' | 'select' | 'date' | 'wiki';
  value: string;
  label: string;
  invalid: boolean;
  required: boolean;
  refresh?: boolean;
  optionsHtml?: string;
  html?: string;
  actions?: IssueFieldActions;
  assignToMe?: string;
  userId?: string;
}

interface Schema {
  projectId: number;
  properties: boolean;
  mentionUrl: string | null;
  fields: Field[];
  customFields: { id: number; fullWidth: boolean; html: string }[];
  statusLabel: string;
  statusText: string;
  notesHtml: string | null;
  privateNotes: boolean;
  privateNotesChecked: boolean;
  timeHtml: string | null;
  attachmentsHtml: string | null;
}

interface Props {
  heading: string;
  issueUrl: string;
  editUrl: string;
  embedded: boolean;
  hidden: Record<string, string | number>;
  validationMessages: string[];
  conflictHtml: string | null;
  labels: Record<'properties' | 'notes' | 'privateNotes' | 'submit' | 'cancel' | 'edit' | 'refreshError' | 'retry', string>;
  schema: Schema;
}

// These widgets still own their DOM (wiki toolbar, custom field formats and uploads).
// The parent chooses a new key when Rails needs to replace the widget.
const RailsWidget = memo(function RailsWidget({ html }: { html: string }) {
  const initialMarkup = useRef({ __html: html });
  return <div dangerouslySetInnerHTML={initialMarkup.current} />;
});

function Property({ field, refresh, labels }: { field: Field; refresh: () => void; labels: Props['labels'] }) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(field.value);
  const select = useRef<HTMLSelectElement>(null);
  const input = useRef<HTMLInputElement>(null);
  useIssueFieldAutocomplete(input, field.actions?.autocompleteUrl, refresh);
  const [created, setCreated] = useState<IssueFieldOptions | null>(null);
  useLayoutEffect(() => {
    const node = select.current;
    if (!node) return;
    const onCreate = (event: Event) => setCreated((event as CustomEvent<IssueFieldOptions>).detail);
    node.addEventListener(ISSUE_FIELD_OPTIONS_EVENT, onCreate);
    setCreated(null);
    return () => node.removeEventListener(ISSUE_FIELD_OPTIONS_EVENT, onCreate);
  }, [field]);
  const options = useMemo(() => ({ __html: created?.optionsHtml ?? field.optionsHtml ?? '' }), [created, field]);
  useLayoutEffect(() => {
    if (select.current) {
      select.current.value = created?.value ?? field.value;
      setValue(select.current.value);
    }
  }, [created, field]);

  function choose(next: string) {
    if (!select.current) return;
    select.current.value = next;
    setValue(next);
    if (field.refresh) refresh();
  }

  const id = 'issue_' + field.name;
  const name = 'issue[' + field.name + ']';
  const label = <label htmlFor={id} className={field.invalid ? 'error' : undefined}>
    {field.label}{field.required && <span className="required"> *</span>}
  </label>;

  if (field.kind === 'checkbox') return <p id={id + '_wrap'}>
    <input type="hidden" name={name} value="0" />
    <input id={id} name={name} type="checkbox" value="1" defaultChecked={field.value === '1'} />
    <label className="inline" htmlFor={id}>{field.label}</label>
  </p>;

  if (field.kind === 'wiki') return <div className="form-field">
    {label}
    <div id="issue_description_and_toolbar" hidden={!editing}><RailsWidget html={field.html!} /></div>
    {!editing && <a href="#issue_description" className="icon icon-edit" onClick={event => { event.preventDefault(); setEditing(true); }}>{labels.edit}</a>}
  </div>;

  if (field.kind === 'select') return <p>{label}
    <select ref={select} id={id} name={name} data-react-issue-field="" title={field.actions?.selectedDescription || undefined}
      onChange={event => {
        setValue(event.target.value);
        if (field.refresh) refresh();
      }}
      dangerouslySetInnerHTML={options} />
    <IssueFieldAffordances actions={field.actions} choose={choose} closeLabel={labels.cancel} />
    {field.assignToMe && value !== field.userId &&
      <button type="button" className="assign-to-me-link" onClick={() => {
        select.current!.value = field.userId!;
        setValue(field.userId!);
      }}>{field.assignToMe}</button>}
  </p>;

  return <p>{label}<input ref={input} id={id} name={name} type={field.kind} defaultValue={field.value}
    size={field.name === 'subject' ? 80 : 10} maxLength={field.name === 'subject' ? 255 : undefined}
    onBlur={event => {
      const submitting = event.relatedTarget?.matches('input[type="submit"], button[type="submit"]');
      if (field.refresh && !submitting && event.target.value !== field.value) refresh();
    }} /></p>;
}

export default function IssueEditor(props: Props) {
  const [schema, setSchema] = useState(props.schema);
  const [refreshState, setRefreshState] = useState<'ready' | 'pending' | 'failed'>('ready');
  const form = useRef<HTMLFormElement>(null);
  const busy = useRef(false);
  const csrf = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
  const { labels } = props;

  // Redmine's existing uploader binds drop/paste listeners after its DOM exists.
  useEffect(() => {
    window.setupFileDrop?.();
    if (window.rm?.AutoComplete) {
      const sources = window.rm.AutoComplete.dataSources;
      if (schema.mentionUrl) sources.users = schema.mentionUrl;
      else delete sources.users;
    }
  }, [schema]);

  async function refresh() {
    if (busy.current || !form.current) return;
    const body = new URLSearchParams();
    for (const [key, value] of new FormData(form.current)) {
      if (typeof value === 'string') body.append(key, value);
    }
    busy.current = true;
    setRefreshState('pending');
    try {
      const response = await fetch(props.editUrl, {
        method: 'PATCH', body,
        headers: { Accept: 'application/json', 'X-Redmine-Editor': 'fields', 'X-CSRF-Token': csrf || '' },
      });
      if (!response.ok) throw new Error(String(response.status));
      const updated: Schema = await response.json();
      setSchema(updated);
      setRefreshState('ready');
    } catch {
      setRefreshState('failed');
    } finally {
      busy.current = false;
    }
  }

  function submit(event: FormEvent) {
    if (busy.current || refreshState !== 'ready' || form.current?.querySelector('.ajax-loading, .ajax-waiting')) {
      event.preventDefault();
    }
  }

  function property(field: Field) {
    return <Property key={field.name} field={field} refresh={refresh} labels={labels} />;
  }
  const top = ['is_private', 'project_id', 'tracker_id', 'subject', 'description'];
  const right = ['parent_issue_id', 'start_date', 'due_date', 'estimated_hours', 'done_ratio'];
  function customField(field: Schema['customFields'][number]) {
    // Only Rails custom-field formatters emit this markup. Replace the field when
    // the formatter changes its options or normalizes the submitted value.
    return <div className="form-field" key={field.id} dangerouslySetInnerHTML={{ __html: field.html }} />;
  }
  const normalFields = schema.customFields.filter(field => !field.fullWidth);
  const customMiddle = Math.ceil(normalFields.length / 2);

  return <>
    {!props.embedded && <h2>{props.heading}</h2>}
    <form ref={form} id="issue-form" action={props.issueUrl} method="post" encType="multipart/form-data" onSubmit={submit}>
      <input type="hidden" name="_method" value="patch" />
      {csrf && <input type="hidden" name="authenticity_token" value={csrf} />}
      {Object.entries(props.hidden).map(([name, value]) => <input key={name} name={name} value={value} type="hidden" />)}
      {props.validationMessages.length > 0 && <div id="errorExplanation"><ul>
        {props.validationMessages.map((message, index) => <li key={index}>{message}</li>)}
      </ul></div>}
      {props.conflictHtml && <RailsWidget html={props.conflictHtml} />}
      <div className="box">
        {schema.properties && <fieldset className="tabular" disabled={refreshState === 'pending'}>
          <legend>{labels.properties}</legend>
          <div id="all_attributes">
            {schema.fields.filter(field => top.includes(field.name)).map(property)}
            <div className="attributes" id="attributes">
              <div className="splitcontent">
                <div className="splitcontentleft">
                  {!schema.fields.some(field => field.name === 'status_id') &&
                    <p><label>{schema.statusLabel}</label>{schema.statusText}</p>}
                  {schema.fields.filter(field => !top.includes(field.name) && !right.includes(field.name)).map(property)}
                </div>
                <div className="splitcontentright">{schema.fields.filter(field => right.includes(field.name)).map(property)}</div>
              </div>
              <div className="splitcontent">
                <div className="splitcontentleft">{normalFields.slice(0, customMiddle).map(customField)}</div>
                <div className="splitcontentright">{normalFields.slice(customMiddle).map(customField)}</div>
              </div>
              {schema.customFields.filter(field => field.fullWidth).map(customField)}
            </div>
          </div>
        </fieldset>}
        {refreshState === 'failed' && <p className="error" role="alert">{labels.refreshError} <button type="button" onClick={refresh}>{labels.retry}</button></p>}
        {schema.timeHtml && <RailsWidget key={schema.projectId} html={schema.timeHtml} />}
        {schema.notesHtml && <fieldset id="add_notes"><legend>{labels.notes}</legend>
          <RailsWidget html={schema.notesHtml} />
          {schema.privateNotes && <label htmlFor="issue_private_notes">
            <input id="issue_private_notes" type="checkbox" name="issue[private_notes]" value="1" defaultChecked={schema.privateNotesChecked} /> {labels.privateNotes}
          </label>}
        </fieldset>}
        {schema.attachmentsHtml && <RailsWidget html={schema.attachmentsHtml} />}
      </div>
      <input type="submit" value={labels.submit} disabled={refreshState !== 'ready'} />{' '}
      <a href={props.issueUrl} onClick={event => {
        const inline = form.current?.closest<HTMLElement>('#update');
        if (props.embedded && inline) {
          event.preventDefault();
          inline.style.display = 'none';
        }
      }}>{labels.cancel}</a>
    </form>
  </>;
}
