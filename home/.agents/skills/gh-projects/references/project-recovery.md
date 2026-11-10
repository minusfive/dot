# GitHub Project Recovery Reference

## Native command matrix

| Action                        | Command                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------- |
| List open and closed Projects | `gh project list --owner <owner>` and `gh project list --owner <owner> --closed` |
| View a Project                | `gh project view <number> --owner <owner> --format json`                         |
| List fields                   | `gh project field-list <number> --owner <owner> --format json`                   |
| List items                    | `gh project item-list <number> --owner <owner> --format json`                    |
| Close a Project               | `gh project close <number> --owner <owner>`                                      |
| Reopen a Project              | `gh project close <number> --owner <owner> --undo`                               |
| Delete a Project              | `gh project delete <number> --owner <owner>`                                     |

Use the exact owner, Project number, and authorization from the accepted recovery decision. Treat delete as irreversible unless the provider supplies a verified recovery path.

Read both list scopes until the provider reports no next page. Record the scope and page or cursor coverage. A `--limit` value is not proof of a complete inventory unless the provider confirms that the value covers every result.

Keep inventory commands read-only. Use `gh project close` for reversible removal from active use. Use `gh project close --undo` only with authorization to reopen. Use `gh project delete` only after a fresh inventory, duplicate or keeper decision, explicit cleanup authorization, and a recorded rollback limitation.

## Default board view

Read the Project root and every available view before a view mutation. Select the provider's initial or default view as the canonical view. Require exactly one default view and set its layout to `BOARD_LAYOUT`.

If no default view exists, create one with an idempotent mutation. Preserve the existing view identity when converting a table view. Reject duplicate views, duplicate default markers, and a table-only default.

Read the Project after the view mutation. Verify the root Project URL and the canonical view URL. Record both URLs with the Project and view node identities.

## Typed field update

`UpdateProjectV2FieldInput.singleSelectOptions` accepts a list of `ProjectV2SingleSelectFieldOptionInput` objects. Each object has `name`, `color`, and `description`, and can retain an existing `id`.

Use this request shape with `gh api graphql --input -`:

```json
{
  "query": "mutation($input:UpdateProjectV2FieldInput!){updateProjectV2Field(input:$input){projectV2Field{... on ProjectV2SingleSelectField{id options{id name color description}}}}}",
  "variables": {
    "input": {
      "fieldId": "FIELD_NODE_ID",
      "singleSelectOptions": [
        {
          "id": "OPTION_NODE_ID",
          "name": "Blocked",
          "color": "RED",
          "description": "Work cannot proceed."
        }
      ]
    }
  }
}
```

Send the input object as JSON. Do not encode `variables.input` as a JSON string.

The request body must contain a typed `variables.input` object. Do not replace `--input -` with `-F input=...` or a JSON string.
