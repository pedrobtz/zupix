# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

zupix reads and writes PNG, JPEG, WebP and QOI with every codec compiled
into the package. It decodes to a `nativeRaster`, a double array or an
integer array with a `bits` attribute, encodes from the same shapes, and
reads header and metadata (size, depth, ICC and EXIF bytes, orientation)
without decoding pixels. R users call the `pix_` functions; sibling
packages call the same codecs from C through a registered table. It has
no `Imports`, no `LinkingTo` and no `SystemRequirements`: zlib comes
from R’s own toolchain and everything else is vendored. It does not
manage colour (that is zucolor), process images (zuvips, magick), read
tiled or pyramidal images (zuvips), or draw (zuraster). TIFF arrives in
v0.2.0; GIF, AVIF and JPEG XL are later still.

The specification is
[`.agents/design.md`](https://pedrobtz.github.io/zupix/.agents/design.md),
adopted from [RFC
0055](https://github.com/pedrobtz/packages/blob/main/rfcs/started/0055-zupix-image-codecs.md).
It outranks this file: `CLAUDE.md` orients, the design doc decides. Its
decisions (§13) are all still marked **(C)**, and its open questions
(§15) are open.

## Current state

Scaffolded 2026-10-30 with `create-pkg.sh`; no functionality yet. The
roadmap in `.agents/roadmap.md` takes it to v0.1.0. `DESCRIPTION`’s
`Title` and `Description` are still the scaffold’s placeholders.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as “6 of 7”.

- **One parent issue per target version**, titled with the bare version,
  for example `v0.1.0`. `v0.1.0` issue: created by `pkg-roadmap`.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it,
  for example `Stage 3 — R interface`, and linking to that section. The
  number of stages is whatever the roadmap has; there is no fixed scale.
- **Every tracking issue carries the `stage` label**, so it can be told
  apart from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in
  the body of the stage’s pull request. Never close a stage whose exit
  criteria are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages
  are done, not what a stage requires. Adding, removing or renaming a
  stage means editing the roadmap and the sub-issues in the same change.
- **Each stage has a CI tier, `quick` or `full`.** The roadmap sets it,
  and `quick` is the default. See Continuous integration for what each
  means. The second-to-last stage, `Full CI`, runs the full set and
  fixes what it finds before `v0.1.0 readiness`.
- Close the parent issue when CRAN accepts the version and it is tagged.
  Opening a parent issue implies at least one stage sub-issue; a parent
  with no sub-issues shows no progress on the board.

## Versioning

A new package develops at `0.0.0.9000` and targets `0.1.0` for its first
CRAN release. Set `Version: 0.1.0` and the matching `NEWS.md` heading
when the package enters `Pre-flight`. Bump to `0.1.0.9000` only after
CRAN accepts it, never before: a `.9000` version above an unreleased
`0.1.0` heading is wrong.

Until the first release the R API may change freely. Sibling packages
can still depend on this one before CRAN does, through `Remotes:` or
`LinkingTo:`. The design plans these: zuraster (`Imports` and
`LinkingTo`, the C table), zuocr (`Imports`, R level), and zupdf and
zuvips (`Suggests`); zusvg may move its PNG output to the table. A
change to the C API in `inst/include/zupix.h` or `zupix-r.h`, or to the
pixel shapes of design §6.2 (the imaging stack’s contract), breaks them
even before 0.1.0. A package that others wait on should reach CRAN
first.

## Commands

Run from the package root.

``` sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

Occasional, for vendored code and its gates:

``` sh
tools/vendor/verify          # vendored tree == manifest + patches (offline)
tools/vendor/fetch [source]  # re-vendor from tools/vendor/manifest.tsv
tools/check-symbols          # zupix.so imports no stdio/exit/abort/getenv/RNG,
                             # exports only R_init_zupix (add --canary)
tools/run-benchmarks         # design §10, into .agents/benchmarks.md
```

## Architecture

Growing as stages land; `.agents/design.md` §4 plans the layers.

- `src/vendor/<lib>/` is upstream code, trimmed by
  `tools/vendor/<lib>.files`, pinned and patched by
  `tools/vendor/manifest.tsv` and `tools/patches/<lib>/`. Never edit it
  by hand: change a patch and re-run `tools/vendor/fetch`.
- Wuffs and `qoi.h` are single files compiled through one zupix
  translation unit each (`src/zpx_wuffs.c`, `src/zpx_qoi.c`), which set
  the module and implementation macros. libjpeg-turbo and libwebp
  compile file by file from the object lists in `src/Makevars`.
- `src/jpeg-config/` holds zupix’s hand-written stand-ins for the
  headers libjpeg-turbo’s CMake build generates.
- `src/zpx_r.c` is the only R-aware C; `src/zpx_init.c` registers it.

## Invariants that are easy to break

These are fixed by the design before any code exists. Each guards
something the code will not show.

- **No `Imports`, `LinkingTo` or `SystemRequirements`.** zlib is linked
  with `-lz` from R’s toolchain (D3); every other codec is vendored. A
  system library breaks the source install the package exists for.
- **The core (`zpx_*.c`) includes no R header, raises no R error and
  never longjmps out of itself;** it returns a `zpx_status`. Fuzz
  targets link it without R, and consumers call the table from inside
  vendored libraries’ frames (design §4, §7), where an R error would
  unwind through foreign code. Only `zpx_r.c` touches R objects.
- **Check limits on declared sizes before allocating** (design §6.5,
  D7), and fail with `zupix_decode_error` when the scanner’s and Wuffs’s
  sizes disagree. Otherwise a small file declaring a huge image
  allocates gigabytes, or passes the limits with one size and decodes
  with another.
- **Return the pixels the file holds.** ICC profiles and colour chunks
  are returned or reported, never applied (D8); EXIF orientation is
  applied only on request (D9); channels may be added, never removed
  (D10). Each of these is a colour decision that belongs to the caller
  or to zucolor.
- **Only `R_init_zupix` is exported** from the shared object. No
  `wuffs_`, `jpeg_`, `jinit`, `WebP` or `qoi_` symbol may leak, or zupix
  collides with any other package that links those libraries;
  `test-abi.R` checks the symbol table (design §9).
- **Decoders and encoders come from different code** (D2): Wuffs
  decodes, while zupix’s own PNG writer, libjpeg-turbo’s compressor,
  libwebp’s encoder and `qoi.h` encode. Don’t pull a vendored library’s
  decoder in for convenience; hostile input goes only through Wuffs.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`,
  randomised input through
  [`withr::local_seed()`](https://withr.r-lib.org/reference/with_seed.html).
  Tests write only under
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "<pkg>_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of
  the definition of done.
- **Borrow a conformance suite before writing one.** Mainstream
  implementations in Python, Java, Go or Node usually ship a test
  corpus. Use it as an oracle rather than inventing cases by hand. The
  design names PngSuite, libjpeg-turbo’s `testimages`, libwebp’s test
  files and the QOI test images, with `png`, `jpeg`, `webp` and `qoi` as
  differential oracles (design §9). Their licences are not yet read
  (Q6); files that may not be redistributed are downloaded in CI only.
- **Helpers live in `tests/testthat/helper-*.R`.** None yet.
- **Keep the suite inside the CRAN time budget.** No suite yet.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors,
0 warnings and 0 notes. The one allowed note is “New submission” before
the first release. `devtools::test(shuffle = TRUE)` green. CI green at
the change’s tier: the quick profile for a `quick` roadmap stage or an
ordinary pull request, the full profile for a `full` stage, `Full CI`,
and every release. A user-facing change also needs a test, roxygen
documentation and a `NEWS.md` entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD
  check runs `--as-cran` on the CRAN-like runners and containers, and it
  replaces win-builder, the macOS builder and R-hub. None of them is a
  release step, and `cran-comments.md` lists the CI legs as its test
  environments.
- **Entering `Pre-flight`.** The roadmap’s feature stages are done, the
  version is set as in Versioning, `NEWS.md` and `cran-comments.md` are
  written, and CI is green. Only submission work remains.
- **Before submitting,** run `pkg-critical-review` once the roadmap is
  implemented and fix what it files, then `pkg-cran-review`, and resolve
  every finding. Both skills are in `pedrobtz/r-skills`.
- **The pretest is automated and does not read `cran-comments.md`.** A
  NOTE that is explained but not fixed gets the upload archived. Fix the
  NOTE, as under Vendored native code, instead of justifying it.
- **After acceptance,** `pkg-post-cran` tags the submitted commit with
  the bare version, `0.1.0` (no `v`), publishes the GitHub release,
  bumps to `0.1.0.9000`, closes the version’s parent issue and moves the
  board card.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by
  hand.
- Edit `README.Rmd`, not the generated `README.md`.
- Keep prose simple and short. One idea per sentence.
- Wrap roxygen text at 80 characters and run `air format .` on R
  sources.
- Use `lower_snake_case`, and prefix internal native symbols with
  `<pkg>_`.
- Keep hard runtime dependencies at zero unless a recorded design
  decision says otherwise.
- Export and document public functions. Do not create roxygen topics for
  internal ones.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. Call those reusable workflows
instead of writing bespoke ones, and pin a released tag rather than
`main`. Pin a workflow that holds a write token, such as `coverage.yml`,
to a commit, with the tag in a comment. The `R-CMD-check` workflow must
call `r-cmd-check.yml`, because a hand-rolled one does not count as the
pre-submission check. This package calls `r-cmd-check.yml@v1` and
`coverage.yml@v1`; `pkgdown.yaml` is a standalone r-lib workflow.

Small edits get a small run. The shared workflows look at the files a
pull request changes, compared with its merge base:

- **Markdown only**, such as `README.md`, `NEWS.md` or
  `cran-comments.md`, skips every check. Only coverage and the pkgdown
  site run.
- **`DESCRIPTION` or `README.Rmd` as well**, and nothing else, adds one
  R CMD check on Ubuntu R-release.
- **Any other file** runs everything.

So put a README or `DESCRIPTION` touch-up in its own pull request. Once
a pull request changes code, every later push to it runs every workflow.

### Quick by default, full by exception

The full profile is slow. gctorture at step 20 alone has taken 36 to 107
minutes on sibling packages. Waiting on it between roadmap stages was
the main thing slowing roadmaps down, so:

- **Pull requests run the quick profile.** It should finish in under
  five minutes. If it doesn’t, raise gctorture’s `quick-step` or trim
  `quick-containers` in the caller workflows; never cut the full
  profile.
- **A `full` roadmap stage takes the `full-ci` label** and merges only
  on a green full run. The roadmap gives the reason in the stage’s
  `**CI.**` line, for example first compiled code, a `PROTECT` or
  finalizer change, a vendored library, or a Windows-only path.
- **Don’t wait on the full run a merge starts** on the default branch,
  and cancel older full runs it supersedes. A failure that only the full
  set shows goes on the `Full CI` stage issue as a comment with the run
  link, and is fixed there. A failure the quick profile also shows is
  fixed now.
- **`Full CI` and `v0.1.0 readiness` wait** for a green full run on
  their merge commit, and the release commit always needs one.
- Locally, run `gctorture(TRUE)` on the code a C change touches when it
  is cheap; the full run is the authority.

## Vendored native code

The design plans four upstreams, none vendored yet: Wuffs (MIT and
Apache-2.0, both apply; decoders for all four formats), the compression
half of libjpeg-turbo 3.2.x (IJG and BSD-3-Clause), the libwebp 1.6.0
encoder (BSD-3-Clause and its `PATENTS` grant), and `qoi.h` (MIT, no
tags, pinned by commit). Stage 0 records tags, commits, checksums and
patches when it vendors them. Wuffs’s JPEG, WebP and QOI decoders exist
only in its `v0.4.0-alpha` series, so D1 departs from the stable-release
rule below; that is the decision the design flags for a second look.

- Pin a stable upstream release, never `master` or a release candidate.
- Record the tag, the commit and the checksums, and write down the
  update procedure so the next bump is mechanical.
- Keep upstream `LICENSE` and `NOTICE` under `src/vendor/<lib>/`,
  declare the vendored code in `DESCRIPTION` and `inst/COPYRIGHTS`.
- Keep the vendor tree clearly separated from first-party source, and
  record every local patch and why it exists.
- **CRAN’s compiled-code check applies to vendored code too.** No
  `stdout` or `stderr`, no `printf`, `abort`, `exit` or system RNG may
  be linked, even behind a debug switch that never runs. Remove them
  with a patch in `tools/patches/`, list it in `src/vendor/PROVENANCE`,
  and make the vendor-verify script check “upstream plus exactly these
  patches”. Avoid diagnostic-suppressing pragmas too, because they draw
  their own NOTE. zuhtml is the reference:
  `tools/patches/0002-no-stdio.patch` and `tools/verify-vendor`. zuxml’s
  first upload was archived because it justified such a symbol instead
  of patching it.
- Guard against regressions in CI: run `nm -u` on the built objects and
  fail on any of those symbols, so an upstream bump cannot bring them
  back.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped.
Keep each commit focused and do not sweep in unrelated files. A pull
request explains the user-visible outcome and the rationale, links
related issues, lists the checks that were run and the tests that were
skipped, and flags platform-sensitive or vendored changes. Performance
claims need evidence.

Never commit or push to the default branch. Work on a branch, open a
pull request, and leave it for review. Do not merge a pull request
unless you are told to.

When you find a defect, in this package or in an upstream tool, open an
issue for it rather than only working around it.

## Working with skills

The portfolio’s workflow skills live in `pedrobtz/r-skills` (`pkg-init`,
`pkg-roadmap`, `pkg-implement`, `pkg-critical-review`,
`pkg-cran-review`, `pkg-post-cran`, `pkg-readme`); the general process
skills are [Superpowers](https://github.com/obra/superpowers).
`building-a-package.md` in `pedrobtz/packages` walks through them in
order. Both sets defer to this file where they overlap, so the
settlements are recorded here.

- **One design.** The specification is `.agents/design.md`, adopted from
  the package’s RFC in `pedrobtz/packages/rfcs`. A package with an
  adopted design is past `brainstorming`; a design change goes through
  the RFC, not a new spec. Superpowers’ default
  `docs/superpowers/specs/` is not used.
- **Plans at two levels.** `.agents/roadmap.md` holds the stages, one
  mergeable pull request each, with exit criteria and a CI tier
  (`pkg-roadmap`). Inside a stage, `writing-plans` breaks the work into
  tasks of one test cycle each, saved as `.agents/plans/stage-<n>.md`.
  The roadmap stays authoritative; a plan is scratch and is not kept in
  sync.
- **Build and merge.** `pkg-implement` runs the stage loop: branch
  `stage-<n>-<slug>` from the stage issue, implement the plan with
  `test-driven-development`
  (`Rscript -e 'devtools::test(filter = "<name>")'` is the red/green
  command), open the pull request, merge on green at the stage’s CI
  tier. The confirmation the user gives at the start of that loop is the
  “told to merge” that Commits and pull requests requires, so the
  `finishing-a-development-branch` menu is not presented for stage pull
  requests. Any other pull request still waits for review.
- **Failures and claims.** A failing check or test goes through
  `systematic-debugging` before a fix. “Green”, “done” and “ready for
  CRAN” are claimed only after `verification-before-completion`: run the
  command, read the output.
- **Review.** `requesting-code-review` gates tasks inside a stage.
  `pkg-critical-review` reviews the whole package once the roadmap is
  implemented, with Posit’s reviewers, and files issues. CRAN’s reviewer
  email and GitHub review threads go through `receiving-code-review`.
- **Keep scratch out of the tarball.** `R CMD build` reads
  `.Rbuildignore`, not `.gitignore`. It must list `^\.agents$`,
  `^\.superpowers$` (the Superpowers task ledger), `^\.worktrees$` (if
  git worktrees are kept in the package directory; a sibling directory
  avoids the question), `^\.claude$`, `^CLAUDE\.md$`, `^AGENTS\.md$`,
  `^CRAN-SUBMISSION$` and `^cran-comments\.md$`. A stray top-level file
  is a NOTE, and the pretest archives on NOTEs.
