# React migration charter

Adopted 2026-11-21. Revisit after the issue editor and issue list have been evaluated.

## Purpose

Use this Redmine fork to learn how to convert a mature Rails application from ERB to React. The experiment should produce two working examples and enough evidence for another Rails team to decide which parts of the approach it could reuse. A full Redmine rewrite is a possible later decision.

React is a project requirement. Frontend engineers should be able to build and maintain whole screens in React. For users, success means they can follow familiar links and complete familiar tasks with the same permissions and outcomes. Reuse the current CSS, icons, labels, and layout. Small visual differences are acceptable when users can still rely on the same interactions.

## Starting architecture

- Build React and TypeScript pages directly in this Rails application. Use Inertia Rails to connect an existing browser route to a React page and pass it the data it needs. Render pages in the browser. SEO and third-party plugin compatibility are outside the experiment.
- Keep Rails responsible for authentication, authorization, validation, queries, and writes. Make decisions that ERB currently obtains from models and helpers explicit in the page data. For example, Rails supplies the statuses a particular user can choose and checks the submitted transition.
- Give React ownership of rendering, focus, and unsaved input. When a tracker change affects the form, send the draft to Rails for updated field choices and preserve the user’s still-applicable input. This is an early test of the boundary between the two layers.

## First two workflows

| Workflow | What we will build and verify |
| --- | --- |
| **1. Edit and save an issue** | Open an existing issue at its current edit URL. Exercise the form under two roles with different permissions. Change the tracker with unsaved text and a pending attachment, submit invalid input, correct it, and save. Compare field choices, validation feedback, retained input, and the final redirect with ERB. |
| **2. Use the issue list** | Open a saved query with selected columns, change a filter or sort order, and paginate. Reopen the resulting URL and use the browser’s Back button. Compare the visible rows, column order, navigation, and CSV export with ERB. |

The editor tests a form whose rules change while the user is typing. The list tests how Rails query state, the URL, and the rendered page work together. Evaluate both before extending the migration to other screens.

## Verification and release

Build and verify one workflow at a time. The [verification record](react-migration-verification.md) gives each step a pass condition and a place to record the ERB and React outcomes. Judge UI differences by their effect on completing the task. Pixel matching and a formal accessibility audit are outside the pilot scope.

If the experiment proceeds to a release, the working assumption is a **single cutover**. The existing release serves ERB while the rewrite is developed and tested. Once the agreed release scope passes its checks, one release switches those browser routes to React at their existing URLs. Finishing the two pilot workflows triggers an evaluation, with no commitment to a cutover date or a full rewrite.

## How we will decide and revise

After both workflows, record what each React page needed from Rails, where the existing controller and model code could be reused, and which interactions were hardest to preserve. Use concrete examples to answer three questions:

1. Can a frontend engineer understand and change the screen from its React components and page data?
2. Can Rails remain the single source of truth for workflow and permission rules?
3. Can users complete the original tasks, and what did it cost to preserve that behavior?

Use the findings to continue, revise the architecture, or conclude the experiment. When evidence changes a decision, update the relevant section of this charter and add a dated note with the observation and its consequence.

## Decision notes

**2026-11-21 — Support both editor entry points.** Redmine exposes Edit inline on the issue detail page and at a dedicated URL. Both now use the same React component and the same Rails page data. The ERB detail page mounts the component in its existing layout. Inertia supplies it on the dedicated route. Keeping the mount outside the component let us verify both entry points with the same permission rules and save action.
