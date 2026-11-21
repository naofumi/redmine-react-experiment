import { createInertiaApp } from '@inertiajs/react';
import type { ComponentProps } from 'react';
import { createRoot } from 'react-dom/client';
import IssueEditor from './IssueEditor';
import IssueList from './IssueList';

if (document.querySelector('script[data-page="app"][type="application/json"]')) {
  void createInertiaApp({
    resolve(name) {
      if (name === 'Issues/Edit') return IssueEditor;
      if (name === 'Issues/Index') return IssueList;

      throw new Error(`Unknown Inertia page: ${name}`);
    },
    setup({ el, App, props }) {
      createRoot(el).render(<App {...props} />);
    },
  });
}

document.querySelectorAll('[data-issue-editor]').forEach((element) => {
  const data = element.getAttribute('data-issue-editor');
  if (!data) return;

  const props: ComponentProps<typeof IssueEditor> = JSON.parse(data);
  createRoot(element).render(<IssueEditor {...props} />);
});
