# White Atlas Select Menu — application-wide dropdown contract

Release slice: RC053.2 · branch `feat/rc053-white-atlas-select-menus-2026-11-14`

## Audit: the six standard select controls
All 47 HTML-ERB templates and the Stimulus controller files on SHA
`620aab5` were inspected. At this checkpoint all native select-only
fields belong to three product workflows:

| File | Controls |
| --- | --- |
| `app/views/owner_capabilities/index.html.erb` | delivery mode, experience, willingness, repeated for each capability |
| `app/views/consultations/index.html.erb` | status search filter |
| `app/views/client_requests/new.html.erb` | request type |
| `app/views/project_intakes/new.html.erb` | demonstration intake type |

The language switcher (`app/views/shared/_locale_switcher.html.erb`) already
uses a visually branded `<details>` contextual menu; competency cards are
accordions, not a system selection dropdown. Native date/time pickers are
separate UI primitives and are not modified by this select-only component.

## Architecture
- Global Stimulus `rc-select` enhancer on the two app-shell layouts.
- Progressive enhancement: when JS is absent, the original `<select>` remains
  functional and maintains standard browser accessibility and form submission.
- When JS is enabled, the native element is visually hidden. Button
  `role=combobox` and portalled `role=listbox` render **inside the product
  UI**, including inside clipped details or cards. No OS select menu appears.
- Native select remains the **single source of submitted value and validation**.
  User selection dispatches `input` and `change`, preserving Rails/Turbo
  behavior; new blank options, disabled controls and reset are supported.
- Keyboard: Arrow Up/Down, Home/End, Enter/Space, Escape, Tab, type-to-jump.
  `aria-controls`, `aria-expanded`, `aria-activedescendant`, and
  `aria-selected` reflect state.
- A single menu may be open. Outside click, Turbo page cache and controller
  disconnect clean up. Portal ensures menu does not get clipped by an
  ancestor `overflow: hidden`.
- Styling only in `_rc_select_menu.scss` using White Atlas tokens.
  Existing calendar, intake, consultation and owner CSS is preserved.
- The marketing layout currently has no native selects and does not load app
  JavaScript; its language `<details>` is already branded.

## Validation
- `npm run build`, `npm run build:css`, exact-SHA Rails/Chrome/Security.
- Browser QA at desktop and 390px, filtered query submission, keyboard
  interaction and Turbo revisit, as covered in system tests.
- Manually inspect the three owner capability selectors in an expanded React
  card; they must display product-owned context menus rather than Chromium
  menus.
- Do not merge or deploy to Railway until full CI passes and the user validates
  the local preview. Local DB and API spend are unchanged by this UI slice.
