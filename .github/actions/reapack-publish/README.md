# reapack-publish

Shared action that opens the "ReaPack: <Package> <tag>" PR in this repo when a TeamAudio project publishes a release. ReaSpeech, XY Pad and ReaSock call it from their own `reapack-publish.yml`.

The caller does the project-specific part: it checks out this repo and copies or builds its package files into that checkout. The action then does the part every project shares:

1. Commits the given paths on a `reapack/<slug>/<tag>-<run id>` branch.
2. Runs `reapack-index --commit --scan <sha>` so `index.xml` is updated in its own commit, as elsewhere in this repo's history.
3. Pushes the branch, creates the `reapack` and package labels, and opens the PR against `main`.

The push, label and PR steps retry with backoff on transient GitHub errors. Before each PR attempt it checks for an existing open PR on the branch, because GitHub sometimes returns an error after it has actually created the PR. If nothing changed (main already has these files), it exits successfully without pushing.

## Usage

```yaml
permissions:
  contents: read

jobs:
  reapack-publish:
    runs-on: ubuntu-latest
    env:
      TAG: ${{ github.event.inputs.tag || github.event.release.tag_name }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ env.TAG }}

      # The push in the action uses this checkout's credentials, so check out
      # with the publish token and keep persist-credentials at its default.
      - uses: actions/checkout@v4
        with:
          repository: TeamAudio/reascripts
          ref: main
          fetch-depth: 0
          token: ${{ secrets.REASCRIPTS_PUBLISH_TOKEN }}
          path: reascripts

      - name: Stage package files
        run: make -C path/to/project build && cp build/MyScript.lua reascripts/Category/MyScript.lua

      - uses: TeamAudio/reascripts/.github/actions/reapack-publish@main
        with:
          token: ${{ secrets.REASCRIPTS_PUBLISH_TOKEN }}
          tag: ${{ env.TAG }}
          package-name: My Script
          package-slug: my-script
          paths: |
            Category/MyScript.lua
```

The action installs Ruby, pandoc and `reapack-index` itself, so the caller doesn't need to.

### Inputs

| Input | Required | Description |
|---|---|---|
| `token` | yes | Token that can push branches, create labels and open PRs here. |
| `tag` | yes | Release tag being published, eg. `v1.2.3`. |
| `package-name` | yes | Name for the commit and PR title, eg. `ReaSpeech`. |
| `package-slug` | yes | Lowercase slug for the branch and package label, eg. `reaspeech`. |
| `paths` | yes | Newline-separated paths, relative to the checkout, to commit. |
| `reascripts-path` | no | Where the caller checked this repo out. Default `reascripts`. |
| `pr-body` | no | PR body. Defaults to a link to the caller's GitHub release for the tag. |

### Outputs

| Output | Description |
|---|---|
| `result` | `created`, `existing` (an open PR for the branch was reused) or `no-changes`. |
| `pr-url` | The PR's URL, unless `result` is `no-changes`. |

## Recovering from a failed run

The branch name includes the workflow run ID, and the action force-pushes it. That makes **Re-run failed jobs** safe: a re-run rebuilds and overwrites the same branch, then opens or reuses its PR. If the PR still can't be opened, the job summary prints the exact `gh pr create` command to open it from the pushed branch.

## Security notes

- Changes to this action run with every caller's publish token, so keep `REASCRIPTS_PUBLISH_TOKEN` scoped to this repo only. Then anyone who can change the action could already push here directly, and the action grants nothing extra.
- Inputs reach the shell as environment variables, never as `${{ }}` inside the script, so a tag or name can't inject shell.
- Never echo the token or enable `set -x` here: callers are public repos, so their run logs are public.
